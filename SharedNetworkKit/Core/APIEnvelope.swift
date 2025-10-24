import Foundation
import SwiftyJSON

/// 提取后端统一返回格式中的业务字段。
public struct APIEnvelope {
    public var apiCode: Int
    public var message: String?
    public var payloadData: Data?
    public var rawJSON: String?

    public init(apiCode: Int, message: String?, payloadData: Data?, rawJSON: String?) {
        self.apiCode = apiCode
        self.message = message
        self.payloadData = payloadData
        self.rawJSON = rawJSON
    }

    public static func parse(from response: NetworkResponse) throws -> APIEnvelope {
        // 首先尝试解析为 JSON
        do {
            let json = try JSON(data: response.data)
            let message = json["msg"].string ?? json["message"].string
            let dataNode = json["data"]
            let dataString = dataNode.rawString(options: [.sortedKeys]) ?? dataNode.rawString()
            let payloadData = dataString?.data(using: .utf8)
            return APIEnvelope(
                apiCode: json["code"].intValue,
                message: message,
                payloadData: payloadData,
                rawJSON: json.rawString()
            )
        } catch {
            // JSON 解析失败，但如果是 200 状态码，则视为成功的非 JSON 响应
            if response.statusCode == 200 {
                // 对于非 JSON 的成功响应，将原始数据作为 payload
                let rawString = String(data: response.data, encoding: .utf8)
                return APIEnvelope(
                    apiCode: 200, // 使用 HTTP 状态码作为 apiCode
                    message: "Success",
                    payloadData: response.data,
                    rawJSON: rawString
                )
            } else {
                // 其他情况仍然抛出包含原始数据的错误
                throw NetworkError.invalidResponse(data: response.data)
            }
        }
    }
}
