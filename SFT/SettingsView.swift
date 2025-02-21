//
//  SettingsView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/10.
//

import SwiftUI
enum SettingsType:String ,CaseIterable{
    case site = "官网"
    case feedBack = "反馈"
    case TgGroup = "Telegram"
    case iosVersion = "ios版本"
    case currentVersion = "当前版本号"
    case buildVersion = "编译版本号"
    case deviceId = "标识符"
    func pressed() {
    }
    func qrImage()->String{
        return "qr_login"
    }
    
}
struct SettingsView: View {
    @EnvironmentObject var userManager: UserManager
    
    @FocusState var focusedSettings: Focusable?
    @State var leftQR:String = "qr_site"
    @State var leftTitle:String = "扫码登录,在手机上管理您的内容吧"
    
    var body: some View {
        HStack{
            VStack{
                Image(leftQR )
                    .frame(width:400)
                    .padding(.horizontal,150)
                Text(leftTitle)
                    .font(.system(.footnote))
            }
            Form {
                ForEach(SettingsType.allCases , id: \.self) { type in
                    Button {
                    } label: {
                        HStack{
                            Text(type.rawValue)
                            Spacer()
//                            Text(rate.describe+"倍速")
//                                .font(.system(size: 30))
//                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10005"))
                    .focused($focusedSettings, equals: .row(id: "10005"))

                }
                /*
                Section(header:Text("设置:").font(.title2)) {
                    Button {
                    } label: {
                        HStack{
                            Text("默认播放速度:")
                            Spacer()
                            Text(rate.describe+"倍速")
                                .font(.system(size: 30))
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10005"))
                    .focused($focusedSettings, equals: .row(id: "10005"))
                    Button {
                        showStep.toggle()
                    } label: {
                        HStack{
                            Text("单次快进:")
                            Spacer()
                            Text("\(step)s")
                                .font(.system(size: 30))
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10013"))
                    .focused($focusedSettings, equals: .row(id: "10013"))
                    
                    Button {
                        confirm.toggle()
                    } label: {
                        HStack{
                            Text("快进确认:")
                            Spacer()
                            Text(confirm ? "需要确认":"不需要确认")
                                .font(.system(size: 30))
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10014"))
                    .focused($focusedSettings, equals: .row(id: "10014"))
                    
                    
                    
                    Button {
                    } label: {
                        HStack{
                            Text("意见反馈:")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10012"))
                    .focused($focusedSettings, equals: .row(id: "10012"))
                    
                    Button {
                    } label: {
                        HStack{
                            Text("扫码下载ios版本:")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10006"))
                    .focused($focusedSettings, equals: .row(id: "10006"))
                    Button {
                    } label: {
                        HStack{
                            Text("加入QQ群聊:")
                            Spacer()
                            Text("782838906")
                                .font(.system(size: 30))
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10007"))
                    .focused($focusedSettings, equals: .row(id: "10007"))
                    
                    Button {
                    } label: {
                        HStack{
                            Text("加入TG群聊:")
                            Spacer()
                            Text("https://t.me/+igI63y0SeQU2N2Fl")
                                .font(.system(size: 30))
                            Image(systemName: "chevron.right")
                        }
                    }
                    .id(Focusable.row(id: "10008"))
                    .focused($focusedSettings, equals: .row(id: "10008"))
                    
                }
                Section(header:Text("设备:").font(.title2)) {
                    Button {
                    } label: {
                        HStack{
                            Text("设备标识:")
                            Spacer()
                            Text(UIDevice.current.identifierForVendor!.uuidString)
                                .font(.system(size: 30))
                        }
                    }
                    .id(Focusable.row(id: "10009"))
                    .focused($focusedSettings, equals: .row(id: "10009"))
                    
                    Button {
                    } label: {
                        HStack{
                            Text("当前版本号：")
                            Spacer()
                            Text("\(.appVersion)")
                                .font(.system(size: 30))
                        }
                    }
                    .id(Focusable.row(id: "10010"))
                    .focused($focusedSettings, equals: .row(id: "10010"))
                    
                    Button {
                    } label: {
                        HStack{
                            Text("编译版本号：")
                            Spacer()
                            Text("\(.appBuildVersion)")
                                .font(.system(size: 30))
                        }
                    }
                    .id(Focusable.row(id: "10011"))
                    .focused($focusedSettings, equals: .row(id: "10011"))
                    
                }
                 */
            }
        }
        .onChangeCompat(of: focusedSettings, { newValue in
            
        })
    }
    
}

#Preview {
    SettingsView()
}
