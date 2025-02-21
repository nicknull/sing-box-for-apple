//
//  ProfileListView.swift
//  SFI
//
//  Created by xiaokang chen on 2023/12/10.
//

import SwiftUI
import Libbox
import Library

struct ProfileListView: View {
    @State private var profileList: [ProfilePreview]
    @EnvironmentObject private var environments: ExtensionEnvironments
    
    @State private var selectedProfileID: Int64
    @State private var reasserting = false
    @State private var alert: Alert?
    
    private var selectedProfileIDLocal: Binding<Int64> {
        $selectedProfileID.withSetter { newValue in
            reasserting = true
            Task { [self] in
                await switchProfile(newValue)
            }
        }
    }
    
    var body: some View {
        Form{
            Section("Profile") {
                Picker(selection: selectedProfileIDLocal) {
                    ForEach(profileList, id: \.id) { profile in
                        Text(profile.name).tag(profile.id)
//                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
//                                Button {
//                                    print("edit")
//                                } label: {
//                                    Text("更新")
//                                }
//                                .tint(.orange)
//                            }
                        
                    }
                } label: {}
                    .pickerStyle(.inline)
            }
        }
        .onAppear(){
            Task{
                do {
                    profileList = try await ProfileManager.list().map { ProfilePreview($0) }
                    if profileList.isEmpty {
                        return
                    }
                    selectedProfileID = await SharedPreferences.selectedProfileID.get()
                    if profileList.filter({ profile in
                        profile.id == selectedProfileID
                    })
                        .isEmpty {
                        selectedProfileID = profileList[0].id
                        await SharedPreferences.selectedProfileID.set(selectedProfileID)
                    }
                } catch {
                    alert = Alert(error)
                }
            }
            
            
        }
    }
    private func switchProfile(_ newProfileID: Int64) async {
        await SharedPreferences.selectedProfileID.set(newProfileID)
        environments.selectedProfileUpdate.send()
        if environments.extensionProfile!.status.isConnected {
            do {
                try await serviceReload()
            } catch {
                alert = Alert(error)
            }
        }
        reasserting = false
    }
    private nonisolated func serviceReload() async throws {
        try LibboxNewStandaloneCommandClient()?.serviceReload()
    }
    
    
}

