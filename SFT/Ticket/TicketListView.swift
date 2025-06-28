import SwiftUI

struct TicketListView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var tickets: [TicketModel] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isLoadingMore = false
    
    var body: some View {
        List {
            ForEach(tickets) { ticket in
                
                NavigationLink {
                    
                    TicketChatView(ticketId: ticket.id)
                } label: {
                    VStack(alignment: .leading) {
                        Text(ticket.subject)
                            .font(.headline)
                        
                        HStack {
                            Text("状态: \(statusText(ticket.status))")
                            Text("优先级: \(ticket.level)")
                        }
                        
                        Text("创建时间: \(Date(timeIntervalSince1970: ticket.createdAt).date2string())")
                            .font(.caption)
                    }
                    .padding(.vertical)
                    
                }
                
            }
        }
        .navigationTitle("我的工单")
        .onAppear(perform: loadTickets)
        .overlay {
            VStack {
                if isLoading {
                    ProgressView("加载中...")
                }
                if isLoadingMore {
                    ProgressView("正在加载更多...")
                }
            }
        }
        .alert("加载失败", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("确定") {}
        } message: {
            Text(errorMessage)
        }
        // 在TicketListView添加导航入口
        .navigationTitle("工单列表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CreateTicketView()
                } label: {
                    Label("新建", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }
        }
    }
    
    private func statusText(_ status: Int) -> String {
        switch status {
        case 0: return "待处理"
        case 1: return "已解决"
        default: return "未知状态"
        }
    }
    
    private func loadTickets() {
        isLoading = true
        NewNetWorkRequest(AQAPIService.getTickets, modelType: [TicketModel].self) { tickets, response in
            isLoading = false
            if let tickets = tickets {
                self.tickets = tickets
            } else {
                errorMessage = response.messageStr ?? "加载工单失败"
            }
        }
    }
}

