//
//  Models.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/2.
//

import Foundation
import CodableWrappers
struct HotKey:Codable,Hashable,Identifiable{
    var id:String{return UUID().uuidString}
    var name:String
    var rtype:String
    var hotValue:String
}


struct AppVersion : Codable{
    var windows_version:String
    var windows_download_url:String
    var macos_version:String
    var macos_download_url:String
    var android_version:String
    var android_download_url:String
    var ios_version:String
    var ios_download_url:String
    var appletv_version:String
    var appletv_download_url:String
}
class AuthModel: Codable{
    @BoolAsIntCoding
    var is_admin :Bool
    var token : String
    var auth_data :String

    // OAuth 登录相关字段（可选，后端返回）
    var login_methods: [String]?  // 已绑定的登录方式列表，如 ["email", "apple", "google"]
    var is_new_user: Bool?  // 是否是新注册用户
}

class UserInfoModel:Codable{
    var email : String?
    var app_account_token: String?
    var transfer_enable : Int64?
    var last_login_at : TimeInterval?
    var created_at : TimeInterval?
    var expired_at : TimeInterval?
    @BoolAsIntCoding
    var banned : Bool
    var remind_expire : Int?
    var remind_traffic : Int64?
    var balance : Int
    var commission_balance : Int?
    var plan_id : Int?
//    var discount : Any?//未知数据
    var commission_rate : String?
    var telegram_id : String?
    var avatar_url : String?

    // OAuth 登录相关字段（可选）
    var login_methods: [String]?  // 已绑定的登录方式
    var has_password: Bool?  // 是否设置了密码（三方登录用户可能没有）
}



class SubscribeModel: Codable,Equatable{
    static func == (lhs: SubscribeModel, rhs: SubscribeModel) -> Bool {
        lhs.d == rhs.d &&  lhs.u == rhs.u &&  lhs.transfer_enable == rhs.transfer_enable &&  lhs.name == rhs.name &&  lhs.subscribe_url == rhs.subscribe_url &&  lhs.plan == rhs.plan 
    }
    
    var d :Int64?
    var u :Int64?
    var transfer_enable :Int64?
    var name :String?
    var subscribe_url:String?
    var sing_url:String?
    var plan:Plan?
}
class Plan:Codable,Equatable{
    static func == (lhs: Plan, rhs: Plan) -> Bool {
        lhs.id == rhs.id
    }
    var id:Int64
    var group_id:Int64
    var transfer_enable :Int64
    var name:String
    var speed_limit:Int64?
    var show:Int64
    var sort:Int64?
    var renew:Int64
    var content:String
    var month_price:Int64?
    var quarter_price:Int64?
    var half_year_price:Int64?
    var year_price:Int64?
    var reset_price:Int64?
    var reset_traffic_method:String?
    var created_at:TimeInterval
    var updated_at:TimeInterval

}

struct TicketModel: Codable, Identifiable {
    let id: Int
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
    let subject: String
    let level: Int
    let replyStatus: Int
    let status: Int
    let userId: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case subject
        case level
        case replyStatus = "reply_status"
        case status
        case userId = "user_id"
    }
}

struct TicketResponse: Codable {
    let data: MessageData  // 需要重命名结构体
}

struct MessageData: Codable {
    let message: [Message] // 直接包含消息数组
    let subject: String
    let status:Int
    let reply_status:Int

}

struct Message: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let ticket_id: Int
    let message: String
    let pic: String?
    let created_at: Int
    let updated_at: Int
    var is_me: Bool
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(created_at))
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}
struct CreateTicketResponse: Codable {
    let data: Bool?
    let message:String?
}
