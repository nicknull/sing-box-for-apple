//
//  AccountBindingView.swift
//  SFI
//
//  账号绑定管理界面
//  用户可以查看和管理已绑定的登录方式
//

import SwiftUI

struct AccountBindingView: View {

    @EnvironmentObject var userManager: UserManager
    @StateObject private var bindingManager = OAuthBindingManager(
        googleClientID: "YOUR_GOOGLE_CLIENT_ID",
        githubClientID: "YOUR_GITHUB_CLIENT_ID"
    )

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertType: ToastNotification.AlertType = .complete(.green)
    @State private var showingUnbindConfirm = false
    @State private var unbindProvider = ""

    // 登录方式列表（从 userInfo 获取）
    private var loginMethods: [String] {
        userManager.userInfo?.login_methods ?? []
    }

    // 是否有密码
    private var hasPassword: Bool {
        userManager.userInfo?.has_password ?? !userManager.password.isEmpty
    }

    var body: some View {
        List {
            Section(header: Text("传统登录方式")) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("邮箱/用户名登录")
                    Spacer()
                    if hasPassword {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已设置")
                            .foregroundColor(.gray)
                    } else {
                        Text("未设置")
                            .foregroundColor(.gray)
                    }
                }
            }

            Section(header: Text("第三方登录绑定")) {
                // Apple 登录
                OAuthBindingRow(
                    icon: "applelogo",
                    iconColor: .black,
                    title: "Apple 账号",
                    isBound: loginMethods.contains("apple"),
                    onBind: {
                        bindingManager.bindAppleAccount()
                    },
                    onUnbind: {
                        showUnbindConfirm(provider: "apple", name: "Apple")
                    }
                )

                // Google 登录
                OAuthBindingRow(
                    icon: "globe",
                    iconColor: Color(red: 0.26, green: 0.52, blue: 0.96),
                    title: "Google 账号",
                    isBound: loginMethods.contains("google"),
                    onBind: {
                        bindingManager.bindGoogleAccount()
                    },
                    onUnbind: {
                        showUnbindConfirm(provider: "google", name: "Google")
                    }
                )

                // GitHub 登录
                OAuthBindingRow(
                    icon: "terminal",
                    iconColor: Color(red: 0.13, green: 0.13, blue: 0.13),
                    title: "GitHub 账号",
                    isBound: loginMethods.contains("github"),
                    onBind: {
                        bindingManager.bindGitHubAccount()
                    },
                    onUnbind: {
                        showUnbindConfirm(provider: "github", name: "GitHub")
                    }
                )
            }

            Section(footer: Text("绑定第三方账号后，您可以使用这些方式快速登录。建议至少保留一种登录方式。")) {
                EmptyView()
            }
        }
        .navigationTitle("登录方式管理")
        .navigationBarTitleDisplayMode(.inline)
        .toast(isPresenting: $showingAlert) {
            ToastNotification(type: alertType, title: alertMessage)
        }
        .alert(isPresented: $showingUnbindConfirm) {
            Alert(
                title: Text("确认解绑"),
                message: Text("确定要解绑 \(unbindProvider) 账号吗？"),
                primaryButton: .destructive(Text("解绑")) {
                    performUnbind()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .onAppear {
            setupBindingCallbacks()
        }
    }

    // MARK: - 设置绑定回调
    private func setupBindingCallbacks() {
        bindingManager.onBindSuccess = { provider in
            alertType = .complete(.green)
            alertMessage = "绑定成功"
            showingAlert = true

            // 刷新用户信息
            Task { await userManager.reload() }
        }

        bindingManager.onBindFailure = { error in
            alertType = .error(.red)
            alertMessage = error
            showingAlert = true
        }

        bindingManager.onUnbindSuccess = { provider in
            alertType = .complete(.green)
            alertMessage = "解绑成功"
            showingAlert = true

            // 刷新用户信息
            Task { await userManager.reload() }
        }

        bindingManager.onUnbindFailure = { error in
            alertType = .error(.red)
            alertMessage = error
            showingAlert = true
        }
    }

    // MARK: - 显示解绑确认对话框
    private func showUnbindConfirm(provider: String, name: String) {
        // 检查是否至少保留一种登录方式
        let boundMethodsCount = loginMethods.count + (hasPassword ? 1 : 0)
        if boundMethodsCount <= 1 {
            alertType = .error(.red)
            alertMessage = "至少需要保留一种登录方式"
            showingAlert = true
            return
        }

        unbindProvider = name
        showingUnbindConfirm = true
    }

    // MARK: - 执行解绑
    private func performUnbind() {
        let provider = unbindProvider.lowercased()
        bindingManager.unbindOAuthAccount(provider: provider)
    }
}

// MARK: - OAuth 绑定行组件
struct OAuthBindingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isBound: Bool
    let onBind: () -> Void
    let onUnbind: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 30)

            Text(title)

            Spacer()

            if isBound {
                Button(action: onUnbind) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已绑定")
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Button(action: onBind) {
                    Text("绑定")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AccountBindingView()
            .environmentObject(UserManager())
    }
}
