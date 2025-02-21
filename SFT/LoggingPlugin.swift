//
//  LoggingPlugin.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import Moya
class LoggingPlugin: PluginType {
    static let shared = LoggingPlugin()

    func willSend(_ request: RequestType, target: TargetType) {
        if let request = request.request {
            print("--> Request:")
            print("URL: \(request.url?.absoluteString ?? "")")
            print("Method: \(request.httpMethod ?? "")")
            if let headers = request.allHTTPHeaderFields {
                print("Headers: \(headers)")
            }
            if let bodyData = request.httpBody {
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    print("Body: \(bodyString)")
                }
            }
            print("\n")
        }
    }
    
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        switch result {
        case .success(let response):
            print("<-- Response:")
            print("URL: \(response.request?.url?.absoluteString ?? "")")
            print("Status code: \(response.statusCode)")
            if let responseData = try? response.mapString() {
                print("Response data: \(responseData)")
            } else {
                print("Failed to parse response data.")
            }
            print("\n")
        case .failure(let error):
            print("<-- Error:")
            print("URL: \(error.response?.request?.url?.absoluteString ?? "")")
            print("Error: \(error.localizedDescription)")
            print("\n")
        }
    }
}
