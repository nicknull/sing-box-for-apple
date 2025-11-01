//
//  SharedCrashKit.swift
//  sing-box-for-apple
//
//  崩溃日志收集共享模块入口
//

import Foundation
import UIKit

public enum SharedCrashKit {
    /// 获取崩溃管理器单例
    public static var shared: CrashManager {
        CrashManager.shared
    }

    /// 便捷方法：安装崩溃收集器
    public static func install() {
        shared.install()
        print("🔍 SharedCrashKit configured")
    }

    /// 便捷方法：验证安装状态
    public static func verifyInstallation() -> Bool {
        shared.verifyInstallation()
    }

    /// 便捷方法：手动上报自定义崩溃信息
    /// 用于捕获非致命错误或特定业务逻辑错误
    public static func reportCustomCrash(
        errorName: String,
        errorMessage: String,
        stackTrace: [String]? = nil,
        additionalInfo: [String: Any]? = nil
    ) {
        shared.reportCustomCrash(
            errorName: errorName,
            errorMessage: errorMessage,
            stackTrace: stackTrace ?? Thread.callStackSymbols,
            additionalInfo: additionalInfo
        )
    }

    /// 便捷方法：记录关键业务事件（可用于崩溃分析上下文）
    public static func logEvent(name: String, parameters: [String: Any] = [:]) {
        shared.logEvent(name: name, parameters: parameters)
    }

#if DEBUG
    /// 便捷方法：触发测试崩溃（仅 Debug 版本）
    public static func triggerTestCrash(reason: String = "测试触发崩溃", signal: Int32 = SIGABRT) {
        shared.triggerTestCrash(reason: reason, signal: signal)
    }
#endif
}