//
//  LoginView.swift
//  Pomelo
//
//  Created by xiaokang chen on 2023/3/22.
//

import SwiftUI
import UIKit
import Combine

import AuthenticationServices
//import MarkdownUI
import NetworkExtension
import DynamicColor
import Libbox
import Library
import Defaults
import SafariServices
import BetterSafariView
import ExytePopupView
struct LoginView: View {

    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var userManager: UserManager

    @State var emailInput: String = ""
    @State var passwordInput: String = ""
    @State var popUp: Bool = false
    @StateObject private var oauthManager = OAuthManager(
        googleClientID: "YOUR_GOOGLE_CLIENT_ID",
        githubClientID: "YOUR_GITHUB_CLIENT_ID"
    )
    @State private var currentAction: LoginAction?
    
    @AppStorage(ConstantKey.auth_data, store: .standard) private var auth_data  = ""
    @AppStorage(ConstantKey.email, store: .standard) private var email  = ""
    @AppStorage(ConstantKey.password, store: .standard) private var password  = ""
    @State var showLink:Bool = false
    @State var link:URL?
    @AppStorage(ConstantKey.consentAgreed) private var agreed: Bool = true

    private enum LoginAction: Equatable {
        case credentials
        case apple
        case google
        case github
    }

    private var isProcessing: Bool { currentAction != nil }

    // 不随键盘移动页面；通过可滚动表单避免遮挡

