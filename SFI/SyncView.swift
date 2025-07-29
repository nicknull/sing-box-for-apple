//
//  SyncView.swift
//  SFI
//
//  Created by xiaokang chen on 2024/3/12.
//

import SwiftUI
import FirebaseRemoteConfig
import Defaults
import Lottie
import NetworkExtension
#if os(iOS)
import SPIndicator
#elseif os(tvOS)
import ExytePopupView
#endif

enum SyncState {
    case initializing    // 初始化中
    case waitingNetwork  // 等待网络连接
    case syncing        // 同步中
    case success        // 同步成功
    case failed         // 同步失败
}

struct SyncView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var monitor = MonitoringNetworkState()
    
    @State private var syncState: SyncState = .initializing
    @State private var errorMessage: String = ""
    @State private var showSkipButton: Bool = false
    
    // 计时器
    @State private var timeoutTimer: Timer?
    @State private var skipButtonTimer: Timer?
    
    var body: some View {
        VStack(spacing: 30) {
            // 动画区域
            LottieView(animation: .named("Sync"))
                .looping()
                .frame(height: 200)
            
            // 状态信息区域
            VStack(spacing: 15) {
                statusTitle
                statusMessage
            }
            
            Spacer()
            
            // 按钮区域
            actionButtons
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .onAppear {
            startSyncProcess()
        }
        .onDisappear {
            cleanupTimers()
        }
        .onChange(of: monitor.isConnected) { isConnected in
            handleNetworkChange(isConnected)
        }
    }
    
    // MARK: - 视图组件
    
    @ViewBuilder
    private var statusTitle: some View {
        switch syncState {
        case .initializing:
            Text("初始化中...")
                .font(.title2)
                .fontWeight(.medium)
        case .waitingNetwork:
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                Text("等待网络连接")
                    .font(.title2)
                    .fontWeight(.medium)
            }
        case .syncing:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("正在更新配置...")
                    .font(.title2)
                    .fontWeight(.medium)
            }
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("更新成功")
                    .font(.title2)
                    .fontWeight(.medium)
            }
        case .failed:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("更新失败")
                    .font(.title2)
                    .fontWeight(.medium)
            }
        }
    }
    
    @ViewBuilder
    private var statusMessage: some View {
        switch syncState {
        case .initializing:
            Text("正在检查网络状态和配置信息...")
                .font(.footnote)
                .foregroundColor(.secondary)
        case .waitingNetwork:
            VStack(spacing: 8) {
                Text("请检查网络连接")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("首次使用可能需要授予网络权限")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .syncing:
            Text("正在从服务器获取最新配置信息...")
                .font(.footnote)
                .foregroundColor(.secondary)
        case .success:
            Text("配置信息已成功更新")
                .font(.footnote)
                .foregroundColor(.green)
        case .failed:
            VStack(spacing: 8) {
                Text("配置更新失败")
                    .font(.footnote)
                    .foregroundColor(.red)
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 15) {
            // 重试按钮
            if syncState == .failed {
                Button(action: retrySync) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // 跳过按钮
            if showSkipButton && syncState != .success {
                Button(action: skipSync) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("跳过此步骤")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 业务逻辑
    
    private func startSyncProcess() {
        syncState = .initializing
        
        // 延迟1秒开始，给网络权限申请一些时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkNetworkAndSync()
        }
        
        // 10秒后显示跳过按钮
        skipButtonTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            DispatchQueue.main.async {
                showSkipButton = true
            }
        }
    }
    
    private func checkNetworkAndSync() {
        if monitor.isConnected {
            startSync()
        } else {
            syncState = .waitingNetwork
        }
    }
    
    private func handleNetworkChange(_ isConnected: Bool) {
        if isConnected && (syncState == .waitingNetwork || syncState == .initializing) {
            // 网络连接恢复，延迟一点再开始同步
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.syncState == .waitingNetwork || self.syncState == .initializing {
                    startSync()
                }
            }
        } else if !isConnected && syncState == .syncing {
            // 同步过程中网络断开
            syncState = .waitingNetwork
            cleanupTimers()
        }
    }
    
    private func startSync() {
        guard monitor.isConnected else {
            syncState = .waitingNetwork
            return
        }
        
        syncState = .syncing
        errorMessage = ""
        
        // 设置30秒超时
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if syncState == .syncing {
                    syncFailed(with: "请求超时，请检查网络连接")
                }
            }
        }
        
        performSync()
    }
    
    private func performSync() {
        NewNetWorkRequest(AQAPIService.getService, 
            successCallback: { responseModel in
                DispatchQueue.main.async {
                    handleSyncSuccess(responseModel)
                }
            },
            failureCallback: { responseModel in
                DispatchQueue.main.async {
                    let message = responseModel.messageStr ?? "网络请求失败"
                    syncFailed(with: message)
                }
            }
        )
    }
    
    private func handleSyncSuccess(_ responseModel: NewResponseModel) {
        cleanupTimers()
        
        guard let data = Data(base64Encoded: responseModel.dataString ?? ""),
              let decodedString = String(data: data, encoding: .utf8)?.removingPercentEncoding else {
            syncFailed(with: "服务器返回数据格式错误")
            return
        }
        
        let components = decodedString.components(separatedBy: "|")
        for (index, element) in components.enumerated() {
            guard let urlStr = element.removingPercentEncoding,
                  let url = URL(string: urlStr),
                  url.scheme != nil else { continue }
            
            if index == 0 {
                // 更新主服务地址
                Defaults[.host] = urlStr
                Defaults[.getServiceTime] = Date().timeIntervalSince1970
                
                syncState = .success
                
                // 2秒后自动进入下一步
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    proceedToNextStep()
                }
                return
            }
        }
        
        syncFailed(with: "服务器返回的数据中没有找到有效的服务地址")
    }
    
    private func syncFailed(with message: String) {
        cleanupTimers()
        syncState = .failed
        errorMessage = message
    }
    
    private func retrySync() {
        startSync()
    }
    
    private func skipSync() {
        cleanupTimers()
        proceedToNextStep()
    }
    
    private func proceedToNextStep() {
        appStateManager.syncCompleted(userManager: userManager)
    }
    
    private func cleanupTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        skipButtonTimer?.invalidate()
        skipButtonTimer = nil
    }
}

#Preview {
    SyncView()
        .environmentObject(AppStateManager())
        .environmentObject(UserManager())
}
