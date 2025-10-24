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
    case getUserInfo //获取用户信息
    case getSubscribe //获取用户订阅信息
    case getService //获取服务的地址 host 是备用服务器地址
    case local(address:String)//扫码修复地址 服务器地址通过扫码保存到本地
//    case rerouter//获取解析地址
    case getVersion(token:String)
    case getTickets //用户端的工单列表
    case ticketFetch(id:Int) //获取工单回复列表
    case ticketReply(id:Int,message:String,imageData:Data?) //回复工单
    case ticketSave(subject:String,level:Int,message:String)//新建工单
    case ticketClose(id:Int) //关闭工单

    // IAP 订单相关
    case reportIAPOrder(transactionID:String, originalTransactionID:String, productID:String, tradeNo:String?, appAccountToken:String?) //上报 IAP 订单
    case prepareIAPOrder(productID:String, appAccountToken:String) // 预下单，获取 trade_no
    case restoreIAPOrders(appAccountToken:String, transactions:[[String:Any]]) // 恢复购买

    // OAuth 登录相关
    case oauthAppleLogin(identityToken:String, userIdentifier:String, email:String?, fullName:String?) //Apple 登录
    case oauthGoogleLogin(authorizationCode:String) //Google 登录
    case oauthGitHubLogin(authorizationCode:String) //GitHub 登录

    // OAuth 账号绑定/解绑
    case bindAppleAccount(identityToken:String, userIdentifier:String) //绑定 Apple 账号
    case bindGoogleAccount(authorizationCode:String) //绑定 Google 账号
    case bindGitHubAccount(authorizationCode:String) //绑定 GitHub 账号
    case unbindOAuthAccount(provider:String) //解绑 OAuth 账号（provider: "apple"/"google"/"github"）

    case getTickets_admin(pageSize:Int,current:Int,status:Int) //管理员 工单列表
    case ticketFetch_admin(id:Int) //管理员 获取工单回复列表
    case ticketReply_admin(id:Int,message:String,imageData:Data?) //管理员 回复工单
    case ticketClose_admin(id:Int) //管理员 关闭工单

    // 设备推送 Token 相关
    case registerDeviceToken(token:String, platform:String) //注册 APNS Device Token (iOS/tvOS)
    case unregisterDeviceToken //注销 Device Token
    case testPush(title:String, body:String) //测试推送
    case getPlans // 获取可用套餐列表

    // 试用功能相关
    case getTrialInfo // 获取试用信息
    case claimTrial // 领取试用

    // 崩溃日志上报
    case reportCrash(userInfo:[String:Any], deviceInfo:[String:Any], crashInfo:[String:Any]) // 上报崩溃日志

}
extension AQAPIService: TargetType, ResponseProvider, NetworkPluginProvider {
    func parseResponse(_ response: NetworkResponse) -> Result<APIEnvelope, NetworkError> {
        do {
            var envelope = try APIEnvelope.parse(from: response)

            // 只有在是 JSON 响应时才进行特殊处理
            if let json = try? JSON(data: response.data) {
                switch self {
                case .signIn(_, _):
                    if let errors = json["errors"].dictionary,
                       let key = errors.keys.first,
                       let message = errors[key]?.array?.first?.string {
                        envelope.message = message
                    } else {
                        envelope.message = json["message"].string ?? envelope.message
                    }

                case .ticketReply, .ticketSave, .ticketClose,
                     .ticketReply_admin, .ticketClose_admin:
                    envelope.message = json["message"].string ?? envelope.message
                    envelope.payloadData = json.rawString()?.data(using: .utf8)

                default:
                    break
                }
            }
            // 对于非 JSON 响应，APIEnvelope.parse 已经处理了，无需额外处理

            return .success(envelope)
        } catch let error as NetworkError {
            return .failure(error)
        } catch {
            return .failure(.underlying(error, data: response.data))
        }
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
        case .getUserInfo:
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
        case .ticketReply(_,_,_): //回复工单
            return "/user/ticket/reply"
        case  .ticketSave://新建工单
            return "user/ticket/save"
        case .ticketClose(_):
            return "user/ticket/close"

        case .reportIAPOrder(_,_,_,_,_):
            return "/user/order/iap"
        case .prepareIAPOrder(_,_):
            return "/user/order/iap/prepare"
        case .restoreIAPOrders(_, _):
            return "/user/order/iap/restore"

        case .oauthAppleLogin(_,_,_,_):
            return "/passport/auth/apple"
        case .oauthGoogleLogin(_):
            return "/passport/auth/google"
        case .oauthGitHubLogin(_):
            return "/passport/auth/github"

        case .bindAppleAccount(_,_):
            return "/user/oauth/bind/apple"
        case .bindGoogleAccount(_):
            return "/user/oauth/bind/google"
        case .bindGitHubAccount(_):
            return "/user/oauth/bind/github"
        case .unbindOAuthAccount(_):
            return "/user/oauth/unbind"

        case .getTickets_admin(_,_,_):
            return "/\(Defaults[.secure_path])/ticket/fetch"
        case .ticketFetch_admin(_):
            return "/\(Defaults[.secure_path])/ticket/fetch"
        case .ticketReply_admin(_,_,_):
            return "/\(Defaults[.secure_path])/ticket/reply"
        case .ticketClose_admin(_):
            return "\(Defaults[.secure_path])/ticket/close"

        case .registerDeviceToken(_,_):
            return "/user/device/register"
        case .unregisterDeviceToken:
            return "/user/device/unregister"
        case .testPush(_,_):
            return "/user/device/test-push"
        case .getPlans:
            return "/user/plan/fetch"
        case .getTrialInfo:
            return "/user/trial/info"
        case .claimTrial:
            return "/user/trial/claim"
        case .reportCrash(_,_,_):
            return "/user/crash/report"
        }
        


        
    }
    
    var method: Moya.Method {
        switch self {
        case .signIn(_,_):
            return .post
        case .getVersion(_):
            return .get
            
        case .ticketReply(_,_,_):
            return .post
        case .ticketSave(_,_,_):
            return .post
        case .ticketClose(_):
            return .post

        case .reportIAPOrder(_,_,_,_,_), .prepareIAPOrder(_,_), .restoreIAPOrders(_, _):
            return .post

        case .oauthAppleLogin(_,_,_,_):
            return .post
        case .oauthGoogleLogin(_):
            return .post
        case .oauthGitHubLogin(_):
            return .post

        case .bindAppleAccount(_,_):
            return .post
        case .bindGoogleAccount(_):
            return .post
        case .bindGitHubAccount(_):
            return .post
        case .unbindOAuthAccount(_):
            return .post

        case .ticketReply_admin(_,_,_):
            return .post
        case .ticketClose_admin(_):
            return .post

        case .registerDeviceToken(_,_):
            return .post
        case .unregisterDeviceToken:
            return .post
        case .testPush(_,_):
            return .post

        case .claimTrial:
            return .post

        case .reportCrash(_,_,_):
            return .post

        default:
            return .get
        }
    }
    
    var task: Moya.Task {
        switch self {
        case let .signIn(email, password):
            return .requestParameters(parameters: ["email": email, "password": password], encoding: JSONEncoding.default)
        case .getUserInfo:
            return .requestPlain
        case let .getVersion(token):
            return .requestParameters(parameters: ["token": token], encoding: URLEncoding.default)

        case let .local(address):
            return .requestParameters(parameters: ["address":address], encoding: URLEncoding.default)
            
            
        //用户工单相关
        case let .ticketFetch(id):
            return .requestParameters(parameters: ["id":id], encoding: URLEncoding.default)
        case let .ticketReply(id,message,imageData):
            let parameters: [String: Any] = [
                           "id": id,
                           "message": message
                       ]
            
            if((imageData) != nil){
                let formData = MultipartFormData(provider: .data(imageData!), name: "image",
                                                  fileName: "ticket.png", mimeType: "image/png")
                return .uploadCompositeMultipart([formData], urlParameters: parameters)
            }
            else{
                return .requestParameters(parameters: parameters,encoding: URLEncoding.httpBody)

            }
        case let .ticketSave(subject, level, message):
            return .requestParameters(parameters: ["subject":subject,"level":level,"message":message],encoding: URLEncoding.httpBody)
            
        case let .ticketClose(id):
            return .requestParameters(parameters: ["id":id], encoding: URLEncoding.default)

        case let .reportIAPOrder(transactionID, originalTransactionID, productID, tradeNo, appToken):
            var params: [String: Any] = [
                "transaction_id": transactionID,
                "original_transaction_id": originalTransactionID,
                "product_id": productID
            ]
            if let t = tradeNo { params["trade_no"] = t }
            if let a = appToken { params["app_account_token"] = a }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
        case let .prepareIAPOrder(productID, appToken):
            return .requestParameters(parameters: [
                "product_id": productID,
                "app_account_token": appToken
            ], encoding: JSONEncoding.default)
        case let .restoreIAPOrders(appToken, transactions):
            return .requestParameters(parameters: [
                "app_account_token": appToken,
                "transactions": transactions
            ], encoding: JSONEncoding.default)

        case let .oauthAppleLogin(identityToken, userIdentifier, email, fullName):
            var params: [String: Any] = [
                "identity_token": identityToken,
                "user_identifier": userIdentifier
            ]
            if let email = email {
                params["email"] = email
            }
            if let fullName = fullName {
                params["full_name"] = fullName
            }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)

        case let .oauthGoogleLogin(authorizationCode):
            return .requestParameters(parameters: [
                "authorization_code": authorizationCode
            ], encoding: JSONEncoding.default)

        case let .oauthGitHubLogin(authorizationCode):
            return .requestParameters(parameters: [
                "authorization_code": authorizationCode
            ], encoding: JSONEncoding.default)

        case let .bindAppleAccount(identityToken, userIdentifier):
            return .requestParameters(parameters: [
                "identity_token": identityToken,
                "user_identifier": userIdentifier
            ], encoding: JSONEncoding.default)

        case let .bindGoogleAccount(authorizationCode):
            return .requestParameters(parameters: [
                "authorization_code": authorizationCode
            ], encoding: JSONEncoding.default)

        case let .bindGitHubAccount(authorizationCode):
            return .requestParameters(parameters: [
                "authorization_code": authorizationCode
            ], encoding: JSONEncoding.default)

        case let .unbindOAuthAccount(provider):
            return .requestParameters(parameters: [
                "provider": provider
            ], encoding: JSONEncoding.default)

        //管理员工单相关
            
        case let .getTickets_admin(pageSize, current, status):
            return .requestParameters(parameters: ["pageSize":pageSize,"current":current,"status":status], encoding: URLEncoding.default)

        case let .ticketFetch_admin(id):
            return .requestParameters(parameters: ["id":id], encoding: URLEncoding.default)
       
        case let .ticketReply_admin(id,message,imageData):

            
            let parameters: [String: Any] = [
                           "id": id,
                           "message": message
                       ]
            
            if((imageData) != nil){
                let formData = MultipartFormData(provider: .data(imageData!), name: "image",
                                                  fileName: "ticket.png", mimeType: "image/png")
                return .uploadCompositeMultipart([formData], urlParameters: parameters)
            }
            else{
                return .requestParameters(parameters: parameters,encoding: URLEncoding.httpBody)

            }
        case let .ticketClose_admin(id):
            return .requestParameters(parameters: ["id":id], encoding: URLEncoding.default)


        case let .registerDeviceToken(token, platform):
            return .requestParameters(parameters: [
                "device_token": token,
                "platform": platform
            ], encoding: JSONEncoding.default)

        case .unregisterDeviceToken:
            return .requestPlain

        case let .testPush(title, body):
            return .requestParameters(parameters: [
                "title": title,
                "body": body
            ], encoding: JSONEncoding.default)
        case .getPlans:
            return .requestPlain
        case .getTrialInfo:
            return .requestPlain
        case .claimTrial:
            return .requestPlain

        case let .reportCrash(userInfo, deviceInfo, crashInfo):
            let parameters: [String: Any] = [
                "user_info": userInfo,
                "device_info": deviceInfo,
                "crash_info": crashInfo,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)

        default:
            return .requestPlain
        }

    }
    
    var headers: [String : String]? {
        switch self {
            
        case .ticketReply(_,_,_):
            return ["Content-Type": "application/x-www-form-urlencoded"]
        case .ticketSave(_,_,_):
            return ["Content-Type": "application/x-www-form-urlencoded"]

        case .ticketReply_admin(_,_,_):
            return ["Content-Type": "application/x-www-form-urlencoded"]

        default:

            return [:]
        }

    }
    
    
}
