import Foundation

public extension Notification.Name {
    /// 用户鉴权失效的全局通知名称，网络层在捕获到 401/403 时触发。
    static let authExpired = Notification.Name("authExpiredNotification")
}
