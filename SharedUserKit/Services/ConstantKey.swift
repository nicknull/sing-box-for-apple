//
//  ConstantKey.swift
//  ApplicationLibrary
//
//  Created by xiaokang chen on 2025/10/5.
//

import Foundation

@frozen public enum ConstantKey {
    public static let token = "token"
    public static let auth_data = "auth_data"
    public static let email = "emailKey"
    public static let is_admin = "is_admin"

    public static let password = "passwordKey"
    public static let userInfojson = "userInfojson"
    public static let subscribeInfojson = "subscribeInfojson"
    public static let suiteName = "group.\(Bundle.appID)"
    public static let host = "host"
    public static let local = "local"
    public static let repair = "repair"

    public static let apiHost = "apiHost"
    public static let frontHost = "frontHost"
    public static let fileContentHash = "fileContentHash"
    public static let confVersion = "confVersion"
    public static let releaseVersion = "releaseVersion"
    public static let consentAgreed = "consentAgreed"
    
    public static let getServiceTime = "getServiceTime"//上次更新主服务域名时间
    public static let secure_path = "secure_path"//后台管理路径，修改后将会改变原有的admin路径
}

struct VersionComparator {
    static func compare(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.components(separatedBy: ".")
        let components2 = version2.components(separatedBy: ".")

        let maxLength = max(components1.count, components2.count)

        for index in 0..<maxLength {
            let value1 = index < components1.count ? Int(components1[index]) ?? 0 : 0
            let value2 = index < components2.count ? Int(components2[index]) ?? 0 : 0

            if value1 < value2 {
                return -1
            } else if value1 > value2 {
                return 1
            }
        }

        return 0
    }
}

extension Bundle {
    
    public static var appID: String {
        Bundle.main.bundleIdentifier!
    }
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }
    public static var appBuildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }


    public static var tunnelBundleSuffix: String {
        Bundle.main.infoDictionary?["TUNNEL_BUNDLE_SUFFIX"] as! String
    }
}
