import Foundation
import FirebaseMessaging

/**
 * FCM Token 管理器
 * 负责上传和管理 FCM Token
 */
class FCMTokenManager {
    static let shared = FCMTokenManager()

    private init() {}

    /// 上传 FCM Token 到后端
    /// - Parameter fcmToken: Firebase Cloud Messaging Token
    func uploadToken(_ fcmToken: String) {
        NSLog("📤 准备上传 FCM Token: \(fcmToken.prefix(20))...")

        // 使用 NewNetWorkRequest 上传 Token
        NewNetWorkRequest(
            AQAPIService.registerFcmToken(fcmToken: fcmToken),
            modelType: SimpleResponse.self
        ) { response, error in
            if let response = response, response.code == 200 {
                NSLog("✅ FCM Token 上传成功")
                // 保存上传时间，避免重复上传
                UserDefaults.standard.set(Date(), forKey: "fcm_token_upload_date")
                UserDefaults.standard.set(fcmToken, forKey: "last_uploaded_fcm_token")
            } else {
                NSLog("❌ FCM Token 上传失败: \(error ?? "未知错误")")
            }
        }
    }

    /// 移除 FCM Token（用户登出时调用）
    func removeToken() {
        NSLog("🗑️ 准备移除 FCM Token")

        NewNetWorkRequest(
            AQAPIService.unregisterFcmToken,
            modelType: SimpleResponse.self
        ) { response, error in
            if let response = response, response.code == 200 {
                NSLog("✅ FCM Token 移除成功")
                UserDefaults.standard.removeObject(forKey: "fcm_token_upload_date")
                UserDefaults.standard.removeObject(forKey: "last_uploaded_fcm_token")
            } else {
                NSLog("❌ FCM Token 移除失败: \(error ?? "未知错误")")
            }
        }
    }

    /// 检查是否需要上传 Token（登录后或 Token 更新时）
    func uploadTokenIfNeeded(_ fcmToken: String) {
        // 检查是否已上传相同的 Token
        let lastToken = UserDefaults.standard.string(forKey: "last_uploaded_fcm_token")
        if lastToken == fcmToken {
            // 检查上传时间，超过24小时重新上传
            if let lastUploadDate = UserDefaults.standard.object(forKey: "fcm_token_upload_date") as? Date {
                let daysSinceUpload = Calendar.current.dateComponents([.hour], from: lastUploadDate, to: Date()).hour ?? 0
                if daysSinceUpload < 24 {
                    NSLog("⏭️ FCM Token 最近已上传，跳过")
                    return
                }
            }
        }

        uploadToken(fcmToken)
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
        ) { response, error in
            if let response = response, response.code == 200 {
                NSLog("✅ 测试推送发送成功")
                completion?(true, nil)
            } else {
                NSLog("❌ 测试推送发送失败: \(error ?? "未知错误")")
                completion?(false, error)
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
