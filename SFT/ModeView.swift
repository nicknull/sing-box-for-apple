//
//  ModeView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/9/10.
//

import SwiftUI
import Libbox
import Library

struct ModeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var commandClient = CommandClient(.clashMode)
    @State private var clashMode = ""
    @State private var alert: Alert?

    var body: some View {
        VStack {
            if commandClient.clashModeList.count > 1 {
//                List{
                    Picker("代理模式", selection: Binding(get: {
                        clashMode
                    }, set: { newMode in
                        clashMode = newMode
                        Task.detached {
                            await setMode(newMode)
                        }
                    }), content: {
                        ForEach(commandClient.clashModeList, id: \.self) { it in
                            Text(it)
                        }
                    })
                    .pickerStyle(.navigationLink)
//                }
            }
        }
        .onReceive(commandClient.$clashMode) { newMode in
            clashMode = newMode
        }
        .onAppear {
            commandClient.connect()
        }
        .onDisappear {
            commandClient.disconnect()
        }
        .onChangeCompat(of: scenePhase) { newValue in
            if newValue == .active {
                commandClient.connect()
            } else {
                commandClient.disconnect()
            }
        }
        .alertBinding($alert)
    }
    private func setMode(_ newMode: String) {
        do {
            try LibboxNewStandaloneCommandClient()!.setClashMode(newMode)
        } catch {
            alert = Alert(error)
        }
    }

}

#Preview {
    ModeView()
}
