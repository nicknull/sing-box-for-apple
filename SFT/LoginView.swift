//
//  LoginView.swift
//  SFT (tvOS)
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
import AuthenticationServices

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

    // OAuth 管理器
    @StateObject private var oauthManager = OAuthManager(
        googleClientID: "YOUR_GOOGLE_CLIENT_ID",
        githubClientID: "YOUR_GITHUB_CLIENT_ID"
    )
    
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
                        // 传统邮箱登录按钮
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

                        // 三方登录分隔线
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2)
                            Text("或使用第三方登录")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                        .frame(width: 850)
                        .padding(.top, 20)

                        // 三方登录按钮（tvOS 样式）
                        VStack(spacing: 20) {
                            // Apple 登录
                            Button(action: {
                                handleAppleSignIn()
                            }) {
                                HStack {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 30))
                                    Text("使用 Apple 登录")
                                        .font(.system(size: 32))
                                        .fontWeight(.medium)
                                }
                                .frame(width: 850, height: 80)
                                .foregroundColor(.white)
                                .background(Color.black)
                                .cornerRadius(40)
                            }
                            .id(Focusable.row(id: "10005"))
                            .focused($focusedSettings, equals: .row(id: "10005"))
                            .disabled(logining || oauthManager.isLoading)
                            // Google/GitHub 登录已隐藏

                            // GitHub 登录
                            Button(action: {
                                handleGitHubSignIn()
                            }) {
                                HStack {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 30))
                                    Text("使用 GitHub 登录")
                                        .font(.system(size: 32))
                                        .fontWeight(.medium)
                                }
                                .frame(width: 850, height: 80)
                                .foregroundColor(.white)
                                .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                                .cornerRadius(40)
                            }
                            .id(Focusable.row(id: "10007"))
                            .focused($focusedSettings, equals: .row(id: "10007"))
                            .disabled(logining || oauthManager.isLoading)
                        }
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

            // 设置 OAuth 回调
            setupOAuthCallbacks()
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
        .popup(isPresented: Binding(get: { oauthManager.isLoading }, set: { _ in }), view: {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在请求 Apple 登录...")
                        .font(.footnote)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .shadow(radius: 12)
            }
        }) { popup in
            popup
                .type(.floater())
                .position(.center)
                .animation(.easeInOut(duration: 0.25))
                .closeOnTap(false)
                .closeOnTapOutside(false)
                .dragToDismiss(false)
                .backgroundColor(Color.black.opacity(0.25))
                .autohideIn(nil)
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

    // MARK: - 设置 OAuth 回调
    func setupOAuthCallbacks() {
        oauthManager.onSuccess = { [self] authModel in
            DispatchQueue.main.async {
                // 保存用户信息
                userManager.auth_data = authModel.auth_data
                userManager.token = authModel.token
                userManager.is_admin = authModel.is_admin

                Task {
                    userManager.reload()
                    logining = false
                    dismiss()
                }
            }
        }

        oauthManager.onFailure = { error in
            DispatchQueue.main.async {
                errorStr = error
                showingPopup = true
                logining = false
            }
        }
    }

    // MARK: - Apple 登录处理
    func handleAppleSignIn() {
        logining = true
        oauthManager.signInWithApple()
    }

    // MARK: - Google 登录处理
    func handleGoogleSignIn() {
        logining = true
        oauthManager.signInWithGoogle()
    }

    // MARK: - GitHub 登录处理
    func handleGitHubSignIn() {
        logining = true
        oauthManager.signInWithGitHub()
    }
}
