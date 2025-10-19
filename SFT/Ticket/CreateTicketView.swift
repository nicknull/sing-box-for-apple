//
//  Untitled.swift
//  sing-box
//
//  Created by xiaokang chen on 2025/6/24.
//
import SwiftUI
import ApplicationLibrary

struct CreateTicketView: View {
    @State private var subject = ""
    @State private var level = 0
    @State private var message = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingPopup = false

    
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section("工单信息") {
                TextField("主题", text: $subject)
                Picker("优先级", selection: $level) {
                    Text("低").tag(0)
                    Text("中").tag(1)
                    Text("高").tag(2)
                }
                .pickerStyle(.menu)
                TextEditor(text: $message)
                    .frame(minHeight: 150)
            }
            
            Button(action: submit) {
                HStack {
                    Text(isLoading ? "提交中..." : "提交工单")
                    if isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(isLoading || subject.isEmpty || message.isEmpty)
        }
        .navigationTitle("新建工单")
        // 在视图修饰符
        .toast(isPresenting: $showingSuccess) {
            ToastNotification(
                type: .complete(.green),
                title: "提交成功"
            )
        }
        .toast(isPresenting: $showingPopup) {
            ToastNotification(
                type: .systemImage("exclamationmark.triangle", .red),
                title: errorMessage
            )
        }
    }
    
    private func submit() {
        isLoading = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        NetworkService.shared.request(
            AQAPIService.ticketSave(
                subject: subject,
                level: level,
                message: message
            ),
            decodeTo: CreateTicketResponse.self
        ) { result in
            isLoading = false
            switch result {
            case .success(let payload):
                if payload.model?.data == true {
                    dismiss()
                } else {
                    errorMessage = payload.model?.message ?? payload.context.message ?? "提交失败"
                    showingPopup = true
                }

            case .failure(let error):
                errorMessage = error.message
                showingPopup = true
            }
        }
    }
}

