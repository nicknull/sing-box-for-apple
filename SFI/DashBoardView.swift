//
//  DashBoardView.swift
//  SFI
//
//  Created by xiaokang chen on 2023/12/8.
//

//
//  DashBoardView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/6.
//

import SwiftUI
import NetworkExtension
import Libbox
import Library
import ApplicationLibrary

import Lottie
import DynamicColor
import Foundation
import Defaults
enum FocusableField {
    case board
    case Media
}

struct DashBoardView: View {
    
    @State var presentLogView = false
    @AppStorage(ConstantKey.auth_data) private var auth_data  = ""
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.trafficFormatter) private var formatter: NumberFormatter
    @State private var alert: Alert?
    @State private var selectedItemIndex = 0
    @StateObject private var commandClient = CommandClient(.clashMode)
    @State private var clashMode = ""
    @State var showLogIn :Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width,height: geometry.size.height)
                if environments.extensionProfileLoading {
                    ProgressView()
                }
                else if environments.extensionProfile != nil {

                    StatusView()
                        .environmentObject(environments.extensionProfile!)
                } else {
                    VStack{
                        LottieView(animation: .named("unconnect"))
                            .looping()
                            .padding(.horizontal,40)
                        Button(action: {
                            Task {
                                await installProfile()
                                environments.postReload()
                                
                            }
                        }, label: {
                            Text("添加VPN配置")
                                .bold()
                                .frame(width: 260,height: 60)
                                .foregroundColor(.white)
                                .background(Color(hexString: "#016475"))
                                .cornerRadius(30)
                                .opacity(0.7)
                        })
                        .offset(x: 0, y: -60) // 在水平和垂直方向上将文本视图偏移 (20, 20) 个单位
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            environments.postReload()
            if(!userManager.isLoggedIn){
                showLogIn.toggle()
            }
            else{
                userManager.reload()
            }
            
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading:authStatusView(auth_data: auth_data,iconName: "person", destination: {
            UserView()
                .environmentObject(userManager)
                .environmentObject(environments)
        }))
        
        .navigationBarItems(trailing:authStatusView(auth_data: auth_data,iconName: "square.3.layers.3d", destination: {
            SettingsView()
                .environmentObject(environments)
        }))
        
        .alertBinding($alert)
        .fullScreenCover(isPresented: $showLogIn, content: {
            LoginView()
                .onDisappear {
                    userManager.reload()
                }
        })
        
    }
    @ViewBuilder
    func authStatusView<Destination: View>(auth_data: String,iconName: String, @ViewBuilder destination: () -> Destination) -> some View {
        if auth_data.count > 0 {
            NavigationLink(destination: destination()) {
                Image(systemName: iconName)
                    .fontWeight(.medium)
            }
        } else {
            Button {
                presentLogView.toggle()
            } label: {
                Image(systemName: iconName)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func installProfile() async {
        do {
            try await ExtensionProfile.install()
            environments.postReload()
        } catch {
            alert = Alert(error)
        }
    }
    
}
struct DetailView: View {
    var body: some View {
        Button(action: {
            
        }, label: {
            Text("Detail Page Content")
            
        })
        .navigationTitle("Detail Page")
    }
}
extension NEVPNStatus {
    
    var displayImage:String{
        switch self {
        case .connecting,.disconnecting,.reasserting:
            return "connecting"
        case .connected:
            return "connected"
        default:
            return "unconnect"
        }
    }
    var buttonTitle: String {
        switch self {
        case .invalid:
            return "不可用"
        case .connecting:
            return "正在连接..."
        case .connected:
            return "断开"
        case .reasserting:
            return "正在重连..."
        case .disconnecting:
            return "正在断开..."
        case .disconnected:
            return "连接"
        @unknown default:
            return "未知"
        }
    }
}
//extension Date{
//    func date2string()->String{
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd"
//        return dateFormatter.string(from: self)
//    }
//}
