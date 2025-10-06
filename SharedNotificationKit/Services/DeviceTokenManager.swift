import Foundation
#if os(iOS)
import FirebaseMessaging
#elseif os(tvOS)
import UserNotifications
#endif

/**
 * 设备 Token 管理器
 * iOS: 使用 FCM Token
 * tvOS: 使用 APNS Token
 */
class DeviceTokenManager {
    static let shared = DeviceTokenManager()

    private init() {}

    #if os(iOS)
    /// 上传 FCM Token 到后端（iOS）
    /// - Parameter fcmToken: Firebase Cloud Messaging Token
    func uploadToken(_ fcmToken: String) {
        NSLog("📤 准备上传 FCM Token: \(fcmToken.prefix(20))...")

        NewNetWorkRequest(
            AQAPIService.registerFcmToken(fcmToken: fcmToken),
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ FCM Token 上传成功")
                UserDefaults.standard.set(Date(), forKey: "fcm_token_upload_date")
                UserDefaults.standard.set(fcmToken, forKey: "last_uploaded_fcm_token")
            } else {
                NSLog("❌ FCM Token 上传失败: \(responseModel.messageStr ?? "未知错误")")
            }
        }
    }
    #elseif os(tvOS)
    /// 上传 APNS Token 到后端（tvOS）
    /// - Parameter apnsToken: Apple Push Notification Service Token
    func uploadToken(_ apnsToken: String) {
        NSLog("📤 准备上传 APNS Token (tvOS): \(apnsToken.prefix(20))...")

        // tvOS 使用相同的接口，后端通过 platform 参数区分
        NewNetWorkRequest(
            AQAPIService.registerDeviceToken(token: apnsToken, platform: "tvos"),
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ APNS Token 上传成功 (tvOS)")
                UserDefaults.standard.set(Date(), forKey: "apns_token_upload_date")
                UserDefaults.standard.set(apnsToken, forKey: "last_uploaded_apns_token")
            } else {
                NSLog("❌ APNS Token 上传失败: \(responseModel.messageStr ?? "未知错误")")
            }
        }
    }
    #endif

    /// 移除设备 Token（用户登出时调用）
    func removeToken() {
        #if os(iOS)
        NSLog("🗑️ 准备移除 FCM Token")
        #elseif os(tvOS)
        NSLog("🗑️ 准备移除 APNS Token (tvOS)")
        #endif

        NewNetWorkRequest(
            AQAPIService.unregisterFcmToken,
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ 设备 Token 移除成功")
                #if os(iOS)
                UserDefaults.standard.removeObject(forKey: "fcm_token_upload_date")
                UserDefaults.standard.removeObject(forKey: "last_uploaded_fcm_token")
                #elseif os(tvOS)
                UserDefaults.standard.removeObject(forKey: "apns_token_upload_date")
                UserDefaults.standard.removeObject(forKey: "last_uploaded_apns_token")
                #endif
            } else {
                NSLog("❌ 设备 Token 移除失败: \(responseModel.messageStr ?? "未知错误")")
            }
        }
    }

    /// 检查是否需要上传 Token（登录后或 Token 更新时）
    func uploadTokenIfNeeded(_ token: String) {
        // 检查是否已上传相同的 Token
        #if os(iOS)
        let lastTokenKey = "last_uploaded_fcm_token"
        let uploadDateKey = "fcm_token_upload_date"
        #elseif os(tvOS)
        let lastTokenKey = "last_uploaded_apns_token"
        let uploadDateKey = "apns_token_upload_date"
        #endif

        let lastToken = UserDefaults.standard.string(forKey: lastTokenKey)
        if lastToken == token {
            // 检查上传时间，超过24小时重新上传
            if let lastUploadDate = UserDefaults.standard.object(forKey: uploadDateKey) as? Date {
                let daysSinceUpload = Calendar.current.dateComponents([.hour], from: lastUploadDate, to: Date()).hour ?? 0
                if daysSinceUpload < 24 {
                    NSLog("⏭️ 设备 Token 最近已上传，跳过")
                    return
                }
            }
        }

        uploadToken(token)
    }

    /// 测试推送通知
    /// - Parameters:
    ///   - title: 通知标题
    ///   - body: 通知内容
    ///   - completion: 完成回调
    func testPush(title: String, body: String, completion: ((Bool, String?) -> Void)? = nil) {
        NSLog("🔔 发送测试推送: \(title)")

        NewNetWorkRequest(
            AQAPIService.testPush(title: title, body: body),
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ 测试推送发送成功")
                completion?(true, nil)
            } else {
                let message = responseModel.messageStr ?? "未知错误"
                NSLog("❌ 测试推送发送失败: \(message)")
                completion?(false, message)
            }
        }
    }
}

/// 简单响应模型
struct SimpleResponse: Codable {
    let code: Int
    let msg: String?
    let data: SimpleResponseData?
}

struct SimpleResponseData: Codable {
    let message: String?
}
