import Foundation
import UIKit
import UserNotifications

class DeviceTokenManager: NSObject {
    static let shared = DeviceTokenManager()

    private var deviceToken: String?

    private override init() {
        super.init()
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                NSLog("✅ 推送通知权限已授予")
                DispatchQueue.main.async {
                    #if os(iOS)
                    UIApplication.shared.registerForRemoteNotifications()
                    #elseif os(tvOS)
                    UIApplication.shared.registerForRemoteNotifications()
                    #endif
                }
            } else {
                NSLog("❌ 推送通知权限被拒绝: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token

        #if os(iOS)
        NSLog("📱 APNS Device Token (iOS): \(token.prefix(20))...")
        #elseif os(tvOS)
        NSLog("📺 APNS Device Token (tvOS): \(token.prefix(20))...")
        #endif

        uploadTokenIfNeeded(token)
    }

    func handleRegistrationError(_ error: Error) {
        NSLog("❌ APNS 注册失败: \(error.localizedDescription)")
    }

    private func uploadToken(_ token: String) {
        #if os(iOS)
        let platform = "ios"
        NSLog("📤 准备上传 APNS Token (iOS): \(token.prefix(20))...")
        #elseif os(tvOS)
        let platform = "tvos"
        NSLog("📤 准备上传 APNS Token (tvOS): \(token.prefix(20))...")
        #endif

        NewNetWorkRequest(
            AQAPIService.registerDeviceToken(token: token, platform: platform),
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ APNS Token 上传成功")
                UserDefaults.standard.set(Date(), forKey: "apns_token_upload_date")
                UserDefaults.standard.set(token, forKey: "last_uploaded_apns_token")
            } else {
                NSLog("❌ APNS Token 上传失败: \(responseModel.messageStr ?? "未知错误")")
            }
        }
    }

    func uploadTokenIfNeeded(_ token: String) {
        let lastTokenKey = "last_uploaded_apns_token"
        let uploadDateKey = "apns_token_upload_date"

        let lastToken = UserDefaults.standard.string(forKey: lastTokenKey)
        if lastToken == token {
            // 检查上传时间，超过24小时重新上传
            if let lastUploadDate = UserDefaults.standard.object(forKey: uploadDateKey) as? Date {
                let daysSinceUpload = Calendar.current.dateComponents([.hour], from: lastUploadDate, to: Date()).hour ?? 0
                if daysSinceUpload < 24 {
                    NSLog("⏭️ APNS Token 最近已上传，跳过")
                    return
                }
            }
        }

        uploadToken(token)
    }

    func removeToken() {
        NSLog("🗑️ 准备移除 APNS Token")

        NewNetWorkRequest(
            AQAPIService.unregisterDeviceToken,
            modelType: SimpleResponse.self
        ) { response, responseModel in
            if let response = response, response.code == 200 {
                NSLog("✅ APNS Token 移除成功")
                UserDefaults.standard.removeObject(forKey: "apns_token_upload_date")
                UserDefaults.standard.removeObject(forKey: "last_uploaded_apns_token")
            } else {
                NSLog("❌ APNS Token 移除失败: \(responseModel.messageStr ?? "未知错误")")
            }
        }
    }

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

struct SimpleResponse: Codable {
    let code: Int
    let msg: String?
    let data: SimpleResponseData?
}

struct SimpleResponseData: Codable {
    let message: String?
}
