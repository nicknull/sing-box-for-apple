import SwiftUI

struct TicketListView_admin: View {
    @EnvironmentObject var userManager: UserManager
    @State private var tickets: [TicketModel] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isLoadingMore = false
    @State private var selectedStatus: Int = 0
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = true
    
    var body: some View {
        VStack {
            // 工单状态筛选器
            Picker("状态筛选", selection: $selectedStatus) {
                Text("未处理").tag(0)
                Text("已处理").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedStatus) { _ in
                Task {
                    await refreshTickets()
                }
            }
            
            // 工单列表
            List {
                ForEach(tickets) { ticket in
                    NavigationLink {
                        TicketChatView_admin(ticketId: ticket.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(ticket.subject)
                                .fontWeight(.bold)
                                .foregroundColor(levelColor(ticket.level))
                            let (statusText, statusColor) = statusTextAndColor(ticket.status, ticket.replyStatus)
                            HStack {
                                Text("创建时间: \(Date(timeIntervalSince1970: ticket.createdAt).date2string())")
                                    .font(.caption)
                                Spacer()
                                Text(statusText)
                                    .foregroundColor(statusColor)
                                    .font(.caption)
                            }
                        }
                    }
                    .onAppear {
                        if ticket.id == tickets.last?.id && canLoadMore && !isLoadingMore {
                            loadMoreTickets()
                        }
                    }
                }
                
                // 加载更多提示
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await refreshTickets()
            }
        }
        .navigationTitle("工单列表")
        .onAppear {
            if tickets.isEmpty {
                loadTickets(reset: true)
            }
        }
        // 加载状态覆盖层
        .overlay {
            if isLoading {
                ProgressView("加载中...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .alert("加载失败", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("确定") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func statusTextAndColor(_ status: Int, _ replyStatus: Int) -> (String, Color) {
        switch status {
        case 0:
            if replyStatus == 0 {
                return ("已回复", .blue)
            } else if replyStatus == 1 {
                return ("待回复", .red)
            } else {
                return ("未知", .gray)
            }
        case 1:
            return ("已关闭", .green)
        default:
            return ("未知", .gray)
        }
    }
    
    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: return .green
        case 1: return .orange
        case 2: return .red
        default: return .gray
        }
    }
    
    /// 加载工单
    private func loadTickets(reset: Bool = false) {
        if reset {
            currentPage = 1
            tickets.removeAll()
            canLoadMore = true
        }
        isLoading = currentPage == 1
        isLoadingMore = currentPage > 1
        
        NewNetWorkRequest(AQAPIService.getTickets_admin(pageSize: 10, current: currentPage, status: selectedStatus), modelType: [TicketModel].self) { result, response in
            isLoading = false
            isLoadingMore = false
            
            if let newTickets = result {
                if newTickets.count < 10 {
                    canLoadMore = false
                }
                if currentPage == 1 {
                    tickets = newTickets
                } else {
                    tickets.append(contentsOf: newTickets)
                }
                currentPage += 1
            } else {
                errorMessage = response.messageStr ?? "加载工单失败"
            }
        }
    }
    
    /// 加载更多
    private func loadMoreTickets() {
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        loadTickets()
    }
    
    /// 刷新数据
    private func refreshTickets() async {
        await withCheckedContinuation { continuation in
            loadTickets(reset: true)
            // 模拟 async 结束，因为 NewNetWorkRequest 没有 async 版，这里立刻返回
            continuation.resume()
        }
    }
}
