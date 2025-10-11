import ApplicationLibrary
import Defaults
import Foundation
import Libbox
import Library
import Network
import UIKit
// Firebase 已移除，使用原生 APNS
// import FirebaseCore
// import FirebaseMessaging

import UserNotifications

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    private var profileServer: ProfileServer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase 已移除
        // FirebaseApp.configure()
        // Messaging.messaging().delegate = self

        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        var error: NSError?
        LibboxSetup(options, &error)
        LibboxSetLocale(Locale.current.identifier)

        UNUserNotificationCenter.current().delegate = self

        // 注册原生 APNS 推送
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                NSLog("✅ 推送通知权限已授予 (iOS)")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                NSLog("❌ 推送通知权限被拒绝: \(error?.localizedDescription ?? "unknown")")
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
    }

    // 注册失败回调
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.handleRegistrationError(error)
        NSLog("❌ didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)")
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

// Firebase Messaging delegate 已移除
// extension ApplicationDelegate: MessagingDelegate { ... }

@available(iOS 10, *)
extension ApplicationDelegate: UNUserNotificationCenterDelegate {
    // 前台收到推送
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 前台收到推送: \(userInfo)")
        completionHandler([.banner, .badge, .sound])
    }

    // 用户点击推送
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 用户点击推送: \(userInfo)")
        completionHandler()
    }
}
