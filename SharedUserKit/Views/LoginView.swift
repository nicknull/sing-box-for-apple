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
import LoadingButton
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

    @State var errorStr: String = ""
    @State var showingPopup: Bool = false

    @State var emailInput: String = ""
    @State var passwordInput: String = ""
    @State var isLoading: Bool = false
    @State var popUp: Bool = false
    @StateObject private var oauthManager = OAuthManager(
        googleClientID: "YOUR_GOOGLE_CLIENT_ID",
        githubClientID: "YOUR_GITHUB_CLIENT_ID"
    )
    var style = LoadingButtonStyle(width: 312,
                                   height: 40,
                                   cornerRadius: 27,
                                   backgroundColor:Color("blueblue"),
                                   loadingColor: Color("blueblue"),
                                   strokeWidth: 5,
                                   strokeColor: .gray)
    
    @AppStorage(ConstantKey.auth_data, store: .standard) private var auth_data  = ""
    @AppStorage(ConstantKey.email, store: .standard) private var email  = ""
    @AppStorage(ConstantKey.password, store: .standard) private var password  = ""
    @State var showLink:Bool = false
    @State var link:URL?
    @AppStorage(ConstantKey.consentAgreed) private var agreed: Bool = true
    
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
                                .disabled(isLoading)
                            TextField("请输入用户名", text: $emailInput)
                                .padding(.leading,10)
                                .frame(height: 40)
                                .textFieldStyle(UnderLineTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .disabled(isLoading)
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
                            .disabled(isLoading)
                        }.padding(.horizontal,20)
                        LoadingButton(action: {
                            if !agreed {
                                errorStr = "请先勾选同意《用户协议》和《隐私政策》"
                                showingPopup = true
                                return
                            }
                            loginBtnPressed()
                            // Your Action here
                        }, isLoading: $isLoading, style: style) {
                            Text("马上登录").foregroundColor(Color.white)
                        }
                        .disabled(!agreed || isLoading)
                        .opacity((!agreed || isLoading) ? 0.5 : 1.0)

                        .padding(40)

                        // 三方登录分隔线
                        HStack(alignment: .center, spacing: 8) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                            Text("或使用以下方式登录")
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

                        // 三方登录按钮（紧凑图标风格，固定宽度，不再拉伸）
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
                                .disabled(isLoading || oauthManager.isLoading || !agreed)
                                .opacity(agreed ? 1.0 : 0.5)
                                Text("Apple").font(.caption2).foregroundColor(.secondary)
                            }

                            VStack(spacing: 6) {
                                Button(action: { handleGoogleSignIn() }) {
                                    Group {
                                        if let img = UIImage(named: "icon_google") {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                        } else {
                                            Image(systemName: "globe")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .background(Color(red: 0.26, green: 0.52, blue: 0.96).opacity(0.15))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color(red: 0.26, green: 0.52, blue: 0.96).opacity(0.25), lineWidth: 1))
                                }
                                .disabled(isLoading || oauthManager.isLoading || !agreed)
                                .opacity(agreed ? 1.0 : 0.5)
                                Text("Google").font(.caption2).foregroundColor(.secondary)
                            }

                            VStack(spacing: 6) {
                                Button(action: { handleGitHubSignIn() }) {
                                    Group {
                                        if let img = UIImage(named: "icon_github") {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                        } else {
                                            Image(systemName: "terminal")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.12))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                                }
                                .disabled(isLoading || oauthManager.isLoading || !agreed)
                                .opacity(agreed ? 1.0 : 0.5)
                                Text("GitHub").font(.caption2).foregroundColor(.secondary)
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
                            .disabled(!agreed)
                            .opacity(agreed ? 1.0 : 0.5)
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
            .toast(isPresenting: $showingPopup){
                ToastNotification(type: .error(.green), title:errorStr)
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

            // 设置 OAuth 回调
            setupOAuthCallbacks()
        }

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

                    DispatchQueue.main.async {
                        // 登录成功后通知 AppStateManager 进入主界面
                        appStateManager.loginCompleted()
                    }
                }
            }
        }

        oauthManager.onFailure = { error in
            DispatchQueue.main.async {
                errorStr = error
                showingPopup = true
            }
        }
    }

    // MARK: - Apple 登录处理
    func handleAppleSignIn() {
        wzz_hideKeyboard()
        oauthManager.signInWithApple()
    }

    // MARK: - Google 登录处理
    func handleGoogleSignIn() {
        wzz_hideKeyboard()
        oauthManager.signInWithGoogle()
    }

    // MARK: - GitHub 登录处理
    func handleGitHubSignIn() {
        wzz_hideKeyboard()
        oauthManager.signInWithGitHub()
    }

    // MARK: - 传统登录处理
    func loginBtnPressed() {
        wzz_hideKeyboard()
        let email = emailInput
        let password = passwordInput
        
        // 输入验证
        guard !email.isEmpty, !password.isEmpty else {
            errorStr = "请输入用户名和密码"
            showingPopup = true
            return
        }
        
        isLoading = true
        
        NewNetWorkRequest(AQAPIService.signIn(email: email, password: password), modelType: AuthModel.self) { authModel, responseModel in
            DispatchQueue.main.async {
                guard let authModel = authModel, !authModel.auth_data.isEmpty else {
                    isLoading = false
                    errorStr = responseModel.messageStr ?? "登录失败，请检查用户名和密码"
                    showingPopup = true
                    return
                }
                
                // 保存用户信息
                userManager.email = email
                userManager.password = password
                userManager.auth_data = authModel.auth_data
                userManager.token = authModel.token
                userManager.is_admin = authModel.is_admin

                Task {
                    userManager.reload()
                    
                    DispatchQueue.main.async {
                        isLoading = false
                        // 登录成功后通知 AppStateManager 进入主界面
                        appStateManager.loginCompleted()
                    }
                }
            }
        } failureCallback: { responseModel in
            DispatchQueue.main.async {
                isLoading = false
                errorStr = responseModel.messageStr ?? "网络请求失败，请检查网络连接"
                showingPopup = true
            }
        }
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
