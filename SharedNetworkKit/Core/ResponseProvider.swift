import Foundation

public protocol ResponseProvider {
    func parseResponse(_ response: NetworkResponse) -> Result<APIEnvelope, NetworkError>
}

public extension ResponseProvider {
    func parseResponse(_ response: NetworkResponse) -> Result<APIEnvelope, NetworkError> {
        do {
            let envelope = try APIEnvelope.parse(from: response)
            return .success(envelope)
        } catch let error as NetworkError {
            return .failure(error)
        } catch {
            return .failure(.underlying(error, data: response.data))
        }
    }
}
