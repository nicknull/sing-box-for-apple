import Foundation
import Moya

/// 对底层 Moya `Response` 的轻量封装，避免上层直接依赖 Moya。
public struct NetworkResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let data: Data
    public let original: Response

    public init(response: Response) {
        statusCode = response.statusCode
        headers = response.response?.allHeaderFields as? [String: String] ?? [:]
        data = response.data
        original = response
    }
}
