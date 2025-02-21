//
//  PlugProvider.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import Moya
protocol PlugProvider {
    var plugins: [PluginType] { get }
}
