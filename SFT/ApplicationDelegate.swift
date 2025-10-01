import ApplicationLibrary
import Foundation
import Libbox
import Library
import UIKit
import FirebaseCore
#if os(iOS)
import FirebaseMessaging
#elseif os(tvOS)
import UserNotifications
#endif

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase 初始化
        FirebaseApp.configure()

        #if os(iOS)
        // iOS 使用 Firebase Messaging
        Messaging.messaging().delegate = self
        #elseif os(tvOS)
        // tvOS 使用原生 APNS
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                NSLog("✅ tvOS 推送通知权限已授予")
            } else {
                NSLog("❌ tvOS 推送通知权限被拒绝: \(error?.localizedDescription ?? "")")
            }
        }
        #endif

        // Libbox 初始化
        NSLog("Here I stand")
        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        options.isTVOS = true
        var error: NSError?
        LibboxSetup(options, &error)
        LibboxSetLocale(Locale.current.identifier)
        setup()
        return true
    }

    private func setup() {
        do {
            try UIProfileUpdateTask.configure()
            NSLog("setup background task success")
        } catch {
            NSLog("setup background task error: \(error.localizedDescription)")
        }
    }

    #if os(tvOS)
    // tvOS: 成功注册 APNS Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NSLog("📱 tvOS APNS Token 已获取: \(tokenString.prefix(20))...")

        // 自动上传 Token（如果用户已登录）
        DeviceTokenManager.shared.uploadTokenIfNeeded(tokenString)
    }

    // tvOS: 注册失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("❌ tvOS APNS Token 注册失败: \(error.localizedDescription)")
    }
    #endif
}

#if os(iOS)
// iOS: Firebase Messaging Delegate
extension ApplicationDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            NSLog("📱 iOS FCM Token 已获取: \(token.prefix(20))...")
        }
    }
}
#elseif os(tvOS)
// tvOS: UserNotificationCenter Delegate
extension ApplicationDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NSLog("📬 tvOS 收到前台通知: \(notification.request.content.title)")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        NSLog("📬 tvOS 用户点击通知")
        completionHandler()
    }
}
#endif
