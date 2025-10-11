//
//  UserManager.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/4.
//

import Foundation
import SwiftUI
import Library
import Libbox
import CryptoSwift
import Defaults
// Firebase 已移除，使用原生 APNS
// import FirebaseCore
// import FirebaseMessaging
import ApplicationLibrary

class UserManager: ObservableObject {
    @AppStorage(ConstantKey.email) var email: String = ""
    @AppStorage(ConstantKey.password) var password: String = ""
    @AppStorage(ConstantKey.auth_data) var auth_data  = ""
    @AppStorage(ConstantKey.token) var token  = ""
    @AppStorage(ConstantKey.is_admin) var is_admin: Bool = false
    @AppStorage(ConstantKey.userInfojson) private var userInfoJsonStr  = ""
    @AppStorage(ConstantKey.subscribeInfojson) private var subscribeInfoJsonStr  = ""
    @AppStorage(ConstantKey.fileContentHash) private var fileContentHash  = ""
    
    var loadingProfile:Bool = false
    var userInfo:UserInfoModel?{
        let decoder:JSONDecoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let result = try? decoder.decode(UserInfoModel.self, from: userInfoJsonStr.data(using: .utf8)!)
        return result
        
    }
    var subscribe:SubscribeModel?{
        let decoder:JSONDecoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let result = try? decoder.decode(SubscribeModel.self, from: subscribeInfoJsonStr.data(using: .utf8)!)
        return result
    }
    var outTraffic:Bool{
        if (subscribe != nil && (subscribe!.d! + subscribe!.u! < subscribe!.transfer_enable!))
        {
            return false
        }else{
            return true
        }
    }
    var outDate:Bool{
        
        if userInfo != nil && userInfo!.expired_at != nil && userInfo!.expired_at!>Date().timeIntervalSince1970{
            return false
        }else{
            return true
        }
    }
    var isLoggedIn: Bool{
        !auth_data.isEmpty
    }
    var reloading:Bool{
        refreshingUserInfo||gettingSubscribe
    }
    @State private var refreshingUserInfo :Bool = false
    @State private var gettingSubscribe :Bool = false
    
    func logout() {
        // 移除设备 Token
        DeviceTokenManager.shared.removeToken()

        self.email = ""
        self.password = ""
        self.auth_data = ""
        self.token = ""
        Task{
            await deleteProfile0()
        }
    }
    func reload(){
        Task{
            refreshUserInfo()
            getSubscribe()
            getReleaseVer()
        }
    }
    func  getReleaseVer(){
        NewNetWorkRequest(AQAPIService.getVersion(token: self.token), modelType: AppVersion.self) { appVersion, responseModel in

            if( appVersion != nil){
#if os(iOS)
                Defaults[.releaseVersion]  = appVersion!.ios_version
#elseif os(tvOS)
                Defaults[.releaseVersion]  = appVersion!.appletv_version
#endif


//                Default(.releaseVersion) = appVersion!.ios_version
//                if(VersionComparator.compare(Bundle.appVersion, appVersion!.ios_version)>0){
//                    Task{
//                        await self.makeOrder(product: product)
//                    }
//                }else{
//                    self.errorTitle = "当前服务不可用"
//                    self.errorSubTitle = "请从官网获取开通相关服务"
//                    self.errorAlert.toggle()
//                }
            }
        }

    }
    func refreshUserInfo() {
        refreshingUserInfo = true

        // APNS Token 已在 ApplicationDelegate 中注册并上传
        // iOS/tvOS 统一使用原生 APNS

        NewNetWorkRequest(AQAPIService.getUserInfo(apnsToken: ""), modelType:UserInfoModel.self) { [self] (userInfo, responseModel) in
            refreshingUserInfo = false
            if userInfo != nil {
                userInfoJsonStr = responseModel.dataString!

                // 登录成功后，触发 APNS Token 上传（如果还未上传）
                NSLog("✅ 用户信息刷新成功，APNS Token 会在设备注册后自动上传")
            } else {
                if responseModel.code == 403 {
                    logout()
                }
            }
        }
    }
    func apnsTokenString(from deviceToken: Data) -> String {
        return deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    }

    func getSubscribe() {
        if(gettingSubscribe){
            return
        }
        gettingSubscribe = true
        
        

        
        NewNetWorkRequest(AQAPIService.getSubscribe,modelType:SubscribeModel.self) { [self] (subscribe,responseModel) in
            gettingSubscribe = false
            if(( subscribe) != nil){
                subscribeInfoJsonStr = responseModel.dataString!
                Task{
                    await updateProfile()
                }
            }
        }
    }
    
    private func deleteProfile0()  async{
        do{
            guard let profile0 = try await ProfileManager.get(by: "iFlash") else{
                return
            }
            try await ProfileManager.delete(profile0)
            
        }catch{
            print("Error: \(error)")
            
        }
    }
    
    func updateProfile()async{
        do{
            let id  = await SharedPreferences.selectedProfileID.get()
            let profile = try await  ProfileManager.get(id)
            guard let remoteURL = subscribe?.sing_url ?? subscribe?.subscribe_url else {
                return
            }
            if profile != nil {
                if profile?.remoteURL != remoteURL{
                    profile?.remoteURL = remoteURL
                }
                let timeDifference = Date().timeIntervalSince(profile!.lastUpdated!)
                if timeDifference<60*4 {
                    return
                }
                try await profile?.updateRemoteProfile()
                try LibboxNewStandaloneCommandClient()?.serviceReload()
            }else{
                try await createProfile0()
            }
        }catch{
            print("Error: \(error)")
        }
    }
    func createProfile0() async throws{
        do {
            guard let remoteURL = subscribe?.sing_url ?? subscribe?.subscribe_url else {
                return
            }
            
            loadingProfile = true
            let nextProfileID = try await ProfileManager.nextID()
            let remoteContent = try HTTPClient().getString(remoteURL)
            loadingProfile = false

            let remoteContentHash = remoteContent.md5()
            let empty = try await ProfileManager.list().isEmpty
            if fileContentHash == remoteContentHash && !empty{
                return
            }
            
            DispatchQueue.main.async {
                self.fileContentHash = remoteContentHash
            }
            
            
            var error: NSError?
            LibboxCheckConfig(remoteContent, &error)
            if let error {
                throw error
            }
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try remoteContent.write(to: profileConfig, atomically: true, encoding: .utf8)
            let savePath = profileConfig.relativePath
            let lastUpdated:Date = .now
            try await ProfileManager.create(Profile(
                name: "iFlash",
                type: .remote,
                path: savePath,
                remoteURL: remoteURL,
                autoUpdate: true,
                autoUpdateInterval: 60,
                lastUpdated: lastUpdated
            ))
            try  UIProfileUpdateTask.configure()
            await SharedPreferences.selectedProfileID.set(nextProfileID)
        } catch {
            print("Error: \(error)")
            throw error
            // 处理错误
        }
    }
    
    
}

