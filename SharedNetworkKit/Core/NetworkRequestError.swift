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
}

extension NetworkRequestError: LocalizedError {
    public var errorDescription: String? { message }
}
