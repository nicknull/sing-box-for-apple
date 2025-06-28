//
//  DashBoardView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/6.
//

import SwiftUI
import Lottie
import NetworkExtension
import Libbox
import Library
import DynamicColor
import ApplicationLibrary
import Foundation
import Defaults
import ExytePopupView
import SwiftDate

enum FocusableField {
    case board
    case Media
}

struct DashBoardView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.trafficFormatter) private var formatter: NumberFormatter
    
    @State private var alert: Alert?
    @State private var selectedItemIndex = 0
    @StateObject private var commandClient = CommandClient(.clashMode)
    @State private var clashMode = ""
    @State var showLogIn :Bool = false
    @State var showRepair:Bool = false

    @Namespace var mainNamespace
    @State var section: FocusableField = .board
    @Environment(\.resetFocus) var resetFocus
//    @State private var appStoreVersion: String?
    @State private var profile:Profile?
    @State private var isLoading = false

    var body: some View {
        HStack{
            VStack{
                Spacer()
                if environments.extensionProfileLoading {
                    ProgressView()
                } else if environments.extensionProfile != nil {
                    StatusView()
                        .environmentObject(environments.extensionProfile!)
                } else {
                    LottieView(animation: .named("unconnect"))
                        .looping()
                        .frame(width: 600,height: 600)
                        .offset(x: 0, y: -60) // 在水平和垂直方向上将文本视图偏移 (20, 20) 个单位
                    
                    Button(action: {
                        Task {
                            await installProfile()
//                            if try await ProfileManager.list().count==0 {
//                                await userManager.createProfile0()
//                            }
                            environments.postReload()
                        }
                    }, label: {
                        Text("添加VPN配置")
                            .bold()
                            .frame(width: 260,height: 60)
                            .foregroundColor(Color(hexString: "#016475"))
                            .cornerRadius(30)
                            .opacity(0.7)
                    })
                    Spacer()
                }
            }
            .frame(width: 800)
            .onMoveCommand(){direction in
                if direction == .right{
                    self.section = .Media
                    resetFocus(in: mainNamespace)
                    
                }
            }
            .prefersDefaultFocus(section == .board, in: mainNamespace)
            .focusSection()
            
            
            Spacer(minLength: 40)
            NavigationView {
                List {
                    Section {
                        Button(action: {}, label: {
                            LabeledContent {
                                Text(userManager.email)
                                    .foregroundColor(Color.secondary)
                                    .padding(.vertical,5)
                            } label: {
                                Text("邮箱")
                                
                            }
                        })
                        
                        Button(action: {}, label: {
                            
                            LabeledContent {
                                let date = Date(timeIntervalSince1970: userManager.userInfo?.expired_at ?? 100*365*24*60*60)
                                Text(date.date2string())
                                    .foregroundColor(Color.secondary)
                                    .padding(.vertical,5)
                            } label: {
                                Text("有效期")
                                
                            }
                        })
                        
                        if userManager.subscribe != nil{
                            Button(action: {}, label: {
                                
                                LabeledContent {
                                    Text(userManager.subscribe?.name ?? "-")
                                } label: {
                                    Label {
                                        Text("套餐")
                                            .padding(.horizontal,20)
                                    } icon: {
                                        IVYIcon(systemName: "info", backgroundColor: .indigo)
                                    }
                                }
                            })

                            if showProducts()  {
                                NavigationLink(destination:
                                                ProductsView()
                                    .environmentObject(userManager)
                                               
                                    .navigationTitle("购买套餐")
                                               
                                ) {
                                    Label {
                                        Text("购买套餐")
                                            .padding(.horizontal,20)
                                    } icon: {
                                        IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
                                    }
                                }
                                
                            }

                            Button(action: {}, label: {
                                
                                LabeledContent {
                                    Text(formatter.string(from: userManager.subscribe!.u! as NSNumber) ?? "-")
                                } label: {
                                    Label {
                                        Text("上行")
                                            .padding(.horizontal,20)
                                    } icon: {
                                        IVYIcon(systemName: "arrow.up.right", backgroundColor: .purple)
                                    }
                                }
                            })
                            Button(action: {}, label: {
                                
                                LabeledContent {
                                    Text(formatter.string(from: userManager.subscribe!.d! as NSNumber) ?? "-")
                                } label: {
                                    Label {
                                        Text("下行")
                                            .padding(.horizontal,20)
                                        
                                    } icon: {
                                        IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
                                    }
                                }})
                            Button(action: {}, label: {
                                
                                LabeledContent {
                                    Text(formatter.string(from: userManager.subscribe!.transfer_enable! as NSNumber) ?? "-")
                                } label: {
                                    Label {
                                        Text("总计")
                                            .padding(.horizontal,20)
                                    } icon: {
                                        IVYIcon(systemName: "person", backgroundColor: Color(hexString: "#478fee"))
                                    }
                                }
                            })
                            
                            if  (environments.extensionProfile != nil) && profile != nil{
                                Button {
                                    isLoading = true
                                    Task {
                                        await updateProfile()
                                    }
                                } label: {
                                    HStack{
                                        Label("更新线路", systemImage: "arrow.clockwise")
                                        Spacer()
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                        }else{
                                            Text(profile?.lastUpdated?.toString() ?? "未知")
                                                .font(.footnote)
                                        }
                                        
                                    }
                                }
                                .disabled(isLoading)
                            }

                        }

                    } header: {
                        Text("个人信息")
                    }



                    
                    Section{
                        Button {
                            showRepair.toggle()

                        } label: {
                            LabeledContent {
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(.secondary)
                                    .opacity(0.7)

                            } label: {
                                Label {
                                    Text("修复")
                                } icon: {
                                    IVYIcon(systemName: "qrcode.viewfinder", backgroundColor: .brown)
                                }
                            }
                        }


                        .sheet(isPresented: $showRepair, content: {
                            RepairView()
                                .environmentObject(userManager)
                        })

                    }header: {
                        Text("修复登录")
                    }
                    if environments.extensionProfile?.status == .connected{
                        Section {
                            NavigationLink(destination:
                                            GroupListView()
                                .navigationTitle("线路")
                                           
                            ) {
                                Label {
                                    Text("线路")
                                        .padding(.horizontal,20)
                                } icon: {
                                    IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
                                }
                            }
                            
                            NavigationLink(destination:
                                            ModeView()
                                .navigationTitle("模式")
                                .focusSection()
                            )
                            {
                                Label {
                                    Text("模式")
                                        .padding(.horizontal,20)
                                } icon: {
                                    IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
                                }
                            }
                            
                        }header: {
                            Text("配置")
                        }
                    }
                    Section{
                        Button {
                        } label: {
                            LabeledContent {
                                Text(Defaults[.host])
                            } label: {
                                Label {
                                    Text("官网")
                                        .padding(.horizontal,20)
                                } icon: {
                                    IVYIcon(systemName: "house", backgroundColor: Color(hexString: "#68a1f1"))
                                }
                            }
                        }
                        Button {
                        } label: {
                            LabeledContent {
                                Text(Bundle.appVersion)
                            } label: {
                                Label {
                                    Text("版本")
                                        .padding(.horizontal,20)
                                } icon: {
                                    IVYIcon(systemName: "location", backgroundColor: Color(hexString: "#bf473d"))
                                }
                            }
                            
                        }
                        
                        Button {
                            userManager.logout()
                            showLogIn.toggle()
                            
                        } label: {
                            LabeledContent {
                                Text("退出")
                            } label: {
                                Label {
                                    Text("账号")
                                        .padding(.horizontal,20)
                                } icon: {
                                    IVYIcon(systemName: "arrow.triangle.branch", backgroundColor: Color(hexString: "#01E905"))
                                }
                            }
                            
                        }
                    }
                    header: {
                        Text("其他")
                    }
                }
                .scrollClipDisabled()
                .padding(.horizontal,40)
            }
            .onMoveCommand(){direction in
                if direction == .left{
                    self.section = .board
                    resetFocus(in: mainNamespace)
                }
            }
            .prefersDefaultFocus(section == .Media, in: mainNamespace)
            .focusSection()
        }
        .alertBinding($alert)
        .onAppear {
            environments.postReload()
            if(!userManager.isLoggedIn){
                showLogIn.toggle()
            }else{
                userManager.reload()
            }
        }
        .sheet(isPresented: $showLogIn, content: {
            LoginView()
        })

        .onReceive(environments.selectedProfileUpdate) { _ in
            Task {
                guard let profileTemp = try await ProfileManager.get(by: "iFlash")else{
                    return
                }
                profile = profileTemp
            }
        }
        
        
    }
    func showProducts()->Bool{
        return true
        //        return appStoreVersion == nil || compareVersions(version1:Bundle.main.infoDictionary?["CFBundleVersion"] as! String, version2:  appStoreVersion!) == .orderedAscending
    }
    func compareVersions(version1: String, version2: String) -> ComparisonResult {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }
        
        for (component1, component2) in zip(components1, components2) {
            if component1 < component2 {
                return .orderedAscending
            } else if component1 > component2 {
                return .orderedDescending
            }
        }
        
        if components1.count < components2.count {
            return .orderedAscending
        } else if components1.count > components2.count {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    
//    func fetchAppStoreVersion() {
//        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
//            return
//        }
//        
//        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)"
//        if let url = URL(string: urlString) {
//            let task = URLSession.shared.dataTask(with: url) { data, _, error in
//                if let data = data {
//                    do {
//                        let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//                        if let resultsArray = result?["results"] as? [[String: Any]],
//                           let appStoreVersion = resultsArray.first?["version"] as? String {
//                            DispatchQueue.main.async {
//                                self.appStoreVersion = appStoreVersion
//                            }
//                        }
//                    } catch {
//                        print(error.localizedDescription)
//                    }
//                }
//            }
//            
//            task.resume()
//        }
//    }
    
    private func installProfile() async {
        do {
            try await ExtensionProfile.install()
            environments.postReload()
        } catch {
            alert = Alert(error)
        }
    }
    private func updateProfile() async {
        if profile == nil {
            return
        }
        defer {
            isLoading = false
        }
        do {
            //
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
            try await profile!.updateRemoteProfile()
            environments.profileUpdate.send()
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
extension Date{
    func date2string()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }
}
