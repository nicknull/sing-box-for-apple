//
//  OAuthManager.swift
//  SFI
//
//  统一的 OAuth 登录管理器
//

import Foundation
import SwiftUI


/// OAuth 登录管理器
class OAuthManager: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let appleSignInManager = AppleSignInManager()
    private var googleSignInManager: GoogleSignInManager?
    private var githubSignInManager: GitHubSignInManager?

    /// 登录成功回调
    var onSuccess: ((AuthModel) -> Void)?

    /// 登录失败回调
    var onFailure: ((String) -> Void)?

    init(googleClientID: String = "", githubClientID: String = "") {
        if !googleClientID.isEmpty {
            googleSignInManager = GoogleSignInManager(clientID: googleClientID)
        }
        if !githubClientID.isEmpty {
            githubSignInManager = GitHubSignInManager(clientID: githubClientID)
        }
    }

    // MARK: - Apple 登录
    func signInWithApple() {
        isLoading = true

        appleSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🍎 开始处理 Apple 登录...")

            // 调用后端 API
            let fullName = credential.displayName
            NetworkService.shared.request(
                AQAPIService.oauthAppleLogin(
                    identityToken: credential.identityToken,
                    userIdentifier: credential.userIdentifier,
                    email: credential.email,
                    fullName: fullName
                ),
                decodeTo: AuthModel.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if let authModel = payload.model, !authModel.auth_data.isEmpty {
                            print("✅ Apple 登录成功")
                            self.onSuccess?(authModel)
                        } else {
                            let error = payload.context.message ?? "Apple 登录失败"
                            print("❌ Apple 登录失败: \(error)")
                            self.errorMessage = error
                            self.onFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        print("❌ Apple 登录失败: \(message)")
                        self.errorMessage = message
                        self.onFailure?(message)
                    }
                }
            }
        }

        appleSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onFailure?(error)
            }
        }

        appleSignInManager.signIn()
    }

    // MARK: - Google 登录
    func signInWithGoogle() {
        guard let googleSignInManager = googleSignInManager else {
            onFailure?("Google 登录未配置")
            return
        }

        isLoading = true

        googleSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🔍 开始处理 Google 登录...")

            // 调用后端 API
            NetworkService.shared.request(
                AQAPIService.oauthGoogleLogin(authorizationCode: credential.authorizationCode),
                decodeTo: AuthModel.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if let authModel = payload.model, !authModel.auth_data.isEmpty {
                            print("✅ Google 登录成功")
                            self.onSuccess?(authModel)
                        } else {
                            let error = payload.context.message ?? "Google 登录失败"
                            print("❌ Google 登录失败: \(error)")
                            self.errorMessage = error
                            self.onFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        print("❌ Google 登录失败: \(message)")
                        self.errorMessage = message
                        self.onFailure?(message)
                    }
                }
            }
        }

        googleSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onFailure?(error)
            }
        }

        googleSignInManager.signIn()
    }

    // MARK: - GitHub 登录
    func signInWithGitHub() {
        guard let githubSignInManager = githubSignInManager else {
            onFailure?("GitHub 登录未配置")
            return
        }

        isLoading = true

        githubSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🐙 开始处理 GitHub 登录...")

            // 调用后端 API
            NetworkService.shared.request(
                AQAPIService.oauthGitHubLogin(authorizationCode: credential.authorizationCode),
                decodeTo: AuthModel.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if let authModel = payload.model, !authModel.auth_data.isEmpty {
                            print("✅ GitHub 登录成功")
                            self.onSuccess?(authModel)
                        } else {
                            let error = payload.context.message ?? "GitHub 登录失败"
                            print("❌ GitHub 登录失败: \(error)")
                            self.errorMessage = error
                            self.onFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        print("❌ GitHub 登录失败: \(message)")
                        self.errorMessage = message
                        self.onFailure?(message)
                    }
                }
            }
        }

        githubSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onFailure?(error)
            }
        }

        githubSignInManager.signIn()
    }
}
