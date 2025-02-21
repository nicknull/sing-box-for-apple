//
//  URL+Query.swift
//  SFI
//
//  Created by xiaokang chen on 2024/8/16.
//

import Foundation
extension URL {
    func queryItems() -> [String:String] {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
            else {
                return [:]
        }
        
        var found:[String:String] = [:]
        
        for queryItem in queryItems {
            if queryItem.value != nil {
                found[queryItem.name] = queryItem.value!
            }
        }
        
        return found
    }
    
}
