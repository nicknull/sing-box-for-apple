//
//  Defaults.swift
//  SFT
//
//  Created by xiaokang chen on 2023/12/8.
//
import Defaults
import Foundation
public extension Defaults.Keys {
    
    
    
    
    static let host = Key<String>(ConstantKey.host, default: "http://ww.wefesr.shop")
    static let local = Key<String>(ConstantKey.local, default: "")
    static let repair = Key<String>(ConstantKey.repair, default: "http://x.2314124.xyz")//iOS扫 Apple TV 端获取到的地址
    static let confVersion = Key<String>(ConstantKey.confVersion, default: "3.7")
    static let releaseVersion = Key<String>(ConstantKey.releaseVersion, default: "3.7")
    static let getServiceTime = Key<Double>(ConstantKey.getServiceTime, default: 0)  //更新 api时间戳
    static let secure_path = Key<String>(ConstantKey.secure_path, default: "629908e0")//后端查看 php

    
}
