//
//  AQAPIService.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import Moya
import SwiftyJSON
import Defaults

enum AQAPIService{
    case signIn(email:String,password:String)
    case getUserInfo
    case getSubscribe
    case getService
    case repair(address:String)//解析 api 面板及备用地址
//    case rerouter//获取解析地址
    case getVersion(token:String)
}
extension AQAPIService:TargetType,ResponseProvider,PlugProvider{
    func responsePrase(_ response:Response) -> NewResponseModel {
        guard let json = try? JSON(data: response.data)else{
            var model = NewResponseModel(code: -1)
            model.messageStr = "非json格式的数据"
            model.dataString = String(data: response.data, encoding: .utf8) 
            return model
        }

        let code = response.statusCode
        var model = NewResponseModel(code: code)
        model.dataString = json["data"].rawString()
        switch self{
        case .signIn(_,_):
            if (json["errors"].dictionary != nil){
                let error  = json["errors"].dictionary![(json["errors"].dictionary?.keys.first)!]?.array?.first?.string
                model.messageStr = error

            }else{
                model.messageStr = json ["message"].stringValue

            }

        default:
            model.messageStr = json ["msg"].stringValue
        }
        return model
    }
    
    var plugins: [Moya.PluginType] {
        switch self {
        case .signIn(_,_):
            return [LoggingPlugin.shared]
        default:
            return[LoggingPlugin.shared,JWTPlugin.shared]
        }
        

    }
    
    var baseURL: URL {
        switch self {
            
        case .repair:
            return URL.init(string:Defaults[.repair])!
        case  .getService:
            return URL.init(string:"http://x.331237.xyz")!
//        case .rerouter:
//            return URL.init(string:Defaults[.host])!
        default:
            return URL.init(string:("\(Defaults[.host])/api/v1"))!
        }
    }

    var path: String {
        switch self {
        case .signIn(_,_):
            return "/passport/auth/login"
        case .getUserInfo:
            return "/user/info"
        case .getSubscribe:
            return "/user/getSubscribe"
        case .repair(_):
            return "/repair"
//        case .rerouter:
//            return "/router/1.txt"
        case .getVersion:
            return "/client/app/getVersion"
        case .getService:
            return "/1.txt"
        }
        

    }
    
    var method: Moya.Method {
        switch self {
        case .signIn(_,_):
            return .post
        case .getVersion(_):
            return .get
        default:
            return .get
        }
    }
    
    var task: Moya.Task {
        switch self {
        case let .signIn(email, password):
            return .requestParameters(parameters: ["email": email, "password": password], encoding: JSONEncoding.default)
        case let .getVersion(token):
            return .requestParameters(parameters: ["token": token], encoding: URLEncoding.default)

        case let .repair(address):
            return .requestParameters(parameters: ["address":address], encoding: URLEncoding.default)
        default:
            return .requestPlain
        }

    }
    
    var headers: [String : String]? {
        return [:]

    }
    
    
}
