import Foundation

/// 描述底层网络与解析阶段的通用错误。
public enum NetworkError: Error {
    case cancelled
    case notConnected
    case timeout
    case invalidResponse
    case server(statusCode: Int, message: String?, data: Data?)
    case decoding(underlying: Error)
    case underlying(Error)
}

public extension NetworkError {
    /// 映射到统一的错误码，便于沿用旧逻辑。
    var code: Int {
        switch self {
        case .cancelled:
            return NSURLErrorCancelled
        case .notConnected:
            return NSURLErrorNotConnectedToInternet
        case .timeout:
            return NSURLErrorTimedOut
        case .invalidResponse:
            return -7000
        case let .server(statusCode, _, _):
            return statusCode
        case .decoding:
            return -7001
        case .underlying:
            return -7002
        }
    }

    /// 提供适合 UI 展示的文案。
    var message: String {
        switch self {
        case .cancelled:
            return "请求已取消"
        case .notConnected:
            return "当前网络不可用"
        case .timeout:
            return "请求超时，请稍后再试"
        case .invalidResponse:
            return "响应格式无效"
        case let .server(_, message, _):
            return message ?? "服务器返回错误"
        case let .decoding(error):
            return "数据解析失败：\(error.localizedDescription)"
        case let .underlying(error):
            return error.localizedDescription
        }
    }

    /// 对是否可以自动重试给出建议。
    var shouldRetry: Bool {
        switch self {
        case .cancelled:
            return false
        case .notConnected:
            return false
        case .timeout:
            return true
        case .invalidResponse:
            return false
        case let .server(statusCode, _, _):
            return statusCode >= 500 && statusCode < 600
        case .decoding:
            return false
        case .underlying:
            return false
        }
    }
}
