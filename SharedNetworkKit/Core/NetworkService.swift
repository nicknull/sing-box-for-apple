import Foundation
import Moya

/// 网络层统一入口，封装请求执行、解析与错误处理。
public final class NetworkService {
    public static let shared = NetworkService()

    private let client: NetworkClient
    private let decoder: JSONDecoder

    /// 捕获鉴权失效时需要广播的通知，默认为 `.authExpired`。
    public var authExpiredNotification: Notification.Name = .authExpired
    /// 触发鉴权失效通知的 HTTP 状态码集合。
    public var authExpiredStatusCodes: Set<Int> = [401, 403]

    public init(client: NetworkClient = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.client = client
        self.decoder = decoder
        self.decoder.allowsJSON5 = true
    }

    // MARK: - Callback 样式接口

    @discardableResult
    public func request<Model: Decodable>(
        _ target: TargetType & ResponseProvider,
        decodeTo modelType: Model.Type,
        progress: ProgressBlock? = .none,
        completion: @escaping (Result<APIResponseWithModel<Model>, NetworkRequestError>) -> Void
    ) -> Cancellable {
        return execute(target, progress: progress, transform: { context in
            guard let data = context.envelope.payloadData, !data.isEmpty else {
                return .success(APIResponseWithModel(context: context, model: nil))
            }
            do {
                let model = try self.decoder.decode(modelType, from: data)
                return .success(APIResponseWithModel(context: context, model: model))
            } catch {
                let requestError = NetworkRequestError(
                    error: .decoding(underlying: error, data: context.response.data),
                    context: context
                )
                return .failure(requestError)
            }
        }, completion: completion)
    }

    @discardableResult
    public func request(
        _ target: TargetType & ResponseProvider,
        progress: ProgressBlock? = .none,
        completion: @escaping (Result<APIResponseContext, NetworkRequestError>) -> Void
    ) -> Cancellable {
        return execute(target, progress: progress, transform: { context in
            .success(context)
        }, completion: completion)
    }

    // MARK: - async/await 接口

    public func request<Model: Decodable>(
        _ target: TargetType & ResponseProvider,
        decodeTo modelType: Model.Type
    ) async throws -> APIResponseWithModel<Model> {
        var cancellable: Cancellable?
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                cancellable = request(target, decodeTo: modelType) { result in
                    switch result {
                    case let .success(context):
                        continuation.resume(returning: context)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable = nil
                }
            }
        } onCancel: {
            cancellable?.cancel()
        }
    }

    public func request(
        _ target: TargetType & ResponseProvider
    ) async throws -> APIResponseContext {
        var cancellable: Cancellable?
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                cancellable = request(target) { result in
                    switch result {
                    case let .success(context):
                        continuation.resume(returning: context)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable = nil
                }
            }
        } onCancel: {
            cancellable?.cancel()
        }
    }

    // MARK: - 内部执行逻辑

    private func execute<Value>(
        _ target: TargetType & ResponseProvider,
        progress: ProgressBlock? = .none,
        transform: @escaping (APIResponseContext) -> Result<Value, NetworkRequestError>,
        completion: @escaping (Result<Value, NetworkRequestError>) -> Void
    ) -> Cancellable {
        return client.request(target, progress: progress) { [weak self] result in
            guard let self else { return }

            switch result {
           case let .success(response):
                self.notifyAuthExpiredIfNeeded(statusCode: response.statusCode)
                let parseResult = target.parseResponse(response)
                switch parseResult {
                case let .success(envelope):
                    let context = APIResponseContext(response: response, envelope: envelope)
                    completion(transform(context))

                case let .failure(error):
                    let requestError = NetworkRequestError(error: error)
                    completion(.failure(requestError))
                }

            case let .failure(error):
                if case let .server(statusCode, _, _) = error {
                    self.notifyAuthExpiredIfNeeded(statusCode: statusCode)
                }
                let requestError = NetworkRequestError(error: error)
                completion(.failure(requestError))
            }
        }
    }

    private func notifyAuthExpiredIfNeeded(statusCode: Int) {
        guard authExpiredStatusCodes.contains(statusCode) else { return }
        NotificationCenter.default.post(name: authExpiredNotification, object: nil)
    }
}
