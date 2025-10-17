//
//  TrialReminderView.swift
//  SharedUserKit
//
//  Created by xiaokang chen on 2024/10/16.
//

import SwiftUI

struct TrialReminderAlert: View {
    @ObservedObject var reminderManager: TrialReminderManager
    @ObservedObject var trialManager: TrialManager
    @EnvironmentObject var userManager: UserManager
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(iconColor)
                
                Text(reminderManager.reminderTitle())
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(reminderMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // 按钮区域
            VStack(spacing: 12) {
                if reminderManager.reminderType == .canTrial {
                    // 可以试用的情况显示"立即试用"按钮
                    Button(action: claimTrial) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("立即试用")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    
                    Button("稍后提醒") {
                        reminderManager.dismissReminder()
                    }
                    .foregroundColor(.secondary)
                } else {
                    // 其他情况显示"查看套餐"和"关闭"按钮
                    Button("查看套餐") {
                        reminderManager.dismissReminder()
                        // TODO: 导航到套餐页面
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("我知道了") {
                        reminderManager.dismissReminder()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(width: 300)
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var iconName: String {
        switch reminderManager.reminderType {
        case .canTrial:
            return "gift.fill"
        case .trialActive:
            return "clock.fill"
        case .trialExpired:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch reminderManager.reminderType {
        case .canTrial:
            return .green
        case .trialActive:
            return .orange
        case .trialExpired:
            return .red
        }
    }
    
    private var reminderMessage: String {
        reminderManager.reminderMessage(trialInfo: trialManager.trialInfo)
    }
    
    private func claimTrial() {
        isLoading = true
        
        Task {
            let result = await trialManager.claimTrial()
            
            isLoading = false
            
            switch result {
            case .success(_):
                // 试用开通成功，刷新用户信息并关闭提醒
                await userManager.reload()
                reminderManager.dismissReminder()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct TrialBannerView: View {
    @ObservedObject var reminderManager: TrialReminderManager
    @ObservedObject var trialManager: TrialManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminderManager.reminderTitle())
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(reminderMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                reminderManager.dismissReminder()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    private var iconName: String {
        switch reminderManager.reminderType {
        case .canTrial:
            return "gift.fill"
        case .trialActive:
            return "clock.fill"
        case .trialExpired:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch reminderManager.reminderType {
        case .canTrial:
            return .green
        case .trialActive:
            return .orange
        case .trialExpired:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch reminderManager.reminderType {
        case .canTrial:
            return Color.green.opacity(0.1)
        case .trialActive:
            return Color.orange.opacity(0.1)
        case .trialExpired:
            return Color.red.opacity(0.1)
        }
    }
    
    private var reminderMessage: String {
        reminderManager.reminderMessage(trialInfo: trialManager.trialInfo)
    }
}

// MARK: - Modifier for easy integration
struct TrialReminderModifier: ViewModifier {
    @StateObject private var trialManager = TrialManager.shared
    @StateObject private var reminderManager = TrialReminderManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // 试用提醒弹窗
            if reminderManager.shouldShowTrialReminder {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        reminderManager.dismissReminder()
                    }
                
                TrialReminderAlert(
                    reminderManager: reminderManager,
                    trialManager: trialManager
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: reminderManager.shouldShowTrialReminder)
            }
        }
        .overlay(alignment: .top) {
            // 试用横幅
            if reminderManager.shouldShowTrialBanner {
                TrialBannerView(
                    reminderManager: reminderManager,
                    trialManager: trialManager
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: reminderManager.shouldShowTrialBanner)
                .padding(.top, 8)
            }
        }
    }
}

extension View {
    func trialReminder() -> some View {
        modifier(TrialReminderModifier())
    }
}

// MARK: - Trial Status Section for UserView
struct TrialStatusSection: View {
    @StateObject private var trialManager = TrialManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var successMessage: String?
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        if let trialInfo = trialManager.trialInfo, trialInfo.trial_enabled {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // 试用配置信息
                    if let config = trialInfo.trial_config {
                        HStack {
                            IVYIcon(systemName: "gift.fill", backgroundColor: .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("试用套餐：\(config.plan_name)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("试用时长：\(config.trial_hours) 小时")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // 用户试用状态
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trialInfo.user_status.message)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let expiredAt = trialInfo.user_status.expired_at {
                                let expireDate = Date(timeIntervalSince1970: expiredAt)
                                Text("到期时间：\(expireDate.date2string())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let remaining = trialInfo.user_status.remaining_hours, remaining > 0 {
                                Text("剩余时间：\(String(format: "%.1f", remaining)) 小时")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    
                    // 操作按钮
                    if trialInfo.can_claim {
                        Button(action: claimTrial) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("立即领取试用")
                                        .fontWeight(.medium)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("试用状态")
            }
            .onAppear {
                if trialManager.shouldRefresh() {
                    Task {
                        await trialManager.fetchTrialInfo()
                    }
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("成功", isPresented: $showingSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(successMessage ?? "")
            }
        } else {
            // 首次加载时显示加载状态
            if trialManager.trialInfo == nil && !trialManager.isLoading {
                Section {
                    EmptyView()
                }
                .onAppear {
                    Task {
                        await trialManager.fetchTrialInfo()
                    }
                }
            }
        }
    }
    
    private var statusIcon: String {
        guard let trialInfo = trialManager.trialInfo else { return "questionmark.circle" }
        
        if trialInfo.can_claim {
            return "gift"
        } else if trialInfo.user_status.is_trial && !trialInfo.user_status.is_expired {
            return "clock"
        } else if trialInfo.user_status.is_expired {
            return "exclamationmark.triangle"
        } else {
            return "checkmark.circle"
        }
    }
    
    private var statusColor: Color {
        guard let trialInfo = trialManager.trialInfo else { return .secondary }
        
        if trialInfo.can_claim {
            return .green
        } else if trialInfo.user_status.is_trial && !trialInfo.user_status.is_expired {
            return .blue
        } else if trialInfo.user_status.is_expired {
            return .red
        } else {
            return .green
        }
    }
    
    private func claimTrial() {
        isLoading = true
        
        Task {
            let result = await trialManager.claimTrial()
            
            isLoading = false
            
            switch result {
            case .success(let data):
                successMessage = "试用开通成功！享受 \(data.remaining_hours) 小时的 \(data.plan_name) 套餐"
                showingSuccess = true
                // 刷新用户信息和试用状态
                await userManager.reload()
                Task {
                    await trialManager.fetchTrialInfo()
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
