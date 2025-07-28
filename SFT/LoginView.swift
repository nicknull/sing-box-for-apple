//
//  LoginView.swift
//  AQplayer
//
//  Created by WO on 2023/6/26.
//
import Foundation
import SwiftUI
import Libbox
import Library
import Foundation
import Lottie
import NetworkExtension
import DynamicColor
import ApplicationLibrary
import QRCode
import Defaults
import ExytePopupView
enum Focusable: Hashable {
    case none
    case row(id: String)
}
struct LoginView: View {
    @State var errorStr:String = ""
    @State var showingPopup: Bool = false
    
    @EnvironmentObject var userManager: UserManager
    
    //    @State var host: String = ""
    @State var email: String = ""
    @State var password: String = ""
    @Environment(\.dismiss) var dismiss
    @FocusState var focusedSettings: Focusable?
    @State var logining:Bool = false
    @State var showRepair:Bool = false
    
    //    @State var host  = ""
    var body: some View {
        VStack{
            
            HStack {
                // 左侧图标
                VStack{
                    Spacer()
                    
                    Text("扫码注册")
                        .font(.system(size: 30))
                    Image(uiImage: UIImage(cgImage: getQRImage()))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 400)
                        .padding(.horizontal, 50)
                    
                    Spacer()
                    
                }
                Spacer()
                // 右侧输入框和按钮
                VStack(spacing: 30) {
                    Spacer()
                    
                    Text("登录")
                        .font(.system(size: 50))
                    // Email 输入框
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .font(.system(size: 30))
                        .id(Focusable.row(id: "10002"))
                        .focused($focusedSettings, equals: .row(id: "10002"))
                    
                    // Password 输入框
                    SecureField("Password", text: $password)
                        .font(.system(size: 30))
                    
                        .id(Focusable.row(id: "10003"))
                        .focused($focusedSettings, equals: .row(id: "10003"))
                    
                    if logining{
                        HStack{
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("登录中...")
                        }
                        .frame(width: 850, height: 80)
                        
                    }else{
                        // 登录按钮
                        Button(action: {
                            // 在此处添加登录按钮的点击操作
                            login()
                        }) {
                            Text("登录")
                                .font(.system(size: 40))
                                .frame(width: 850, height: 80)
                                .cornerRadius(40)
                        }
                        .id(Focusable.row(id: "10004"))
                        .focused($focusedSettings, equals: .row(id: "10004"))
                        .disabled(!isValidEmail(email) || password.count<6)
                    }
                    Spacer()
                }
                .padding(.horizontal, 50)
                .frame(width: 1000)
            }
            Spacer()
            VStack{
                Text("登录即代表同意您与闪电播放器之间的协议，您需要遵守您当地的法律法规")
                    .font(.footnote)
                
                Text("闪电加速器不会收集您的用户数据，账号的所有解释权归机场所有")
                    .font(.footnote)
                    .padding(.bottom, 50)
//                Spacer()
                Text("闪电加速器需要您的机场完成对sing-box协议的支持")
                    .font(.system(size: 22).monospacedDigit())
            }
            HStack{
                Spacer()
                    Button {
                        showRepair.toggle()
                    } label: {
                        Label("修复", systemImage: "checkmark.shield")
                    }
                    .padding(.trailing,60)
                    .sheet(isPresented: $showRepair, content: {
                        RepairView()
                    })
            }
            
            
        }
        .onAppear(){
            email = userManager.email
            password = userManager.password
        }
        .popup(isPresented: $showingPopup) {
            HStack{
                Text(errorStr)
                    .padding(40)
            }
            .background(.gray)
            .cornerRadius(30.0)
        } customize: {
            $0.autohideIn(2)
        }
        
        .onChange(of: userManager.subscribe, perform: { newValue in
            print("------userManager.subscribe-------")
            print(newValue)
        })
#if os(tvOS)
        .onExitCommand(perform: {
            
        })
#endif
    }
    func getQRImage() -> CGImage {
        do {
            let doc = try QRCode.Document(utf8String: Defaults[.host])
            let cgImage = try doc.cgImage(dimension: 400)
            return cgImage
        } catch {
            let defaultIcon = UIImage(named: "defaultIcon") // 假设您有一个名为"defaultIcon"的图标资源
            return defaultIcon!.cgImage!
        }
    }
    func login() {
        if email.isEmpty{
            return
        }
        if password.count<6{
            return
        }
        
        if !isValidEmail(email){
            return
        }
        logining = true
        NewNetWorkRequest(AQAPIService.signIn(email: email, password: password), modelType: AuthModel.self) { authModel, responseModel in
            guard (authModel?.auth_data) != nil else {
                logining = false
                
                if (responseModel.messageStr != nil){
                    errorStr = responseModel.messageStr!
                    showingPopup.toggle()
                }else{
                    errorStr = "登录失败，请稍后再试或尝试修复"
                    showingPopup.toggle()
                }
                return
            }
            userManager.is_admin = authModel!.is_admin
            userManager.email = email
            userManager.password = password
            userManager.auth_data = authModel!.auth_data
            userManager.token = authModel!.token
            Task {
                userManager.reload()
                logining = false
                dismiss()
            }
        }
    }
    func isValidEmail(_ email: String) -> Bool {
        // 正则表达式来验证邮箱地址
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}
