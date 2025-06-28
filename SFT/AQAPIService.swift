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
    case signIn(email:String,password:String) //登录
    case getUserInfo(apnsToken:String) //获取用户信息
    case getSubscribe //获取用户订阅信息
    case getService //获取服务的地址 host 是备用服务器地址
    case local(address:String)//扫码修复地址 服务器地址通过扫码保存到本地
//    case rerouter//获取解析地址
    case getVersion(token:String)
    case getTickets //用户端的工单列表
    case ticketFetch(id:Int) //获取工单回复列表
    case ticketReply(id:Int,message:String) //回复工单
    case ticketSave(subject:String,level:Int,message:String)//新建工单
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
            
        case .ticketReply(_,_):

            model.messageStr = json ["message"].stringValue
        case .ticketSave(_,_,_):

            model.messageStr = json ["message"].stringValue
            model.dataString = json.rawString()

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
            
        case .local:
            return URL.init(string:Defaults[.local])!
        case  .getService:
            return URL.init(string:Defaults[.repair])!//访问修复的备用服务器地址 1.txt
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
        case .getUserInfo(_):
            return "/user/info"
        case .getSubscribe:
            return "/user/getSubscribe"
        case .local(_):
            return "/local"
//        case .rerouter:
//            return "/router/1.txt"
        case .getVersion:
            return "/client/app/getVersion"
        case .getService:
            return "/1.txt"
        case .getTickets:
            return "/user/ticket/fetch"
            
        case .ticketFetch:
            return "/user/ticket/fetch"
        case .ticketReply(_,_): //回复工单
            return "/user/ticket/reply"
        case  .ticketSave://新建工单
            return "user/ticket/save"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .signIn(_,_):
            return .post
        case .ticketReply(_,_):
            return .post
        case .ticketSave(_,_,_):
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
        case let .getUserInfo(apnsToken):
            return .requestParameters(parameters: ["pushtoken": apnsToken], encoding: URLEncoding.default)
        case let .getVersion(token):
            return .requestParameters(parameters: ["token": token], encoding: URLEncoding.default)

        case let .local(address):
            return .requestParameters(parameters: ["address":address], encoding: URLEncoding.default)
            
        case let .ticketFetch(id):
            return .requestParameters(parameters: ["id":id], encoding: URLEncoding.default)
       
        case let .ticketReply(id,message):

            
            let parameters: [String: Any] = [
                           "id": id,
                           "message": message
                       ]
            return .requestParameters(parameters: parameters,encoding: URLEncoding.httpBody)

        case let .ticketSave(subject, level, message):
            return .requestParameters(parameters: ["subject":subject,"level":level,"message":message],encoding: URLEncoding.httpBody)
        default:
            return .requestPlain
        }

    }
    
    var headers: [String : String]? {
        switch self {
        case .ticketReply(_,_):
            return ["Content-Type": "application/x-www-form-urlencoded"]
        case .ticketSave(_,_,_):
            return ["Content-Type": "application/x-www-form-urlencoded"]

        default:

            return [:]
        }

    }
    
    
}
