//
//  NewNetworkManager.swift
//  AQplayer
//
//  Created by WO on 2023/6/25.
//

import Foundation
import Moya
import SwiftyJSON
typealias NewRequestModelSuccessCallback<T:Codable> = ((T?,NewResponseModel) -> Void)
typealias NewRequestModelsSuccessCallback<T:Codable> = (([T]?,NewResponseModel) -> Void)
typealias NewRequestCallback = ((NewResponseModel) -> Void)
@discardableResult
func NewNetWorkRequest<T: Codable>(_ target: TargetType&ResponseProvider, modelType: T.Type, progress: ProgressBlock? = .none,successCallback:@escaping NewRequestModelSuccessCallback<T>, failureCallback: NewRequestCallback? = nil) -> Cancellable? {
    
    return NewNetWorkRequest(target,progress: progress, successCallback: {responseModel in
        guard let dataString = responseModel.dataString else{
            successCallback(.none,responseModel)
            return
        }
        do {
            let decoder:JSONDecoder = JSONDecoder()
            decoder.allowsJSON5 = true
            let result = try decoder.decode(modelType, from: dataString.data(using: .utf8)!)
            successCallback(result, responseModel)
        } catch {
            successCallback(.none,responseModel)
            print("解码错误: \(error)")
        }

    }, failureCallback: failureCallback)
}
@discardableResult
func NewNetWorkRequest(_ target:TargetType&ResponseProvider,progress: ProgressBlock? = .none,successCallback: @escaping NewRequestCallback, failureCallback: NewRequestCallback? = nil) -> Cancellable? {
    
    var plugins:[PluginType] = []
    let pluginTarget = ( target as?PlugProvider)
    if (pluginTarget != nil){
        plugins.append(contentsOf: pluginTarget!.plugins)
    }
    let provider = MoyaProvider<MultiTarget>(plugins:plugins)
    return provider.request(MultiTarget(target) ,progress: progress) { result in
        switch result {
        case let .success(response):
            
//            guard let json = try? JSON(data: response.data)else{
//                return
//            }
            let model:NewResponseModel = target.responsePrase(response)
            if model.code == 401 || model.code == 403 {
                NotificationCenter.default.post(name: .authExpired, object: nil)
            }
            successCallback(model)

        case let .failure(error as NSError):
            var model:NewResponseModel = NewResponseModel(code: error.code)
            model.messageStr = error.localizedDescription
            failureCallback?(model)
            print(error.localizedDescription)
        }
    }
}