    var body: some View {
        ZStack{
            VStack() {
                Image("fog")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.top,0)
                    .edgesIgnoringSafeArea(.top)
                Spacer()
            }
            VStack() {
                VStack() {
                Spacer(minLength: 5)
                VStack(alignment: .trailing){
                    HStack{
                        Text("闪电加速器")
                            .font(.title)
                            .bold()
                            .padding(20)
                            .foregroundColor(Color("blueblue"))
                        Spacer()
                    }
                }
                
                // 登录方式（仅表单区域可滚动，页面不整体位移）
                ScrollView {
                    VStack(alignment: .center, spacing: 12) {
                        VStack(){
                        Spacer(minLength: 20)
                        HStack{
                            Text("用户名:")
                                .frame(width: 80 ,height: 40,alignment: .trailing)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color("blueblue"))
                                .disabled(isProcessing)
                            TextField("请输入用户名", text: $emailInput)
                                .padding(.leading,10)
                                .frame(height: 40)
                                .textFieldStyle(UnderLineTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .disabled(isProcessing)
                        }.padding(.horizontal,20)
                        HStack{
                            Text("密    码:")
                                .frame(width: 80 ,height: 40,alignment: .trailing)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color("blueblue"))
                            
                            SecureField("请输入密码", text: $passwordInput) {
                                print("Your password is \(self.passwordInput)!")
                            }
                            .padding(.leading,10)
                            .frame(height: 40)
                            .textFieldStyle(UnderLineTextFieldStyle())
                            .disabled(isProcessing)
                        }.padding(.horizontal,20)
                        Button {
                            guard currentAction == nil else { return }
                            if !agreed {
                                HUDManager.showFailure("请先勾选同意《用户协议》和《隐私政策》")
                                return
                            }
                            loginBtnPressed()
                        } label: {
                            Text(currentAction == .credentials ? "正在登录…" : "马上登录")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color("blueblue"))
                                .cornerRadius(22)
                        }
                        .disabled(!agreed || isProcessing)
                        .opacity((!agreed || isProcessing) ? 0.6 : 1.0)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)

                        // 第三方登录分隔线（仅保留 Apple 登录）
                        HStack(alignment: .center, spacing: 8) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                            Text("或使用第三方登录")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 4)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)

                        // 第三方登录按钮（仅保留 Apple）
                        HStack(spacing: 24) {
                            VStack(spacing: 6) {
                                Button(action: { handleAppleSignIn() }) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                }
                                .disabled(isProcessing || !agreed)
                                .opacity(agreed ? 1.0 : 0.5)
                                Text("Apple").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 20)

                        HStack{
                            Spacer()
                            
                            ButtonWithSafari(stringURL: "\(Defaults[.host])/#/register") {
                                HStack {
                                    Spacer()
                                    Text("注册账号")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color("blueblue"))
                                    Spacer()
                                }
                                .frame(height: 44)
                                .background(Color.clear)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 22)
//                                        .stroke(Color("blueblue"), lineWidth: 1)
//                                )
                            }
                            .disabled(!agreed || isProcessing)
                            .opacity((!agreed || isProcessing) ? 0.5 : 1.0)
//
                            Spacer()
                        }
                            Spacer()
                        }
                    }
                    .padding(.bottom, 12)
                    .scrollIndicators(.never)
                }
                Spacer(minLength: 0)
                
                
                HStack(spacing: 8){
                    Button(action: { agreed.toggle() }) {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .foregroundColor(agreed ? Color("blueblue") : .secondary)
                    }
                    Text("登录即表明同意")
                    ButtonWithSafari(stringURL: Defaults[.host]+"/agreement.html") {
                        Text("[用户协议]")
                    }
                    ButtonWithSafari(stringURL: Defaults[.host]+"/protocol.html") {
                        Text("[隐私政策]")
                    }
                }
                .padding(.bottom,40)
                
                }
            }
            .popup(isPresented: $popUp, view: {
                PopupMiddle {
                    if let url = URL(string: "mailto:LightningVPN888@gmail.com?subject=无法注册&body=请回复我最新的可访问的网址\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n") {
                        if UIApplication.shared.canOpenURL(url) {
                            // 打开URL
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            })
            
        }
        // 页面不随键盘移动
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture { self.wzz_hideKeyboard() }
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .safariView(isPresented: $showLink) {
            SafariView(url: link!)
        }
        .onAppear(){
            self.emailInput = (self.email.count > 0 && self.emailInput.count == 0) ? self.email:""
            self.passwordInput = (self.password.count > 0 && self.passwordInput.count == 0) ? self.password:""

            // 记录登录页面访问
             SharedAnalyticsKit.shared.logScreenView(screenName: "LoginView")

            // 设置 OAuth 回调
            setupOAuthCallbacks()
        }

    }

    // MARK: - 设置 OAuth 回调
    func setupOAuthCallbacks() {
        oauthManager.onSuccess = { [self] authModel in
            DispatchQueue.main.async {
                userManager.auth_data = authModel.auth_data
                userManager.token = authModel.token
                userManager.is_admin = authModel.is_admin

                Task { @MainActor in
                    await finalizeLoginSession(
                        method: "oauth",
                        successMessage: "登录成功",
                        typedEmail: nil
                    )
                }
            }
        }

        oauthManager.onFailure = { error in
            DispatchQueue.main.async {
                SharedAnalyticsKit.shared.logUserLogin(
                    method: "oauth",
                    success: false
                )
                SharedAnalyticsKit.shared.logCustomError(
                    message: "OAuth login failed: \(error)",
                    context: "login"
                )

                failCurrentAction(error)
            }
        }
    }

    // MARK: - Apple 登录处理
    func handleAppleSignIn() {
        guard currentAction == nil else { return }
        wzz_hideKeyboard()
        startAction(.apple, message: "正在使用 Apple 登录…")
        oauthManager.signInWithApple()
    }

    // MARK: - Google 登录处理
    func handleGoogleSignIn() {
        guard currentAction == nil else { return }
        wzz_hideKeyboard()
        startAction(.google, message: "正在使用 Google 登录…")
        oauthManager.signInWithGoogle()
    }

    // MARK: - GitHub 登录处理
    func handleGitHubSignIn() {
        guard currentAction == nil else { return }
        wzz_hideKeyboard()
        startAction(.github, message: "正在使用 GitHub 登录…")
        oauthManager.signInWithGitHub()
    }

    // MARK: - 传统登录处理
    func loginBtnPressed() {
        guard currentAction == nil else { return }
        wzz_hideKeyboard()
        let email = emailInput
        let password = passwordInput
        
        // 输入验证
        guard !email.isEmpty, !password.isEmpty else {
            HUDManager.showFailure("请输入用户名和密码")
            return
        }
        
        startAction(.credentials, message: "正在登录…")
        NetworkService.shared.request(
            AQAPIService.signIn(email: email, password: password),
            decodeTo: AuthModel.self
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let payload):
                    guard let authModel = payload.model, !authModel.auth_data.isEmpty else {
                        failCurrentAction(payload.context.message ?? "登录失败，请检查用户名和密码")
                        SharedAnalyticsKit.shared.logUserLogin(
                            method: "email_password",
                            success: false
                        )
                        SharedAnalyticsKit.shared.logCustomError(
                            message: "Email login failed: \(payload.context.message ?? "unknown")",
                            context: "login"
                        )
                        return
                    }

                    userManager.email = email
                    userManager.password = password
                    userManager.auth_data = authModel.auth_data
                    userManager.token = authModel.token
                    userManager.is_admin = authModel.is_admin

                    Task { @MainActor in
                        await finalizeLoginSession(
                            method: "email_password",
                            successMessage: "登录成功",
                            typedEmail: email
                        )
                    }

                case .failure(let error):
                    failCurrentAction(error.message)

                    SharedAnalyticsKit.shared.logUserLogin(
                        method: "email_password",
                        success: false
                    )
                    SharedAnalyticsKit.shared.logCustomError(
                        message: "Email login failed: \(error.message)",
                        context: "login"
                    )
                }
            }
        }
    }

    @MainActor
    private func finalizeLoginSession(
        method: String,
        successMessage: String,
        typedEmail: String?
    ) async {
        HUDManager.showLoading("正在同步账号数据…")
        do {
            try await userManager.establishSessionAfterLogin()

            SharedAnalyticsKit.shared.logUserLogin(
                method: method,
                success: true,
                userId: userManager.userInfo?.email
            )

            finishCurrentAction(successMessage: successMessage)
            DeviceTokenManager.shared.syncTokenIfAvailable(force: true)
            appStateManager.loginCompleted()
        } catch {
            await handleLoginInitializationFailure(error, method: method, typedEmail: typedEmail)
        }
    }

    @MainActor
    private func handleLoginInitializationFailure(
        _ error: Error,
        method: String,
        typedEmail: String?
    ) async {
        let message: String
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            message = description
        } else {
            let fallback = error.localizedDescription
            message = fallback.isEmpty ? "登录失败，请稍后重试" : fallback
        }

        SharedAnalyticsKit.shared.logUserLogin(
            method: method,
            success: false
        )
        SharedAnalyticsKit.shared.logCustomError(
            message: "Login session init failed: \(message)",
            context: "login"
        )

        userManager.token = ""
        userManager.auth_data = ""
        userManager.is_admin = false

        if let typedEmail {
            userManager.email = typedEmail
        }

        failCurrentAction(message)
    }

    private func startAction(_ action: LoginAction, message: String) {
        currentAction = action
        HUDManager.showLoading(message)
    }

    private func finishCurrentAction(successMessage: String? = nil) {
        let hadAction = currentAction != nil
        currentAction = nil
        if let message = successMessage, !message.isEmpty, hadAction {
            HUDManager.showSuccess(message)
        } else {
            HUDManager.dismiss()
        }
    }

    private func failCurrentAction(_ message: String) {
        currentAction = nil
        HUDManager.showFailure(message.isEmpty ? "操作失败" : message)
    }
}

