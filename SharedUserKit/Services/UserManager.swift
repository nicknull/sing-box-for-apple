//
//  UserManager.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/4.
//

import Foundation
import SwiftUI
import Library
import Libbox
import CryptoSwift
import Defaults
import ApplicationLibrary

import Moya
import _Concurrency
import UIKit

private func isCurrentTaskCancelled() -> Bool {
    // 通过显式引用 Swift 并发 Task，绕过与 Moya.Task 的命名冲突
    _Concurrency.Task.isCancelled
}

@MainActor
class UserManager: ObservableObject {
    @AppStorage(ConstantKey.email) var email: String = ""
    @AppStorage(ConstantKey.password) var password: String = ""
    @AppStorage(ConstantKey.auth_data) var auth_data = ""
    @AppStorage(ConstantKey.token) var token = ""
    @AppStorage(ConstantKey.is_admin) var is_admin: Bool = false
    @AppStorage(ConstantKey.userInfojson) private var userInfoJsonStr = ""
    @AppStorage(ConstantKey.subscribeInfojson) private var subscribeInfoJsonStr = ""
    @AppStorage(ConstantKey.fileContentHash) private var fileContentHash = ""

    @Published private(set) var loadingProfile = false
    @Published private(set) var isRefreshingUserInfo = false
    @Published private(set) var isUpdatingSubscription = false

    private var pendingSyncRequests: Set<SyncRequest> = []
    private var activeSyncTask: _Concurrency.Task<Void, Never>?

    private let profileUpdateThrottle: TimeInterval = 60
    private var hasUpdatedProfileThisSession = false

    var userInfo: UserInfoModel? {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        guard let data = userInfoJsonStr.data(using: .utf8) else { return nil }
        return try? decoder.decode(UserInfoModel.self, from: data)
    }

    var subscribe: SubscribeModel? {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        guard let data = subscribeInfoJsonStr.data(using: .utf8) else { return nil }
        return try? decoder.decode(SubscribeModel.self, from: data)
    }

    var outTraffic: Bool {
        guard let subscribe, let down = subscribe.d, let up = subscribe.u, let quota = subscribe.transfer_enable else {
            return true
        }
        return down + up >= quota
    }

    var outDate: Bool {
        guard let expiry = userInfo?.expired_at else { return true }
        return expiry <= Date().timeIntervalSince1970
    }

    var isLoggedIn: Bool { !auth_data.isEmpty }

    var reloading: Bool { isRefreshingUserInfo || isUpdatingSubscription }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func logout() async {
        // 记录用户登出事件
        // SharedAnalyticsKit.shared.logUserLogout()

        cancelActiveSync()
        // DeviceTokenManager.shared.removeToken()

        email = ""
        password = ""
        auth_data = ""
        token = ""
        is_admin = false
        userInfoJsonStr = ""
        subscribeInfoJsonStr = ""
        fileContentHash = ""
        hasUpdatedProfileThisSession = false

//        Task {
            await deleteProfile0()
//        }
    }

    func reload() async {
        guard isLoggedIn else { return }
        enqueueSync([.userInfo, .subscription])
        getReleaseVer()
        await checkTrialStatusAfterLogin()
    }

    /// 登录成功后立即执行一次完整的用户数据同步，确保会话状态可用。
    func establishSessionAfterLogin() async throws {
        do {
            let response: DecodedResponse<UserInfoModel> = try await requestDecodedModel(
                AQAPIService.getUserInfo,
                as: UserInfoModel.self
            )
            userInfoJsonStr = response.rawJSON
            NSLog("✅ 登录初始化：用户信息同步成功")
        } catch let error as CancellationError {
            throw error
        } catch {
            throw mapToInitializationError(error)
        }

        do {
            let response: DecodedResponse<SubscribeModel> = try await requestDecodedModel(
                AQAPIService.getSubscribe,
                as: SubscribeModel.self
            )
            subscribeInfoJsonStr = response.rawJSON
            try await synchronizeProfile(with: response.model)
            NSLog("✅ 登录初始化：订阅信息同步成功")
        } catch let error as CancellationError {
            throw error
        } catch {
            throw mapToInitializationError(error)
        }

        getReleaseVer()
        await checkTrialStatusAfterLogin()
    }

    func requestSubscriptionRefresh(force: Bool = false) {
        guard isLoggedIn else { return }
        if hasUpdatedProfileThisSession && !force {
            return
        }
        if force {
            hasUpdatedProfileThisSession = false
        }
        enqueueSync([.subscription])
    }

