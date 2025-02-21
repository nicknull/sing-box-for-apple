//
//  DomainChecker.swift
//  sing-box
//
//  Created by xiaokang chen on 2024/3/13.
//

import Foundation
import Combine

enum DomainAvailability {
    case reachable
    case unreachable
    case error(String)
}

class DomainChecker {
    func checkDomain(domain: String) -> AnyPublisher<DomainAvailability, Never> {
        return Future<DomainAvailability, Never> { promise in
            guard let url = URL(string: "http://" + domain) else {
                promise(.success(.unreachable)) // Invalid URL
                return
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5 // Set timeout interval to 5 seconds

            URLSession.shared.dataTaskPublisher(for: request)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        if let urlError = error as? URLError, urlError.code == .timedOut {
                            promise(.success(.unreachable)) // Timeout occurred
                        } else {
                            promise(.success(.error(error.localizedDescription))) // Other networking error
                        }
                    }
                }, receiveValue: { data, response in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.success(.unreachable)) // Invalid response
                        return
                    }

                    let statusCode = httpResponse.statusCode
                    if statusCode < 200 || statusCode >= 300 {
                        promise(.success(.unreachable)) // HTTP request failed
                    } else {
                        promise(.success(.reachable)) // Domain is reachable
                    }
                })
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()
}

// Example usage:
