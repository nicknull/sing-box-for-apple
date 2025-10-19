import Foundation
import Moya

/// 为特定 API 提供额外插件（如日志、鉴权）。
public protocol NetworkPluginProvider {
    var plugins: [PluginType] { get }
}
