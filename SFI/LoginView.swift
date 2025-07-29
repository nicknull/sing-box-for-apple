//
//  LoginView.swift
//  Pomelo
//
//  Created by xiaokang chen on 2023/3/22.
//

import SwiftUI
import Combine

import AuthenticationServices
import AlertToast
import LoadingButton
//import MarkdownUI
import NetworkExtension
import DynamicColor
import ApplicationLibrary
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
                
                
                //登录方式
                VStack() {
                    
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
                            loginBtnPressed()
                            // Your Action here
                        }, isLoading: $isLoading, style: style) {
                            Text("马上登录").foregroundColor(Color.white)
                        }
                        
                        .padding(40)
                        
                        HStack{
                            Spacer()
                            
                            ButtonWithSafari(stringURL: "\(Defaults[.host])/#/register") {
                                Text("注册账号")
                                    .tracking(3.0)
                                    .fontWeight(.medium)
                            }
//                            Rectangle()
//                                .fill(Color.blue)
//                                .opacity(0.6)
//                                .frame(width: 2,height: 12)
//                                .padding(.horizontal,5)
//                            
//                            Button {
//                                popUp.toggle()
//                            } label: {
//                                Text("无法注册")
//                                    .tracking(3.0)
//                                    .fontWeight(.medium)
//                            }
//                            
//                            Rectangle()
//                                .fill(Color.blue)
//                                .opacity(0.6)
//                                .frame(width: 2,height: 12)
//                                .padding(.horizontal,5)
//                            
//                            Button {
//                                popUp.toggle()
//                            } label: {
//                                Text("无法登录")
//                                    .tracking(3.0)
//                                    .fontWeight(.medium)
//                            }
//                            
                            Spacer()
                        }
                        Spacer()
                        
                    }
                }
                Spacer()
                
                
                HStack{
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
            .toast(isPresenting: $showingPopup){
                AlertToast(type: .error(.green), title:errorStr)
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
        
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .safariView(isPresented: $showLink) {
            SafariView(url: link!)
        }
        .onAppear(){
            self.emailInput = (self.email.count > 0 && self.emailInput.count == 0) ? self.email:""
            self.passwordInput = (self.password.count > 0 && self.passwordInput.count == 0) ? self.password:""
        }
        
    }
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


