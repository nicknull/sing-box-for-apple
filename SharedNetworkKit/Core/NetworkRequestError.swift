import Foundation

/// 表示一次请求的失败结果，携带网络错误及可用的上下文。
public struct NetworkRequestError: Error {
    public let error: NetworkError
    public let context: APIResponseContext?

    public init(error: NetworkError, context: APIResponseContext? = nil) {
        self.error = error
        self.context = context
    }

    public var message: String {
        context?.message ?? error.message
    }

    public var apiCode: Int {
        context?.apiCode ?? error.code
    }

    public var httpStatusCode: Int {
        context?.httpStatusCode ?? {
            if case let .server(statusCode, _, _) = error {
                return statusCode
            } else {
                return 0
            }
        }()
    }

    /// 获取错误相关的原始响应数据
    /// 优先从 context 获取，如果没有则从 error 中获取
    public var rawData: Data? {
        return context?.response.data ?? error.rawData
    }

    /// 获取原始响应数据的字符串表示
    public var rawDataString: String? {
        guard let data = rawData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 获取原始 JSON 字符串（如果有的话）
    public var rawJSON: String? {
        return context?.rawJSON ?? {
            guard let data = rawData else { return nil }
            return String(data: data, encoding: .utf8)
        }()
    }
}

extension NetworkRequestError: LocalizedError {
    public var errorDescription: String? { message }
}
