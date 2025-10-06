//
//  SharedNotificationKit.swift
//  sing-box-for-apple
//
//  提供通知相关共享工具的集中入口，便于跨平台引用。
//

import Foundation

enum SharedNotificationKit {
    /// 访问全局的设备 Token 管理器实例。
    static var deviceTokenManager: DeviceTokenManager {
        DeviceTokenManager.shared
    }
}
