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
            throw NetworkError.invalidResponse
        }
    }
}
