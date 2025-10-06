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
        NewNetWorkRequest(
            AQAPIService.ticketSave(
                subject: subject,
                level: level,
                message: message
            ),
            modelType: CreateTicketResponse.self
        ) { response, error in
            if(response != nil){
                if(response?.message != nil ){
                    errorMessage = response?.message ?? ""
                    showingPopup = true

                }else if(response?.data == true){
                    dismiss()
                }
            }

            isLoading = false
            // 在submit函数中
//            if response?.code == 200 {
//                showingSuccess = true
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                    dismiss()
//                }
//            } else {
//                errorMessage = error ?? "提交失败"
//            }
            
        }
    }
}


