//
//  OAuthBindingManager.swift
//  SFI
//
//  OAuth 账号绑定管理器
//  用于绑定和解绑三方登录账号
//

import Foundation
import SwiftUI


/// OAuth 账号绑定管理器
class OAuthBindingManager: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let appleSignInManager = AppleSignInManager()
    private var googleSignInManager: GoogleSignInManager?
    private var githubSignInManager: GitHubSignInManager?

    /// 绑定成功回调
    var onBindSuccess: ((String) -> Void)?  // 参数为 provider 类型

    /// 绑定失败回调
    var onBindFailure: ((String) -> Void)?

    /// 解绑成功回调
    var onUnbindSuccess: ((String) -> Void)?

    /// 解绑失败回调
    var onUnbindFailure: ((String) -> Void)?

    init(googleClientID: String = "", githubClientID: String = "") {
        if !googleClientID.isEmpty {
            googleSignInManager = GoogleSignInManager(clientID: googleClientID)
        }
        if !githubClientID.isEmpty {
            githubSignInManager = GitHubSignInManager(clientID: githubClientID)
        }
    }

    // MARK: - 绑定 Apple 账号
    func bindAppleAccount() {
        isLoading = true

        appleSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🍎 开始绑定 Apple 账号...")

            // 调用后端 API 绑定账号
            NetworkService.shared.request(
                AQAPIService.bindAppleAccount(
                    identityToken: credential.identityToken,
                    userIdentifier: credential.userIdentifier
                ),
                decodeTo: BindResponse.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if payload.context.httpStatusCode == 200 {
                            print("✅ Apple 账号绑定成功")
                            self.onBindSuccess?("apple")
                        } else {
                            let error = payload.model?.message ?? payload.context.message ?? "绑定失败"
                            print("❌ Apple 账号绑定失败: \(error)")
                            self.errorMessage = error
                            self.onBindFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        self.errorMessage = message
                        self.onBindFailure?(message)
                    }
                }
            }
        }

        appleSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onBindFailure?(error)
            }
        }

        appleSignInManager.signIn()
    }

    // MARK: - 绑定 Google 账号
    func bindGoogleAccount() {
        guard let googleSignInManager = googleSignInManager else {
            onBindFailure?("Google 登录未配置")
            return
        }

        isLoading = true

        googleSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🔍 开始绑定 Google 账号...")

            NetworkService.shared.request(
                AQAPIService.bindGoogleAccount(authorizationCode: credential.authorizationCode),
                decodeTo: BindResponse.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if payload.context.httpStatusCode == 200 {
                            print("✅ Google 账号绑定成功")
                            self.onBindSuccess?("google")
                        } else {
                            let error = payload.model?.message ?? payload.context.message ?? "绑定失败"
                            print("❌ Google 账号绑定失败: \(error)")
                            self.errorMessage = error
                            self.onBindFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        self.errorMessage = message
                        self.onBindFailure?(message)
                    }
                }
            }
        }

        googleSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onBindFailure?(error)
            }
        }

        googleSignInManager.signIn()
    }

    // MARK: - 绑定 GitHub 账号
    func bindGitHubAccount() {
        guard let githubSignInManager = githubSignInManager else {
            onBindFailure?("GitHub 登录未配置")
            return
        }

        isLoading = true

        githubSignInManager.onSuccess = { [weak self] credential in
            guard let self = self else { return }

            print("🐙 开始绑定 GitHub 账号...")

            NetworkService.shared.request(
                AQAPIService.bindGitHubAccount(authorizationCode: credential.authorizationCode),
                decodeTo: BindResponse.self
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false

                    switch result {
                    case .success(let payload):
                        if payload.context.httpStatusCode == 200 {
                            print("✅ GitHub 账号绑定成功")
                            self.onBindSuccess?("github")
                        } else {
                            let error = payload.model?.message ?? payload.context.message ?? "绑定失败"
                            print("❌ GitHub 账号绑定失败: \(error)")
                            self.errorMessage = error
                            self.onBindFailure?(error)
                        }

                    case .failure(let error):
                        let message = error.message
                        self.errorMessage = message
                        self.onBindFailure?(message)
                    }
                }
            }
        }

        githubSignInManager.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error
                self?.onBindFailure?(error)
            }
        }

        githubSignInManager.signIn()
    }

    // MARK: - 解绑 OAuth 账号
    func unbindOAuthAccount(provider: String) {
        isLoading = true

        print("🔓 开始解绑 \(provider) 账号...")

        NetworkService.shared.request(
            AQAPIService.unbindOAuthAccount(provider: provider),
            decodeTo: BindResponse.self
        ) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let payload):
                    if payload.context.httpStatusCode == 200 {
                        print("✅ \(provider) 账号解绑成功")
                        self.onUnbindSuccess?(provider)
                    } else {
                        let error = payload.model?.message ?? payload.context.message ?? "解绑失败"
                        print("❌ \(provider) 账号解绑失败: \(error)")
                        self.errorMessage = error
                        self.onUnbindFailure?(error)
                    }

                case .failure(let error):
                    let message = error.message
                    self.errorMessage = message
                    self.onUnbindFailure?(message)
                }
            }
        }
    }
}

// MARK: - 绑定响应模型
struct BindResponse: Codable {
    let success: Bool?
    let message: String?
}
