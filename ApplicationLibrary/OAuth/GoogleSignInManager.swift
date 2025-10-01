//
//  GoogleSignInManager.swift
//  SFI
//
//  Google 登录管理器
//

import Foundation
import SwiftUI
import AuthenticationServices

/// Google 登录管理器
class GoogleSignInManager: NSObject, ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 登录成功回调
    var onSuccess: ((GoogleLoginCredential) -> Void)?

    /// 登录失败回调
    var onFailure: ((String) -> Void)?

    // Google OAuth 配置
    private let clientID: String
    private let redirectURI = "com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect"

    init(clientID: String) {
        self.clientID = clientID
        super.init()
    }

    // MARK: - 发起 Google 登录
    func signIn() {
        // 构建 Google OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "email profile"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let url = components.url else {
            onFailure?("无法构建 Google OAuth URL")
            return
        }

        // 使用 ASWebAuthenticationSession 进行登录
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.googleusercontent.apps") { [weak self] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    self.onFailure?("用户取消了登录")
                } else {
                    self.onFailure?(error.localizedDescription)
                }
                return
            }

            guard let callbackURL = callbackURL else {
                self.onFailure?("未获取到回调 URL")
                return
            }

            // 解析授权码
            self.handleCallback(url: callbackURL)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - 处理回调
    private func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            onFailure?("无法解析授权码")
            return
        }

        print("🔑 Google 授权码: \(code)")

        // 将授权码发送给后端，由后端换取 Access Token 和用户信息
        let credential = GoogleLoginCredential(authorizationCode: code)
        onSuccess?(credential)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension GoogleSignInManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - Google 登录凭证
struct GoogleLoginCredential {
    let authorizationCode: String  // 授权码，需要发送给后端换取 token
}
