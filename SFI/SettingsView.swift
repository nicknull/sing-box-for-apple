//
//  ClashView.swift
//  Clash
//
//  Created by xiaokang chen on 2023/2/15.
//

import SwiftUI
import NetworkExtension
import Libbox
import Library
import ApplicationLibrary

struct SettingsView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @StateObject private var commandClient = CommandClient(.status)
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var alert: Alert?
    @State private var profile:Profile?

    var body: some View {
        Form {
            
            if let extensionProfile = environments.extensionProfile,
               extensionProfile.status.isConnected {
                
                if let message = commandClient.status {
                    if message.trafficAvailable {
                        Section{
                            
                            LabeledContent {
                                Text("\(LibboxFormatBytes(message.uplinkTotal))")
                            } label: {
                                Text("Uplink")
                            }
                            LabeledContent {
                                Text("\(LibboxFormatBytes(message.downlinkTotal))")
                            } label: {
                                Text("Downlink")
                            }
                        }header: {
                            Text("Traffic Total")
                        }
                    }
                }
                
                
                Section{
                    NavigationLink {
                        GroupListView()
                    } label: {
                        Text("线路")
                    }
                }
            header: {
                Text("线路")
            }
                Section{
                    ModeView()                    
                }header: {
                    Text("代理模式")
                }
                
            }else{
                Text("连接后查看")
            }
            if  (environments.extensionProfile != nil) && profile != nil{
                Button {
                    isLoading = true
                    Task {
                        await updateProfile()
                    }
                } label: {
                    HStack{
                        Label("更新线路", systemImage: "arrow.clockwise")
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text(formattedUpdateTime(profile?.lastUpdated))
                                .font(.footnote)
                        }

                    }
                }
                .disabled(isLoading)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 记录设置页面访问
             SharedAnalyticsKit.shared.logScreenView(screenName: "SettingsView")

            commandClient.connect()
            Task{

                guard let profileTemp = try await ProfileManager.get(by: "iFlash")else{
                    return
                }
                profile = profileTemp
            }
        }
        .onDisappear {
            commandClient.disconnect()
        }
        .alertBinding($alert)
        .onReceive(environments.selectedProfileUpdate) { _ in
            Task {
                guard let profileTemp = try await ProfileManager.get(by: "iFlash")else{
                    return
                }
                profile = profileTemp
            }
        }


    }
    private func updateProfile() async {
        if profile == nil {
            return
        }
        defer {
            isLoading = false
        }
        do {
//
            try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))
            try await profile!.updateRemoteProfile()
            environments.profileUpdate.send()
        } catch {
            alert = Alert(error)
        }
    }

    private func formattedUpdateTime(_ date: Date?) -> String {
        guard let date else { return "未知" }
        let now = Date()
        let interval = abs(now.timeIntervalSince(date))

        if interval < 24 * 60 * 60 {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.locale = .autoupdatingCurrent
            relativeFormatter.unitsStyle = .full
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        }

        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        if formatter.locale.identifier.hasPrefix("zh") {
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        }
        return formatter.string(from: date)
    }

}
