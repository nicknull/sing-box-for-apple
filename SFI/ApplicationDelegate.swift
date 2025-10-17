import ApplicationLibrary
import Defaults
import Foundation
import Libbox
import Library
import Network
import UIKit
import UserNotifications

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    private var profileServer: ProfileServer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 初始化 Firebase Analytics
         SharedAnalyticsKit.configure()

        // 记录应用启动事件
         SharedAnalyticsKit.logAppLaunch()

        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        var error: NSError?
        LibboxSetup(options, &error)
        LibboxSetLocale(Locale.current.identifier)

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                NSLog("✅ 推送通知权限已授予 (iOS)")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }

                // 记录推送权限事件
                 SharedAnalyticsKit.shared.logPushNotification(event: "permission_granted")
            } else {
                NSLog("❌ 推送通知权限被拒绝: \(error?.localizedDescription ?? "unknown")")

                // 记录推送权限被拒绝事件
                 SharedAnalyticsKit.shared.logPushNotification(
                     event: "permission_denied",
                     success: false
                 )
                if let error = error {
                     SharedAnalyticsKit.shared.logError(error: error, context: "push_permission")
                }
            }
        }

        setup()
        print("✅ AppDelegate didFinishLaunchingWithOptions called")

        return true
    }

    // APNS Device Token 回调
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceTokenManager.shared.handleDeviceToken(deviceToken)
        NSLog("✅ didRegisterForRemoteNotificationsWithDeviceToken")

        // 记录设备Token注册成功事件
         SharedAnalyticsKit.shared.logPushNotification(
             event: "device_token_registered",
             success: true
         )
    }

    // 注册失败回调
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.handleRegistrationError(error)
        NSLog("❌ didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)")

        // 记录设备Token注册失败事件
         SharedAnalyticsKit.shared.logPushNotification(
             event: "device_token_registration_failed",
             success: false
         )
         SharedAnalyticsKit.shared.logError(error: error, context: "device_token_registration")
    }

    private func setup() {
        do {
            try UIProfileUpdateTask.configure()
            NSLog("setup background task success")
        } catch {
            NSLog("setup background task error: \(error.localizedDescription)")
        }
        Task {
            if UIDevice.current.userInterfaceIdiom == .phone {
                await requestNetworkPermission()
            }
            await setupBackground()
        }
    }

    private nonisolated func setupBackground() async {
        if #available(iOS 16.0, *) {
            do {
                let profileServer = try ProfileServer()
                profileServer.start()
                await MainActor.run {
                    self.profileServer = profileServer
                }
                NSLog("started profile server")
            } catch {
                NSLog("setup profile server error: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated func requestNetworkPermission() async {
        if await SharedPreferences.networkPermissionRequested.get() {
            return
        }
        if !DeviceCensorship.isChinaDevice() {
            await SharedPreferences.networkPermissionRequested.set(true)
            return
        }
        URLSession.shared.dataTask(with: URL(string: "http://captive.apple.com")!) { _, response, _ in
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    Task {
                        await SharedPreferences.networkPermissionRequested.set(true)
                    }
                }
            }
        }.resume()
    }
}

@available(iOS 10, *)
extension ApplicationDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 前台收到推送: \(userInfo)")

        // 记录前台收到推送事件
         SharedAnalyticsKit.shared.logPushNotification(
             event: "received_foreground",
             type: userInfo["type"] as? String
         )

        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 用户点击推送: \(userInfo)")

        // 记录用户点击推送事件
         SharedAnalyticsKit.shared.logPushNotification(
             event: "clicked",
             type: userInfo["type"] as? String
         )

        completionHandler()
    }
}
