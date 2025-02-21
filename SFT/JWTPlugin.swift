//
//  JWTPlugin.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import SwiftUI
import Moya

class JWTPlugin: PluginType {
    static let shared = JWTPlugin()
    @AppStorage(ConstantKey.auth_data) var auth_data  = ""
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var updatedRequest = request
        // Add JWT token to the request headers
        updatedRequest.addValue("\(auth_data)", forHTTPHeaderField: "Authorization")
        return updatedRequest
    }
}
