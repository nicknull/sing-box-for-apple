import Foundation

/// 封装后端返回的基础数据，便于调用层读取公共字段。
public struct APIResponseContext {
    public let response: NetworkResponse
    public let envelope: APIEnvelope

    public init(response: NetworkResponse, envelope: APIEnvelope) {
        self.response = response
        self.envelope = envelope
    }

    public var httpStatusCode: Int { response.statusCode }
    public var headers: [String: String] { response.headers }
    public var apiCode: Int { envelope.apiCode }
    public var message: String? { envelope.message }
    public var payloadData: Data? { envelope.payloadData }
    public var rawJSON: String? { envelope.rawJSON }

    public var payloadString: String? {
        guard let data = payloadData else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// 携带泛型模型的响应上下文。
public struct APIResponseWithModel<Model> {
    public let context: APIResponseContext
    public let model: Model?

    public init(context: APIResponseContext, model: Model?) {
        self.context = context
        self.model = model
    }
}
