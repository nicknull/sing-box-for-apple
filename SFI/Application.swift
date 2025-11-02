import Foundation
import Library
import SwiftUI
import Defaults
import SPIndicator
import Combine

enum AppState {
    case sync      // 需要显示同步界面
    case login     // 需要登录
    case main      // 主界面
}

@MainActor
class AppStateManager: ObservableObject {
    @Published var currentState: AppState = .main
    private let serviceInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days
    
    func checkInitialState(userManager: UserManager) {
        // 首先检查是否需要同步
        // 考虑到首次打开时可能还在申请网络权限，我们需要更谨慎地判断
        let getService = Defaults[.getServiceTime]
        let timeInterval = Date().timeIntervalSince1970
        
        // 如果从未获取过服务配置（getService为0），或者超过了服务间隔时间
        let needSync = (getService == 0) || (timeInterval - getService > serviceInterval)
        
        if needSync {
            currentState = .sync
        } else if !userManager.isLoggedIn {
            currentState = .login
        } else {
            currentState = .main
        }
    }
    
    func syncCompleted(userManager: UserManager) {
        if !userManager.isLoggedIn {
            currentState = .login
        } else {
            currentState = .main
        }
    }
    
    func syncFailed() {
        // 同步失败时，可以选择跳过同步继续到下一步
        // 这里我们保持在sync状态，让用户可以重试
        // 或者可以添加一个"跳过"选项
    }
    
    func loginCompleted() {
        currentState = .main
    }
    
    func userLoggedOut() {
        // 用户登出后，重新检查初始状态
        // 但通常情况下应该直接跳转到登录页面
        currentState = .login
    }
}

@main
struct Application: App {

    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
    @StateObject private var environments = ExtensionEnvironments()
    @StateObject private var userManager = UserManager()
    @StateObject private var appStateManager = AppStateManager()
    @State var syncingConfig: Bool = false
    @State var synced: Bool = false
    let notificationCenter = UNUserNotificationCenter.current()

    var body: some Scene {
        WindowGroup {
            HUDContainer {
                switch appStateManager.currentState {
                case .sync:
                    SyncView()
                        .environmentObject(appStateManager)
                        .environmentObject(userManager)
                case .login:
                    LoginView()
                        .environmentObject(appStateManager)
                        .environmentObject(userManager)
                case .main:
                    NavigationStack {
                        DashBoardView()
                            .tag(0)
                            .environment(\.trafficFormatter, ClashTrafficFormatterKey.defaultValue)
                            .environmentObject(environments)
                            .environmentObject(userManager)
                            .environmentObject(appStateManager)
                            .navigationTitle("闪电加速器")
                            .trialReminder()
                    }
                }
            }
            .onAppear {
                appStateManager.checkInitialState(userManager: userManager)
            }
            .onOpenURL { url in
#if os(iOS)
                guard let base64EncodedString =  url.queryItems()["repair"] else{
                    SPIndicator.present(title: "修复失败", message: "请重新获取修复邮件，当前无法修复", preset: .done)
                    return ;
                }
                guard let decodedData = Data(base64Encoded: base64EncodedString) else{
                    SPIndicator.present(title: "修复失败", message: "请重新获取修复邮件", preset: .done)

                    return ;
                }
                guard let decodedString = String(data: decodedData, encoding: .utf8)  else{
                    SPIndicator.present(title: "修复失败", message: "请重新联系我们", preset: .done)
                    return ;
                }
                guard URL(string: decodedString) != nil else{
                    SPIndicator.present(title: "修复失败", message: "您的修复地址有误", preset: .done)
                    return ;
                }
                Defaults[.host] = decodedString
                SPIndicator.present(title: "修复成功", message: "请重启后再试", preset: .done)
                Task { await userManager.reload() }
#endif

            }
            .onReceive(NotificationCenter.default.publisher(for: .authExpired)) { _ in
                Task { @MainActor in
                    await userManager.logout()
                    appStateManager.userLoggedOut()
                }
            }

        }
    }
    
}
