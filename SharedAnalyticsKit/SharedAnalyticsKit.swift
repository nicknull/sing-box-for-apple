//
//  SharedAnalyticsKit.swift
//  sing-box-for-apple
//
//  Analytics统计共享模块入口
//

import Foundation
import UIKit
import Firebase
import FirebaseAnalytics
import FirebaseCrashlytics

public enum SharedAnalyticsKit {
    /// 获取Analytics管理器单例
    public static var shared: AnalyticsManager {
        AnalyticsManager.shared
    }

    /// 便捷方法：初始化Firebase配置
    public static func configure() {
        guard FirebaseApp.app() == nil else {
            print("🔥 Firebase already configured")
            return
        }

        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        print("🔥 Firebase Analytics & Crashlytics configured")
    }

    /// 便捷方法：记录应用启动
    public static func logAppLaunch() {
        shared.logCustomEvent(name: "app_launch", parameters: [
            "platform": "ios",
            "device_type": UIDevice.current.userInterfaceIdiom == .phone ? "iphone" : "ipad",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
    }
}
