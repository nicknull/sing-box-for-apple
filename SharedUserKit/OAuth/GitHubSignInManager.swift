//
//  GitHubSignInManager.swift
//  SFI
//
//  GitHub 登录管理器
//

import Foundation
import SwiftUI
import AuthenticationServices

/// GitHub 登录管理器
class GitHubSignInManager: NSObject, ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 登录成功回调
    var onSuccess: ((GitHubLoginCredential) -> Void)?

    /// 登录失败回调
    var onFailure: ((String) -> Void)?

    // GitHub OAuth 配置
    private let clientID: String
    private let redirectURI = "your-app-scheme://oauth/callback"

    init(clientID: String) {
        self.clientID = clientID
        super.init()
    }

    // MARK: - 发起 GitHub 登录
    func signIn() {
        // 构建 GitHub OAuth URL
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "user:email"),
            URLQueryItem(name: "state", value: generateState())
        ]

        guard let url = components.url else {
            onFailure?("无法构建 GitHub OAuth URL")
            return
        }

        // 使用 ASWebAuthenticationSession 进行登录
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "your-app-scheme") { [weak self] callbackURL, error in
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

        print("🔑 GitHub 授权码: \(code)")

        // 将授权码发送给后端，由后端换取 Access Token 和用户信息
        let credential = GitHubLoginCredential(authorizationCode: code)
        onSuccess?(credential)
    }

    // MARK: - 生成 State
    private func generateState() -> String {
        return UUID().uuidString
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension GitHubSignInManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - GitHub 登录凭证
struct GitHubLoginCredential {
    let authorizationCode: String  // 授权码，需要发送给后端换取 token
}
