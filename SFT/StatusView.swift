//
//  StatusView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/10.
//

import SwiftUI
import Lottie
import NetworkExtension
import Libbox
import Library
import ApplicationLibrary
import Defaults
import ExytePopupView
struct StatusView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @EnvironmentObject private var extensionProfile: ExtensionProfile
    @State private var alert: Alert?
    @State var showLogIn :Bool = false
    @EnvironmentObject var userManager: UserManager
    
    @State private var errorTitle = ""
    @State private var errorSubTitle = ""
    @State private var errorAlert = false
    
    @MainActor
    @State private var showingPopup = false
    @MainActor
    @State private var pinTitle = ""
    
    @AppStorage(ConstantKey.userInfojson) private var userInfoJsonStr  = ""
    @AppStorage(ConstantKey.subscribeInfojson) private var subscribeInfoJsonStr  = ""
    @AppStorage(ConstantKey.auth_data) private var auth_data  = ""
    
    @State private var profile:Profile?
    var webSite:URL{
        return URL(string: "\(Defaults[.host])")!
    }
    
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
    @State private var animation: LottieAnimation = .named("unconnect")!
    var body: some View {
        VStack{

            switch extensionProfile.status {
            case .connecting,.disconnecting,.reasserting:
                
                LottieView {
                    animation
                }
                .looping()
#if os(iOS)
                .padding(.horizontal,40)
#elseif os(tvOS)
                .frame(width: 600,height: 600)
                .offset(x: 0, y: -60) // 在水平和垂直方向上将文本视图偏移 (20, 20) 个单位
#endif
            default:
                LottieView {
                    animation
                }
                .looping()
#if os(iOS)
                .padding(.horizontal,40)
#elseif os(tvOS)
                .frame(width: 600,height: 600)
                .offset(x: 0, y: -60) // 在水平和垂直方向上将文本视图偏移 (20, 20) 个单位
#endif
                
            }
            Spacer()
            
            Button(action: {
                Task { @MainActor in
                    if (subscribe != nil && (subscribe!.d! + subscribe!.u! >= subscribe!.transfer_enable!))
                    {
                        errorTitle = "流量已用尽"
                        errorSubTitle = "请登录网站续费后使用"
                        errorAlert.toggle()
                    }else if userInfo != nil && userInfo!.expired_at != nil && userInfo!.expired_at!<Date().timeIntervalSince1970{
                        errorTitle = "订阅已到期"
                        errorSubTitle = "请登录网站续费后使用"
                        errorAlert.toggle()
                    }
                    else if auth_data.count == 0 {
                        showLogIn.toggle()
                    }
                    else if(!userManager.isLoggedIn){
                        showLogIn.toggle()
                    }else if(environments.extensionProfileLoading){

                    }else if((profile == nil)){
                        errorTitle = "正在加载资源"
                        errorSubTitle = "请稍候，等待加载成功后连接"
                        errorAlert.toggle()
                        userManager.getSubscribe()
                        environments.profileUpdate.send()
                        environments.selectedProfileUpdate.send()

                    }
                    else{
                        if extensionProfile.status == .disconnected {
                            Task{
//                            let profiles = try await ProfileManager.list()
//                            if profiles.count == 0 {
//                                await userManager.createProfile0()
//                                environments.postReload()
//                            }
                            await switchProfile(true)
                        }
                    }else if extensionProfile.status == .connected {
                        Task {
                            await switchProfile(false)
                        }
                    }
                    }
                }
            }, label: {
                Text(btnTitle())
                    .bold()
                    .frame(width: 260,height: 60)
                    .foregroundColor(.white)
                    .background( (extensionProfile.status == .connecting||extensionProfile.status == .disconnecting||extensionProfile.status == .reasserting||(profile == nil && userManager.loadingProfile)) ? Color.gray:Color(hexString: "#016475"))
                    .cornerRadius(30)
                    .opacity(0.7)
            })
            .padding(.bottom,50)
            //        .offset(x: 0, y: -60) // 在水平和垂直方向上将文本视图偏移 (20, 20) 个单位
            .disabled(extensionProfile.status == .connecting||extensionProfile.status == .disconnecting||extensionProfile.status == .reasserting||(profile == nil && userManager.loadingProfile))
            .sheet(isPresented: $showLogIn, content: {
                LoginView()
            })
            .alert(isPresented: $errorAlert, content: {
                Alert(
                    title: Text(errorTitle),
                    message: Text(errorSubTitle),
                    primaryButton: .destructive(Text("前往")) {
                        UIApplication.shared.open(webSite)
                    },
                    secondaryButton: .cancel(Text("取消"), action: {
                        
                    })
                )
            })
            .onChange(of: extensionProfile.status, perform: { newValue in
                animation = .named(extensionProfile.status.displayImage)!
            })
            .popup(isPresented: $showingPopup) {
                Text(pinTitle)
                    .background(Color(red: 0.85, green: 0.8, blue: 0.95))
                    .cornerRadius(30.0)
            } customize: {
                $0.autohideIn(2)
            }
        }

        
        .onAppear {
//            Task{
//                await setDefaultProfile()
//            }
            if profile == nil{
                userManager.getSubscribe()
                environments.profileUpdate.send()
                environments.selectedProfileUpdate.send()
            }
        }
        .onReceive(environments.selectedProfileUpdate) { _ in
            Task {
                guard let profileTemp = try await ProfileManager.get(by: "iFlash")else{
                    return
                }
                profile = profileTemp
            }
        }
        
    }
    
    func btnTitle() -> String {
        var btnTitle = "连接"
        if (subscribe != nil && (subscribe!.d! + subscribe!.u! >= subscribe!.transfer_enable!))
        {
            btnTitle = "流量已用尽"
        }else if userInfo != nil && userInfo!.expired_at != nil && userInfo!.expired_at!<Date().timeIntervalSince1970{
            btnTitle = "订阅已到期"
        }
        else if auth_data.count == 0 {
            btnTitle = "登录"
        }else if profile == nil{
            if userManager.loadingProfile {
                btnTitle = "正在下载配置"
            }else{
                btnTitle = "加载配置"
            }
        }
        else {
            btnTitle = extensionProfile.status.buttonTitle
        }
        
        return btnTitle
    }
    private nonisolated func setDefaultProfile() async {
        
        Task{
            do {
                
                let profileList = try await ProfileManager.list()
                if profileList.isEmpty {
                    await MainActor.run {
                        pinTitle = "正在加载资源"
                        showingPopup.toggle()
                    }
                    return
                }
                var selectedProfileID = await SharedPreferences.selectedProfileID.get()
                if profileList.filter({ profile in profile.id == selectedProfileID}).isEmpty {
                    selectedProfileID = profileList[0].id!
                    await SharedPreferences.selectedProfileID.set(selectedProfileID)
                    await MainActor.run {
                        profile = profileList[0]
                    }

                }
            } catch {
                print(error)
//                                await MainActor.run {
//                                    alert = Alert(error)
//                                }
            }
        }
    }
    
    private nonisolated func switchProfile(_ isEnabled: Bool) async {
        Task{
            await setDefaultProfile()
        }
        
        do {
            if isEnabled {
                
                do{
                    try await extensionProfile.start()
                    await environments.logClient.connect()

                }catch{
                    print(error)

                }
            } else {
                try await extensionProfile.stop()
            }
        } catch {
            await MainActor.run {
                alert = Alert(error)
            }
        }
    }
    
}

#Preview {
    StatusView()
}