    func getReleaseVer() {
        NetworkService.shared.request(
            AQAPIService.getVersion(token: token),
            decodeTo: AppVersion.self
        ) { result in
            guard case let .success(payload) = result, let appVersion = payload.model else { return }
#if os(iOS)
            Defaults[.releaseVersion] = appVersion.ios_version
#elseif os(tvOS)
            Defaults[.releaseVersion] = appVersion.appletv_version
#endif
        }
    }

    func refreshUserInfo() {
        enqueueSync([.userInfo])
    }

    func apnsTokenString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    }

    func getSubscribe() {
        enqueueSync([.subscription])
    }

    private func enqueueSync(_ requests: Set<SyncRequest>) {
        guard isLoggedIn else { return }
        pendingSyncRequests.formUnion(requests)
        startNextSyncIfNeeded()
    }

    private func startNextSyncIfNeeded() {
        guard activeSyncTask == nil, !pendingSyncRequests.isEmpty else { return }
        let requests = pendingSyncRequests
        pendingSyncRequests.removeAll()

        activeSyncTask = _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.performSync(for: requests)
            self.activeSyncTask = nil
            self.startNextSyncIfNeeded()
        }
    }

    private func performSync(for requests: Set<SyncRequest>) async {
        if requests.contains(.userInfo) {
            await syncUserInfo()
        }
        if requests.contains(.subscription) {
            await syncSubscription()
        }
    }

    private func syncUserInfo() async {
        guard !isRefreshingUserInfo else { return }
        isRefreshingUserInfo = true
        defer { isRefreshingUserInfo = false }

         do {
             let response: DecodedResponse<UserInfoModel> = try await requestDecodedModel(AQAPIService.getUserInfo, as: UserInfoModel.self)
             userInfoJsonStr = response.rawJSON
             NSLog("✅ 用户信息刷新成功，APNS Token 会在设备注册后自动上传")
         } catch UserDataSyncError.unauthorized {
             await logout()
         } catch {
             NSLog("⚠️ 用户信息刷新失败: \(error.localizedDescription)")
         }
    }

    private func syncSubscription() async {
        guard !isUpdatingSubscription else { return }
        isUpdatingSubscription = true
        defer { isUpdatingSubscription = false }

         do {
             let response: DecodedResponse<SubscribeModel> = try await requestDecodedModel(AQAPIService.getSubscribe, as: SubscribeModel.self)
             subscribeInfoJsonStr = response.rawJSON
             try await synchronizeProfile(with: response.model)
         } catch UserDataSyncError.unauthorized {
             await logout()
         } catch {
             NSLog("⚠️ 订阅信息刷新失败: \(error.localizedDescription)")
         }
    }

    private func synchronizeProfile(with subscription: SubscribeModel) async throws {
        guard let remoteURL = subscription.sing_url ?? subscription.subscribe_url, !remoteURL.isEmpty else {
            NSLog("⚠️ 订阅数据缺少有效的远程配置地址")
            return
        }

        let selectedID = await SharedPreferences.selectedProfileID.get()
        if let profile = try await loadProfile(id: selectedID) {
            let urlChanged = profile.remoteURL != remoteURL
            if urlChanged {
                profile.remoteURL = remoteURL
                try await ProfileManager.update(profile)
                hasUpdatedProfileThisSession = false
            }

            if hasUpdatedProfileThisSession && !urlChanged {
                return
            }

            if !urlChanged && shouldThrottleProfileUpdate(profile: profile, remoteURL: remoteURL) {
                return
            }

            try await profile.updateRemoteProfile()
            hasUpdatedProfileThisSession = true
        } else {
            try await createProfile(remoteURL: remoteURL)
            hasUpdatedProfileThisSession = true
        }
    }

    private func loadProfile(id: Int64) async throws -> Profile? {
        guard id >= 0 else { return nil }
        return try await ProfileManager.get(id)
    }

    private func shouldThrottleProfileUpdate(profile: Profile, remoteURL: String) -> Bool {
        guard profile.remoteURL == remoteURL, let lastUpdated = profile.lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < profileUpdateThrottle
    }

    private func createProfile(remoteURL: String) async throws {
        loadingProfile = true
        defer { loadingProfile = false }

        let remoteContent = try await fetchRemoteConfig(from: remoteURL)
        let remoteContentHash = remoteContent.md5()
        let hasExistingProfiles = try await !ProfileManager.list().isEmpty

        if fileContentHash == remoteContentHash && hasExistingProfiles {
            return
        }

        fileContentHash = remoteContentHash

        var error: NSError?
        LibboxCheckConfig(remoteContent, &error)
        if let error {
            throw error
        }

        let nextProfileID = try await ProfileManager.nextID()
        let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
        try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
        let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
        try remoteContent.write(to: profileConfig, atomically: true, encoding: .utf8)

        let profile = Profile(
            name: "iFlash",
            type: .remote,
            path: profileConfig.relativePath,
            remoteURL: remoteURL,
            autoUpdate: true,
            autoUpdateInterval: 60,
            lastUpdated: .now
        )

        try await ProfileManager.create(profile)
        try UIProfileUpdateTask.configure()
        await SharedPreferences.selectedProfileID.set(nextProfileID)
    }

    private func fetchRemoteConfig(from remoteURL: String) async throws -> String {
        try HTTPClient().getString(remoteURL)
    }

    private func requestDecodedModel<T: Codable>(_ target: TargetType & ResponseProvider, as type: T.Type) async throws -> DecodedResponse<T> {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            NetworkService.shared.request(
                target,
                decodeTo: type
            ) { result in
                guard !hasResumed else { return }

                switch result {
                case let .success(payload):
                    if isCurrentTaskCancelled() {
                        hasResumed = true
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    guard let raw = payload.context.payloadString else {
                        hasResumed = true
                        continuation.resume(throwing: UserDataSyncError.emptyPayload)
                        return
                    }

                    guard payload.context.httpStatusCode == 200, let model = payload.model else {
                        hasResumed = true
                        if payload.context.httpStatusCode == 403 {
                            continuation.resume(throwing: UserDataSyncError.unauthorized)
                        } else {
                            continuation.resume(
                                throwing: UserDataSyncError.requestFailed(
                                    code: payload.context.httpStatusCode,
                                    message: payload.context.message
                                )
                            )
                        }
                        return
                    }

                    hasResumed = true
                    continuation.resume(returning: DecodedResponse(model: model, rawJSON: raw))

                case let .failure(error):
                    hasResumed = true
                    continuation.resume(
                        throwing: UserDataSyncError.requestFailed(
                            code: error.httpStatusCode,
                            message: error.message
                        )
                    )
                }
            }
        }
    }

    private func cancelActiveSync() {
        activeSyncTask?.cancel()
        activeSyncTask = nil
        pendingSyncRequests.removeAll()
        isRefreshingUserInfo = false
        isUpdatingSubscription = false
    }

    @objc private func handleAppDidBecomeActive() {
        guard isLoggedIn else { return }
        requestSubscriptionRefresh()
        DeviceTokenManager.shared.syncTokenIfAvailable(force: false)
    }

    private func mapToInitializationError(_ error: Error) -> Error {
        if let syncError = error as? UserDataSyncError {
            return syncError
        }
        if let networkError = error as? NetworkRequestError {
            return UserDataSyncError.requestFailed(
                code: networkError.httpStatusCode,
                message: networkError.message
            )
        }
        let nsError = error as NSError
        return UserDataSyncError.requestFailed(
            code: nsError.code,
            message: nsError.localizedDescription
        )
    }

    private func deleteProfile0() async {
        do {
            guard let profile = try await ProfileManager.get(by: "iFlash") else {
                return
            }
            try await ProfileManager.delete(profile)
        } catch {
            print("Error: \(error)")
        }
    }

    private struct DecodedResponse<Model> {
        let model: Model
        let rawJSON: String
    }

    private enum SyncRequest: Hashable {
        case userInfo
        case subscription
    }

    private enum UserDataSyncError: LocalizedError {
        case emptyPayload
        case unauthorized
        case requestFailed(code: Int, message: String?)

        var errorDescription: String? {
            switch self {
            case .emptyPayload:
                return "服务器返回了空数据"
            case .unauthorized:
                return "登录状态已失效"
            case let .requestFailed(code, message):
                return "请求失败(\(code)): \(message ?? "未知错误")"
            }
        }
    }

    // MARK: - Trial Management

    /// 登录后检查试用状态
    private func checkTrialStatusAfterLogin() async {
        // 确保用户已登录
        guard isLoggedIn else { return }
        await self.checkAndShowTrialReminder()

    
    }

    /// 检查并显示试用提醒
    @MainActor
    private func checkAndShowTrialReminder() async {
         let trialManager = TrialManager.shared
         let reminderManager = TrialReminderManager.shared

         // 如果最近检查过且不需要刷新，跳过
         if !trialManager.shouldRefresh() {
             if let trialInfo = trialManager.trialInfo {
                 reminderManager.checkShouldShowReminder(trialInfo: trialInfo)
             }
             return
         }

         // 获取试用信息
         let result = await trialManager.fetchTrialInfo()
         switch result {
         case .success(let trialInfo):
             // 检查是否需要显示提醒
             reminderManager.checkShouldShowReminder(trialInfo: trialInfo)
         case .failure(let error):
             NSLog("⚠️ 获取试用信息失败: \(error.localizedDescription)")
         }
    }
}
