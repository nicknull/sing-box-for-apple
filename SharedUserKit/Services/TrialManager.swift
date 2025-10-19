//
//  TrialManager.swift
//  SharedUserKit
//
//  Created by xiaokang chen on 2024/10/16.
//

import Foundation
import Defaults


class TrialManager: ObservableObject {
    static let shared = TrialManager()

    @Published var trialInfo: TrialInfoData?
    @Published var isLoading = false
    @Published var lastCheckTime: Date?

    private init() {}

    // MARK: - API 调用

    /// 获取试用信息
    func fetchTrialInfo() async -> Result<TrialInfoData, Error> {
        isLoading = true
        defer { isLoading = false }

        return await withCheckedContinuation { continuation in
            NetworkService.shared.request(
                AQAPIService.getTrialInfo,
                decodeTo: TrialInfoResponse.self
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.lastCheckTime = Date()

                    switch result {
                    case .success(let payload):
                        if payload.context.httpStatusCode == 200, let trialResp = payload.model {
                            self?.trialInfo = trialResp.data
                            continuation.resume(returning: .success(trialResp.data))
                        } else {
                            let error = NSError(domain: "TrialError", code: payload.context.httpStatusCode, userInfo: [
                                NSLocalizedDescriptionKey: payload.context.message ?? "获取试用信息失败"
                            ])
                            continuation.resume(returning: .failure(error))
                        }

                    case .failure(let error):
                        let nsError = NSError(domain: "TrialError", code: error.httpStatusCode, userInfo: [
                            NSLocalizedDescriptionKey: error.message
                        ])
                        continuation.resume(returning: .failure(nsError))
                    }
                }
            }
        }
    }

    /// 领取试用
    func claimTrial() async -> Result<TrialClaimData, Error> {
        isLoading = true
        defer { isLoading = false }

        return await withCheckedContinuation { continuation in
            NetworkService.shared.request(
                AQAPIService.claimTrial,
                decodeTo: TrialClaimResponse.self
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let payload):
                        if payload.context.httpStatusCode == 200, let claimData = payload.model?.data {
                            continuation.resume(returning: .success(claimData))
                        } else {
                            let error = NSError(domain: "TrialError", code: payload.context.httpStatusCode, userInfo: [
                                NSLocalizedDescriptionKey: payload.context.message ?? "领取试用失败"
                            ])
                            continuation.resume(returning: .failure(error))
                        }

                    case .failure(let error):
                        let nsError = NSError(domain: "TrialError", code: error.httpStatusCode, userInfo: [
                            NSLocalizedDescriptionKey: error.message
                        ])
                        continuation.resume(returning: .failure(nsError))
                    }
                }
            }
        }
    }

    // MARK: - 试用状态检查

    /// 检查用户是否可以试用
    func canUserTrial() -> Bool {
        guard let trialInfo = trialInfo else { return false }
        return trialInfo.trial_enabled && trialInfo.can_claim
    }

    /// 检查用户是否正在试用中
    func isUserOnTrial() -> Bool {
        guard let trialInfo = trialInfo else { return false }
        return trialInfo.user_status.is_trial && !trialInfo.user_status.is_expired
    }

    /// 检查试用是否过期
    func isTrialExpired() -> Bool {
        guard let trialInfo = trialInfo else { return false }
        return trialInfo.user_status.is_trial && trialInfo.user_status.is_expired
    }

    /// 获取试用剩余时间（小时）
    func remainingTrialHours() -> Double? {
        guard let trialInfo = trialInfo else { return nil }
        return trialInfo.user_status.remaining_hours
    }

    /// 获取试用到期时间
    func trialExpirationDate() -> Date? {
        guard let trialInfo = trialInfo,
              let expiredAt = trialInfo.user_status.expired_at else { return nil }
        return Date(timeIntervalSince1970: expiredAt)
    }

    // MARK: - 缓存管理

    /// 清理缓存的试用信息
    func clearCache() {
        trialInfo = nil
        lastCheckTime = nil
    }

    /// 是否需要刷新数据（超过5分钟）
    func shouldRefresh() -> Bool {
        guard let lastCheck = lastCheckTime else { return true }
        return Date().timeIntervalSince(lastCheck) > 300 // 5分钟
    }
}

// MARK: - Trial Reminder Manager
class TrialReminderManager: ObservableObject {
    static let shared = TrialReminderManager()

    @Published var shouldShowTrialReminder = false
    @Published var shouldShowTrialBanner = false
    @Published var reminderType: TrialReminderType = .canTrial

    private let userDefaults = UserDefaults.standard
    private let lastReminderKey = "LastTrialReminderTime"
    private let reminderCountKey = "TrialReminderCount"
    private let maxRemindersPerDay = 2

    private init() {}

    enum TrialReminderType {
        case canTrial        // 可以试用
        case trialActive     // 试用进行中
        case trialExpired    // 试用已过期
    }

    /// 检查是否应该显示试用提醒
    func checkShouldShowReminder(trialInfo: TrialInfoData) {
        // 检查提醒频率限制
        if hasReachedDailyReminderLimit() {
            return
        }

        // 根据试用状态决定提醒类型
        if trialInfo.can_claim && trialInfo.trial_enabled {
            reminderType = .canTrial
            shouldShowTrialReminder = true
            recordReminderShown()
        } else if trialInfo.user_status.is_trial && !trialInfo.user_status.is_expired {
            // 试用进行中，在剩余时间少于24小时时提醒
            if let remaining = trialInfo.user_status.remaining_hours, remaining <= 24 {
                reminderType = .trialActive
                shouldShowTrialBanner = true
            }
        } else if trialInfo.user_status.is_trial && trialInfo.user_status.is_expired {
            reminderType = .trialExpired
            shouldShowTrialBanner = true
        }
    }

    /// 记录提醒已显示
    private func recordReminderShown() {
        let now = Date()
        userDefaults.set(now.timeIntervalSince1970, forKey: lastReminderKey)

        let today = Calendar.current.startOfDay(for: now)
        let currentCount = userDefaults.integer(forKey: "\(reminderCountKey)_\(today.timeIntervalSince1970)")
        userDefaults.set(currentCount + 1, forKey: "\(reminderCountKey)_\(today.timeIntervalSince1970)")
    }

    /// 检查是否达到每日提醒限制
    private func hasReachedDailyReminderLimit() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let todayCount = userDefaults.integer(forKey: "\(reminderCountKey)_\(today.timeIntervalSince1970)")
        return todayCount >= maxRemindersPerDay
    }

    /// 关闭提醒
    func dismissReminder() {
        shouldShowTrialReminder = false
        shouldShowTrialBanner = false
    }

    /// 获取提醒标题
    func reminderTitle() -> String {
        switch reminderType {
        case .canTrial:
            return "免费试用可用"
        case .trialActive:
            return "试用即将到期"
        case .trialExpired:
            return "试用已到期"
        }
    }

    /// 获取提醒消息
    func reminderMessage(trialInfo: TrialInfoData?) -> String {
        switch reminderType {
        case .canTrial:
            if let config = trialInfo?.trial_config {
                return "可免费试用 \(config.trial_hours) 小时的 \(config.plan_name) 套餐"
            }
            return "可以领取免费试用"
        case .trialActive:
            if let remaining = trialInfo?.user_status.remaining_hours {
                return "试用还剩 \(String(format: "%.1f", remaining)) 小时，请及时购买套餐"
            }
            return "试用即将到期，请及时购买套餐"
        case .trialExpired:
            return "试用已到期，购买套餐继续使用"
        }
    }
}
