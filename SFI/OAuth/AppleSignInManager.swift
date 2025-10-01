//
//  AppleSignInManager.swift
//  SFI
//
//  Apple 登录管理器
//  处理 Sign in with Apple 的核心逻辑
//

import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit

/// Apple 登录管理器
class AppleSignInManager: NSObject, ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 登录成功回调
    var onSuccess: ((AppleLoginCredential) -> Void)?

    /// 登录失败回调
    var onFailure: ((String) -> Void)?

    // MARK: - 发起 Apple 登录
    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        // 生成 nonce 用于安全验证
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // MARK: - 生成随机 Nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    // MARK: - SHA256 加密
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {

            // 提取用户信息
            let userIdentifier = appleIDCredential.user  // Apple 提供的唯一用户 ID
            let email = appleIDCredential.email  // 可能为 nil（仅首次登录提供）
            let fullName = appleIDCredential.fullName  // 可能为 nil
            let identityToken = appleIDCredential.identityToken
            let authorizationCode = appleIDCredential.authorizationCode

            // 解析 Identity Token
            guard let identityToken = identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                onFailure?("无法获取 Identity Token")
                return
            }

            // 解析 Authorization Code
            var authCodeString: String?
            if let authorizationCode = authorizationCode {
                authCodeString = String(data: authorizationCode, encoding: .utf8)
            }

            // 构建登录凭证
            let credential = AppleLoginCredential(
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName,
                identityToken: tokenString,
                authorizationCode: authCodeString
            )

            print("🍎 Apple 登录成功")
            print("  - User ID: \(userIdentifier)")
            print("  - Email: \(email ?? "未提供")")
            print("  - Identity Token: \(tokenString.prefix(50))...")

            onSuccess?(credential)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let errorMessage: String

        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "用户取消了登录"
            case .failed:
                errorMessage = "授权失败"
            case .invalidResponse:
                errorMessage = "无效的响应"
            case .notHandled:
                errorMessage = "请求未处理"
            case .unknown:
                errorMessage = "未知错误"
            @unknown default:
                errorMessage = "未知错误"
            }
        } else {
            errorMessage = error.localizedDescription
        }

        print("❌ Apple 登录失败: \(errorMessage)")
        onFailure?(errorMessage)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - Apple 登录凭证
struct AppleLoginCredential {
    let userIdentifier: String  // Apple 提供的唯一用户 ID
    let email: String?  // 邮箱（可能是匿名邮箱）
    let fullName: PersonNameComponents?  // 用户姓名
    let identityToken: String  // JWT Token
    let authorizationCode: String?  // 授权码

    /// 是否是匿名邮箱（Apple 提供的隐藏邮箱）
    var isPrivateEmail: Bool {
        guard let email = email else { return false }
        return email.contains("@privaterelay.appleid.com")
    }

    /// 获取显示名称
    var displayName: String {
        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            return formatter.string(from: fullName)
        }
        return email ?? "Apple 用户"
    }
}
