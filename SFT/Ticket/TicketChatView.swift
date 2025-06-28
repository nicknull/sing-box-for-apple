import SwiftUI
import AlertToast

struct TicketChatView: View {
    @State private var newMessage = ""
    @State private var subject = ""

    
    @State private var selectedImage: UIImage? = nil
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPopup = false
    
    
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
                    Image(systemName: "photo")
                        .padding(8)
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
            
        }
        .navigationTitle(subject)
        .onAppear {
            loadMessages()
        }
        .toast(isPresenting: $showingPopup) {
            AlertToast(
                displayMode: .hud,
                type: .systemImage("exclamationmark.triangle", .red),
                title: errorMessage
            )
        }
        
    }
    
    private func loadMessages() {
        isLoading = true
        NewNetWorkRequest(AQAPIService.ticketFetch(id: ticketId), modelType: MessageData.self) {
            response, _ in
            if let messages = response?.message {  // 直接访问data.message
                self.messages = messages
                subject = response?.subject ?? ""
            }
        }
    }
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        isLoading = true
        
        NewNetWorkRequest(
            AQAPIService.ticketReply(id: ticketId, message: newMessage),
            modelType: MessageData.self
        ) { [self] response, error in
            isLoading = false
            if let newMsg = response?.message.last {
                messages.append(newMsg)
                newMessage = ""
                selectedImage = nil
            } else {
                errorMessage = error.messageStr
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
                            AsyncImage(url: URL(string: "https://pics0.baidu.com/feed/42166d224f4a20a49f4d1b0bd00b9732730ed010.jpeg@f_auto?token=b5ada3a4a3eaccf9cea4a074b849a2ef")) { phase in
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
                        .sheet(isPresented: $showFullImage) {
                            //                        FullScreenImageView(imageURL: picURL)
                        }
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
        //        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.is_me ? .trailing : .leading)
        //        .padding(.horizontal, 10)
        //        .padding(.vertical, 10)
    }
    
    private func validImageURL(from string: String?) -> URL? {
        guard let str = string,
              let url = URL(string: str),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}


