//
//  ResponseProvider.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import Moya
import SwiftyJSON
protocol ResponseProvider {
    func responsePrase(_ response:Response) ->NewResponseModel
}
