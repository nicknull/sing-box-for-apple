import SwiftUI
import ApplicationLibrary
import Defaults

struct TicketChatView: View {
    @State private var newMessage = ""
    @State private var subject = ""
    @State private var status = 1
    @State private var reply_status = 1

    
    @State private var selectedImage: UIImage? = nil
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPopup = false
    
    @Environment(\.dismiss) var dismiss
    let ticketId: Int
    
    var body: some View {
        VStack {
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
                .disabled(status == 1 || reply_status == 0)            
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
            ToastNotification(
                displayMode: .hud,
                type: .systemImage("exclamationmark.triangle", .red),
                title: errorMessage
            )
        }
        .loadingHUD(isPresented: $isLoading, message: "加载中...")
    }
    
    private func loadMessages() {
        isLoading = true
        NewNetWorkRequest(AQAPIService.ticketFetch(id: ticketId), modelType: MessageData.self) {
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
        guard !newMessage.isEmpty else { return }
        
        isLoading = true
        
        NewNetWorkRequest(
            AQAPIService.ticketReply(id: ticketId, message: newMessage, imageData: selectedImage?.jpegData(compressionQuality: 0.8)),
            modelType: CreateTicketResponse.self
        ) { [self] response, error in
            isLoading = false
            if(response?.data == true){
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
            AQAPIService.ticketClose(id: ticketId),
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

// MARK: - 图片处理扩展
// 添加UIViewControllerRepresentable协议
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            picker.dismiss(animated: true)
        }
    }
    
}

// 修改selectImage方法
private extension TicketChatView {
    func selectImage() {
        let imagePicker = ImagePicker(selectedImage: $selectedImage)
        let hostingController = UIHostingController(rootView: imagePicker)
        UIApplication.shared.windows.first?.rootViewController?.present(
            hostingController, animated: true)
    }
}

struct MessageBubbleModifier: ViewModifier {
    let isMe: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isMe ? Color.blue : Color(UIColor.systemGray5))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isMe ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showFullImage = false
    
    var body: some View {
        VStack() {
            HStack{
                
                if message.is_me {
                    Spacer()
                }
                
                Group {
                    if let picURLString = message.pic,
                       let picURL = validImageURL(from: picURLString){
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: picURL) { phase in
                                phase.image?
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 200)
                                    .cornerRadius(8)
                                    .onTapGesture { showFullImage = true }
                            }
                            
                            if !message.message.isEmpty {
                                Text(message.message)
                                    .font(.system(size: 16))
                                    .foregroundColor(message.is_me ? .white:.gray)
                            }
                        }
                        .fullScreenCover(isPresented: $showFullImage, content: {
                            FullScreenImageView(imageURL: picURL)

                        })
                    } else {
                        
                        Text(message.message)
                            .font(.system(size: 16))
                            .foregroundColor(message.is_me ? .white:.gray)
                    }
                }
                .modifier(MessageBubbleModifier(isMe: message.is_me))
                if !message.is_me {
                    Spacer()
                }
                
            }
            HStack {
                if !message.is_me {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                if message.is_me {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func validImageURL(from string: String?) -> URL? {
        guard let path = string,
              let baseURL = URL(string: Defaults[.host])
        else {
            return nil
        }
        return baseURL.appendingPathComponent(path)
    }
}


