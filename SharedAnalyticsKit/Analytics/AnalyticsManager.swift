import Foundation
import Firebase
import FirebaseAnalytics
import UIKit

/// Analytics事件管理器
public class AnalyticsManager {
    public static let shared = AnalyticsManager()

    private init() {
        // 确保在任何统计调用前已经初始化 Firebase
        if FirebaseApp.app() == nil {
        }
    }

    // MARK: - 用户行为统计

    /// 记录用户登录事件
    public func logUserLogin(method: String, success: Bool, userId: String? = nil) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method,
            "success": success
        ])

        if success, let userId = userId {
            setUserId(userId)
        }
    }

    /// 记录用户登出事件
    public func logUserLogout() {
        Analytics.logEvent("user_logout", parameters: nil)
        setUserId(nil) // 清除用户ID
    }

    /// 记录IAP购买事件
    public func logIAPPurchase(productId: String, success: Bool, amount: Double? = nil, transactionId: String? = nil) {
        var parameters: [String: Any] = [
            "product_id": productId,
            "success": success
        ]

        if let amount = amount {
            parameters[AnalyticsParameterValue] = amount
            parameters[AnalyticsParameterCurrency] = "USD"
        }

        if let transactionId = transactionId {
            parameters["transaction_id"] = transactionId
        }

        Analytics.logEvent(AnalyticsEventPurchase, parameters: parameters)
    }

    /// 记录VPN连接事件
    public func logVPNConnection(server: String, success: Bool, connectionTime: TimeInterval? = nil, errorMessage: String? = nil) {
        var parameters: [String: Any] = [
            "server": server,
            "success": success
        ]

        if let connectionTime = connectionTime {
            parameters["connection_time"] = connectionTime
        }

        if let errorMessage = errorMessage {
            parameters["error_message"] = errorMessage
        }

        Analytics.logEvent("vpn_connect", parameters: parameters)
    }

    /// 记录VPN断开事件
    public func logVPNDisconnection(server: String, duration: TimeInterval? = nil, reason: String? = nil) {
        var parameters: [String: Any] = [
            "server": server
        ]

        if let duration = duration {
            parameters["session_duration"] = duration
        }

        if let reason = reason {
            parameters["disconnect_reason"] = reason
        }

        Analytics.logEvent("vpn_disconnect", parameters: parameters)
    }

    // MARK: - 页面统计

    /// 记录页面访问
    public func logScreenView(screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }

    // MARK: - 错误统计

    /// 记录非致命错误（改用自定义崩溃收集）
    public func logError(error: Error, context: String? = nil) {
        let nsError = error as NSError

        var parameters: [String: Any] = [
            "error_code": nsError.code,
            "error_domain": nsError.domain,
            "error_description": error.localizedDescription
        ]

        if let context = context {
            parameters["context"] = context
        }

        Analytics.logEvent("app_error", parameters: parameters)

        // 使用我们自己的 CrashManager 记录错误
        SharedCrashKit.reportCustomCrash(
            errorName: "\(nsError.domain):\(nsError.code)",
            errorMessage: nsError.localizedDescription,
            stackTrace: Thread.callStackSymbols,
            additionalInfo: context.map { ["context": $0] }
        )
    }

    /// 记录自定义错误信息（改用自定义崩溃收集）
    public func logCustomError(message: String, code: Int = 0, context: String? = nil) {
        var parameters: [String: Any] = [
            "error_message": message,
            "error_code": code
        ]

        if let context = context {
            parameters["context"] = context
        }

        Analytics.logEvent("custom_error", parameters: parameters)

        // 使用我们自己的 CrashManager 记录错误
        SharedCrashKit.reportCustomCrash(
            errorName: "CustomError:\(code)",
            errorMessage: message,
            stackTrace: Thread.callStackSymbols,
            additionalInfo: context.map { ["context": $0] }
        )
    }

    // MARK: - 性能统计

    /// 记录性能指标
    public func logPerformance(action: String, duration: TimeInterval, success: Bool = true, details: [String: Any]? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "duration": duration,
            "success": success
        ]

        if let details = details {
            parameters.merge(details) { _, new in new }
        }

        Analytics.logEvent("performance_metric", parameters: parameters)
    }

    // MARK: - 用户属性设置

    /// 设置用户属性
    public func setUserProperty(value: String?, name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// 设置用户ID（不再同步到 Crashlytics）
    public func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
        // 注：不再使用 Crashlytics，用户ID只设置到 Firebase Analytics
    }

    // MARK: - 自定义事件

    /// 记录自定义事件
    public func logCustomEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}

// MARK: - 便捷扩展

public extension AnalyticsManager {

    /// 记录应用状态变化
    func logAppStateChange(state: String, previousState: String? = nil) {
        var parameters: [String: Any] = ["new_state": state]
        if let previousState = previousState {
            parameters["previous_state"] = previousState
        }
        logCustomEvent(name: "app_state_change", parameters: parameters)
    }

    /// 记录设置页面访问
    func logSettingsAccess(setting: String) {
        logCustomEvent(name: "settings_access", parameters: [
            "setting": setting
        ])
    }

    /// 记录服务器选择
    func logServerSelection(server: String, location: String? = nil) {
        var parameters: [String: Any] = ["server": server]
        if let location = location {
            parameters["location"] = location
        }
        logCustomEvent(name: "server_selected", parameters: parameters)
    }

    /// 记录流量使用情况
    func logTrafficUsage(upload: Int64, download: Int64, duration: TimeInterval) {
        logCustomEvent(name: "traffic_usage", parameters: [
            "upload_bytes": upload,
            "download_bytes": download,
            "session_duration": duration,
            "total_bytes": upload + download
        ])
    }

    /// 记录推送通知相关事件
    func logPushNotification(event: String, type: String? = nil, success: Bool = true) {
        var parameters: [String: Any] = [
            "event": event,
            "success": success
        ]
        if let type = type {
            parameters["notification_type"] = type
        }
        logCustomEvent(name: "push_notification", parameters: parameters)
    }

    /// 记录网络质量
    func logNetworkQuality(latency: TimeInterval, downloadSpeed: Double, uploadSpeed: Double) {
        logCustomEvent(name: "network_quality", parameters: [
            "latency_ms": latency * 1000,
            "download_speed_mbps": downloadSpeed,
            "upload_speed_mbps": uploadSpeed
        ])
    }
}