// 本文件内联一个键盘适配工具，防止目标未编译全局工具时报错
final class LocalKeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    private var willShow: NSObjectProtocol?
    private var willHide: NSObjectProtocol?

    init() {
        willShow = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { note in
            if let rect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = rect.height
            }
        }
        willHide = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }

    deinit {
        if let w = willShow { NotificationCenter.default.removeObserver(w) }
        if let w = willHide { NotificationCenter.default.removeObserver(w) }
    }
}

struct LocalKeyboardAvoiding: ViewModifier {
    @ObservedObject var keyboard: LocalKeyboardObserver
    func body(content: Content) -> some View {
        let kb = keyboard.keyboardHeight
        content
            .padding(.bottom, max(0, kb - 10))
            .offset(y: kb > 0 ? -min(200, kb * 0.6) : 0)
            .animation(.easeOut(duration: 0.25), value: kb)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppStateManager())
            .environmentObject(UserManager())
    }
}

public struct UnderLineTextFieldStyle : TextFieldStyle {
    public func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.callout)
            .padding(.bottom, 10)
            .background(
                UnderLine()
                    .stroke(Color(hexString: "#165DFF"), lineWidth: /*@START_MENU_TOKEN@*/1.0/*@END_MENU_TOKEN@*/)
                    .frame(alignment: .bottom)
            )
    }
}

struct UnderLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

extension View {
    /// 关闭键盘事件
    func wzz_hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
