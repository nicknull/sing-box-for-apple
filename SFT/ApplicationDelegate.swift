import ApplicationLibrary
import Foundation
import Libbox
import Library
import UIKit
import UserNotifications

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #if os(iOS)
                NSLog("✅ iOS 推送通知权限已授予")
                #elseif os(tvOS)
                NSLog("✅ tvOS 推送通知权限已授予")
                #endif
            } else {
                NSLog("❌ 推送通知权限被拒绝: \(error?.localizedDescription ?? "")")
            }
        }

        // Libbox 初始化
        NSLog("Here I stand")
        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        #if os(tvOS)
        options.isTVOS = true
        #endif
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

    // APNS Token 注册成功
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceTokenManager.shared.handleDeviceToken(deviceToken)
        #if os(iOS)
        NSLog("✅ iOS APNS Token 注册成功")
        #elseif os(tvOS)
        NSLog("✅ tvOS APNS Token 注册成功")
        #endif
    }

    // APNS Token 注册失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.handleRegistrationError(error)
        NSLog("❌ APNS Token 注册失败: \(error.localizedDescription)")
    }
}

extension ApplicationDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let title = notification.request.content.title
        #if os(iOS)
        NSLog("📬 iOS 收到前台通知: \(title)")
        completionHandler([.banner, .sound, .badge])
        #elseif os(tvOS)
        NSLog("📬 tvOS 收到前台通知: \(title)")
        completionHandler([.banner, .sound])
        #endif
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        #if os(iOS)
        NSLog("📬 iOS 用户点击通知")
        #elseif os(tvOS)
        NSLog("📬 tvOS 用户点击通知")
        #endif
        completionHandler()
    }
}
