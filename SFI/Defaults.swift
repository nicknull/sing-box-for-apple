//
//  Defaults.swift
//  SFT
//
//  Created by xiaokang chen on 2023/12/8.
//
import Defaults
import Foundation
extension Defaults.Keys {
    static let host = Key<String>(ConstantKey.host, default: "http://x.sdsxc.xyz:85")
    static let repair = Key<String>(ConstantKey.repair, default: "http://x.sdsxc.xyz:85")//iOS扫 Apple TV 端获取到的地址
    static let confVersion = Key<String>(ConstantKey.confVersion, default: "2.9")
    static let releaseVersion = Key<String>(ConstantKey.releaseVersion, default: "2.9")
    static let getService = Key<Double>(ConstantKey.getService, default: 0)    
}
