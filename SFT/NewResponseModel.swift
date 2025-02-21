//
//  NewResponseModel.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
struct NewResponseModel {
    var code: Int//-1 数据异常返回
    var messageStr: String?//错误信息
    var dataString: String?//有效返回值用于解析 model
}
