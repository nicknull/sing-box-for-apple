import SwiftUI
import AlertToast
import Defaults

struct TicketChatView_admin: View {
    @State private var newMessage = ""
    @State private var subject = ""
    @State private var status = 1
    @State private var reply_status = 1
    
    
    @State private var selectedImage: UIImage? = nil
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPopup = false
    
    @FocusState private var isInputActive: Bool
    
    @Environment(\.dismiss) var dismiss
    let ticketId: Int
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(messages) { message in
                            // 消息排列逻辑修正
                            HStack {
                                if message.is_me {
                                    Spacer()
                                }
                                MessageBubble(message: message)
                                if !message.is_me {
                                    Spacer()
                                }
                            }
                            .padding()
                        }
                    }
                    .id("lastMessage")
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("lastMessage", anchor: .bottom)
                    }
                }
                
            }
            
            HStack {
                Button(action: selectImage) {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 100, maxHeight: 100)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "photo")
                            .padding(8)
                    }
                }
                .padding(.leading, 8)
                
                TextField("输入消息...", text: $newMessage)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .focused($isInputActive)
                Button("发送") {
                    sendMessage()
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 8)
            .padding(.bottom)
            .disabled(status == 1)
        }
        .navigationTitle(subject)
        .onAppear {
            loadMessages()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: closeTicket) {
                    Text("关闭工单")
                }
                .disabled(status == 1)
            }
        }
        
        .toast(isPresenting: $showingPopup) {
            AlertToast(
                displayMode: .hud,
                type: .systemImage("exclamationmark.triangle", .red),
                title: errorMessage
            )
        }
        .loadingHUD(isPresented: $isLoading, message: "加载中...")
        
    }
    
    private func loadMessages() {
        isLoading = true
        NewNetWorkRequest(AQAPIService.ticketFetch_admin(id: ticketId), modelType: MessageData.self) {
            response, _ in
            isLoading = false
            if let messages = response?.message {  // 直接访问data.message
                self.messages = messages
                subject = response?.subject ?? ""
                status = response?.status ?? 1
                
                reply_status = response?.reply_status ?? 1
            }
        }
    }
    private func sendMessage() {
        guard !newMessage.isEmpty else {
            errorMessage = "内容不能为空"
            showingPopup = true
            return
        }
        
        isLoading = true
        
        NewNetWorkRequest(
            AQAPIService.ticketReply_admin(id: ticketId, message: newMessage, imageData: selectedImage?.jpegData(compressionQuality: 0.8)),
            modelType: CreateTicketResponse.self
        ) { [self] response, error in
            isLoading = false
            if(response?.data == true){
                newMessage = ""
                selectedImage = nil
                isInputActive = false
                loadMessages()
            }else{
                errorMessage = response?.message
                showingPopup = true
            }
        }
    }
    
    
    private func closeTicket() {
        isLoading = true
        NewNetWorkRequest(
            AQAPIService.ticketClose_admin(id: ticketId),
            modelType: CreateTicketResponse.self
        ) { [self] response, error in
            isLoading = false
            if(response?.data == true){
                dismiss()
            }else{
                errorMessage = response?.message
                showingPopup = true
            }
        }
        
    }
}

// 修改selectImage方法
private extension TicketChatView_admin {
    func selectImage() {
        let imagePicker = ImagePicker(selectedImage: $selectedImage)
        let hostingController = UIHostingController(rootView: imagePicker)
        UIApplication.shared.windows.first?.rootViewController?.present(
            hostingController, animated: true)
    }
}


