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

extension Notification.Name {
    static let authExpired = Notification.Name("authExpiredNotification")
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
    private var activeSyncTask: Task<Void, Never>?

    private let profileUpdateThrottle: TimeInterval = 4 * 60

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

    func logout() {
        cancelActiveSync()
        DeviceTokenManager.shared.removeToken()

        email = ""
        password = ""
        auth_data = ""
        token = ""

        Task {
            await deleteProfile0()
        }
    }

    func reload() {
        enqueueSync([.userInfo, .subscription])
        getReleaseVer()
    }

    func getReleaseVer() {
        NewNetWorkRequest(AQAPIService.getVersion(token: token), modelType: AppVersion.self) { appVersion, _ in
            guard let appVersion else { return }
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
        pendingSyncRequests.formUnion(requests)
        startNextSyncIfNeeded()
    }

    private func startNextSyncIfNeeded() {
        guard activeSyncTask == nil, !pendingSyncRequests.isEmpty else { return }
        let requests = pendingSyncRequests
        pendingSyncRequests.removeAll()

        activeSyncTask = Task { [weak self] @MainActor in
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
            logout()
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
            logout()
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
            if profile.remoteURL != remoteURL {
                profile.remoteURL = remoteURL
                try await ProfileManager.update(profile)
            }

            if shouldThrottleProfileUpdate(profile: profile, remoteURL: remoteURL) {
                return
            }

            try await profile.updateRemoteProfile()
        } else {
            try await createProfile(remoteURL: remoteURL)
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
        try await Task.detached(priority: .userInitiated) {
            try HTTPClient().getString(remoteURL)
        }.value
    }

    private func requestDecodedModel<T: Codable>(_ target: TargetType & ResponseProvider, as type: T.Type) async throws -> DecodedResponse<T> {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            _ = NewNetWorkRequest(target, modelType: type) { model, response in
                guard !hasResumed else { return }

                if Task.isCancelled {
                    hasResumed = true
                    continuation.resume(throwing: CancellationError())
                    return
                }

                guard let raw = response.dataString else {
                    hasResumed = true
                    continuation.resume(throwing: UserDataSyncError.emptyPayload)
                    return
                }

                guard response.code == 200, let model else {
                    hasResumed = true
                    if response.code == 403 {
                        continuation.resume(throwing: UserDataSyncError.unauthorized)
                    } else {
                        continuation.resume(throwing: UserDataSyncError.requestFailed(code: response.code, message: response.messageStr))
                    }
                    return
                }

                hasResumed = true
                continuation.resume(returning: DecodedResponse(model: model, rawJSON: raw))
            } failureCallback: { response in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: UserDataSyncError.requestFailed(code: response.code, message: response.messageStr))
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
}
