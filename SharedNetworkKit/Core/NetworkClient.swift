import Foundation
import Moya

/// 底层网络客户端，负责与 MoyaProvider 交互并统一错误映射。
public final class NetworkClient {
    public static let shared = NetworkClient()

    private let providerBuilder: ([PluginType]) -> MoyaProvider<MultiTarget>
    private let callbackQueue: DispatchQueue?

    public init(
        callbackQueue: DispatchQueue? = nil,
        providerBuilder: @escaping ([PluginType]) -> MoyaProvider<MultiTarget> = { plugins in
            MoyaProvider<MultiTarget>(plugins: plugins)
        }
    ) {
        self.callbackQueue = callbackQueue
        self.providerBuilder = providerBuilder
    }

    @discardableResult
    public func request(
        _ target: TargetType & ResponseProvider,
        progress: ProgressBlock? = .none,
        completion: @escaping (Result<NetworkResponse, NetworkError>) -> Void
    ) -> Cancellable {
        let plugins = (target as? NetworkPluginProvider)?.plugins ?? []
        let provider = providerBuilder(plugins)

        return provider.request(
            MultiTarget(target),
            callbackQueue: callbackQueue,
            progress: progress
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(response):
                completion(.success(NetworkResponse(response: response)))

            case let .failure(error):
                completion(.failure(self.mapError(error)))
            }
        }
    }

    private func mapError(_ error: MoyaError) -> NetworkError {
        switch error {
        case let .underlying(underlyingError, response):
            let data = response?.data
            if let urlError = underlyingError as? URLError {
                switch urlError.code {
                case .cancelled:
                    return .cancelled
                case .notConnectedToInternet, .networkConnectionLost:
                    return .notConnected
                case .timedOut:
                    return .timeout
                default:
                    return .underlying(urlError, data: data)
                }
            }
            return .underlying(underlyingError, data: data)

        case let .statusCode(response):
            let message = String(data: response.data, encoding: .utf8)
            return .server(statusCode: response.statusCode, message: message, data: response.data)

        case let .objectMapping(error, response):
            return .decoding(underlying: error, data: response.data)
        case let .encodableMapping(error):
            return .decoding(underlying: error, data: nil)
        case let .parameterEncoding(error):
            return .decoding(underlying: error, data: nil)
        case let .jsonMapping(response):
            return .invalidResponse(data: response.data)
        case let .imageMapping(response):
            return .invalidResponse(data: response.data)
        case let .stringMapping(response):
            return .invalidResponse(data: response.data)
        case .requestMapping:
            return .invalidResponse(data: nil)

        @unknown default:
            return .underlying(error, data: nil)
        }
    }
}
