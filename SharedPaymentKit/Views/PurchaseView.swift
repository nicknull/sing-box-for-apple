//
//  PurchaseView.swift
//  SharedPaymentKit
//
//  统一的内购购买页，负责加载商品、发起购买、恢复交易与提示用户状态。
//

import SwiftUI
import StoreKit
import ExytePopupView

private typealias PurchaseResult = (transaction: StoreKit.Transaction?, purchaseState: PurchaseXState)

struct PurchaseView: View {

    @EnvironmentObject private var userManager: UserManager
    @StateObject private var purchaseManager: PurchaseXManager

    @State private var screenState: ScreenState = .idle
    @State private var isPurchasing = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var plans: [PlanSummary] = []

    private let productIDs: [String]
    private let productGroups: [ProductGroup] = [
        ProductGroup(
            key: "bcup",
            displayName: "常规 中杯",
            planID: 7,
            periods: [
                ProductPeriod(code: "month", label: "月付"),
                ProductPeriod(code: "quart", label: "季付"),
                ProductPeriod(code: "year", label: "年付")
            ]
        ),
        ProductGroup(
            key: "ccup",
            displayName: "常规 大杯",
            planID: 2,
            periods: [
                ProductPeriod(code: "month", label: "月付"),
                ProductPeriod(code: "quart", label: "季付"),
                ProductPeriod(code: "year", label: "年付")
            ]
        ),
        ProductGroup(
            key: "dcup",
            displayName: "常规 超大杯",
            planID: 8,
            periods: [
                ProductPeriod(code: "month", label: "月付"),
                ProductPeriod(code: "quart", label: "季付"),
                ProductPeriod(code: "year", label: "年付")
            ]
        ),
        ProductGroup(
            key: "zcup",
            displayName: "无限流量",
            planID: 9,
            periods: [
                ProductPeriod(code: "year", label: "年付")
            ]
        )
    ]

    init(productIDs: [String] = [
        "com.gy.iflash.bcup.month",
        "com.gy.iflash.bcup.quart",
        "com.gy.iflash.bcup.year",
        "com.gy.iflash.ccup.month",
        "com.gy.iflash.ccup.quart",
        "com.gy.iflash.ccup.year",
        "com.gy.iflash.dcup.month",
        "com.gy.iflash.dcup.quart",
        "com.gy.iflash.dcup.year",
        "com.gy.iflash.zcup.year"
    ]) {
        self.productIDs = productIDs
        let manager = PurchaseXManager()
        manager.onPurchaseSuccess = { transaction in
            NSLog("purchase success: \(transaction.productID)")
        }
        _purchaseManager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        content
            .navigationTitle("选择套餐")
            .task {
                configurePurchaseCallbacksIfNeeded()
                guard screenState == .idle else { return }
                await loadInitialData()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("确定")))
            }
            .popup(isPresented: $isPurchasing) {
                hudView
            } customize: {
                $0
                    .type(.toast)
                    .position(.center)
                    .animation(.easeInOut)
                    .closeOnTap(false)
                    .closeOnTapOutside(false)
            }
    }
}

// MARK: - Screen State

private extension PurchaseView {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded([Product])
        case empty
    }
}

// MARK: - View Builders

private extension PurchaseView {
    @ViewBuilder
    var content: some View {
        switch screenState {
        case .idle, .loading:
            loadingView
        case .empty:
            emptyView
        case .loaded(let products):
            productList(products)
        }
    }

    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载中...")
            Spacer()
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("暂无可用商品")
                .foregroundColor(.secondary)
            Button("重新加载") {
                Task { await loadInitialData() }
            }
            Spacer()
        }
        .padding()
    }

    func productList(_ products: [Product]) -> some View {
        let productDictionary = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return List {
            ForEach(filteredSections(products: productDictionary), id: \.group.key) { section in
                Section(header: sectionHeader(for: section.group)) {
                    ForEach(section.items, id: \.product.id) { entry in
                        productRow(for: entry.product, subtitle: entry.subtitle)
                    }
                }
            }

            Section(footer: Text("若已在其它设备购买，可在此恢复购买")) {
                Button("恢复购买") {
                    Task { await restorePurchases() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .disabled(isPurchasing)
    }

    func productRow(for product: Product, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
//                if !product.description.isEmpty {
//                    Text(product.description)
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
            }
            Spacer()
            Text(product.displayPrice)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("购买") {
                Task { await purchase(product: product) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 6)
    }

    var hudView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在处理订单...")
                .font(.caption)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(16)
    }
}

// MARK: - Initialisation Flow

private extension PurchaseView {
    func configurePurchaseCallbacksIfNeeded() {
        if purchaseManager.onPurchaseSuccess == nil {
            purchaseManager.onPurchaseSuccess = { transaction in
                NSLog("purchase success: \(transaction.productID)")
            }
        }
    }

    func loadInitialData() async {
        await MainActor.run { screenState = .loading }
        if await isLoggedIn() {
            _ = await ensureAppToken()
        }
        let products = await fetchProducts()
        await MainActor.run {
            if products.isEmpty {
                screenState = .empty
            } else {
                screenState = .loaded(products)
            }
        }
        loadPlans()
    }

    func fetchProducts() async -> [Product] {
        await purchaseManager.requestProductsFromAppstore(productIds: productIDs) ?? []
    }
}

// MARK: - Purchase Actions

private extension PurchaseView {
    func purchase(product: Product) async {
        guard await isLoggedIn() else {
            await MainActor.run {
                presentAlert("请先登录")
            }
            return
        }

        await MainActor.run { isPurchasing = true }

        guard let appToken = await ensureAppToken() else {
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("账户标识缺失，请重新登录后再试")
            }
            return
        }

        do {
            let tradeNo = await prepareOrder(productID: product.id, appToken: appToken)
            let result = try await purchaseManager.purchase(product: product, userID: appToken)
            await handlePurchaseResult(result, tradeNo: tradeNo, appToken: appToken)
        } catch {
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("购买出错: \(error.localizedDescription)")
            }
        }
    }

    func handlePurchaseResult(_ result: PurchaseResult, tradeNo: String?, appToken: String) async {
        switch result.purchaseState {
        case .complete:
            guard let transaction = result.transaction else {
                await MainActor.run { isPurchasing = false }
            await MainActor.run {
                presentAlert("购买完成，但未获取到交易信息")
            }
                return
            }
            let (success, errorMessage) = await reportOrder(transaction: transaction, tradeNo: tradeNo, appToken: appToken)
            await MainActor.run {
                isPurchasing = false
                if success {
                    userManager.reload()
                    alertMessage = "购买成功！"
                } else {
                    alertMessage = "购买成功，但订单同步失败: \(errorMessage ?? "未知错误")"
                }
                showAlert = true
            }
        case .cancelled:
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("购买已取消")
            }
        case .pending:
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("购买待处理，请稍后查看")
            }
        case .failed:
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("购买失败")
            }
        default:
            await MainActor.run {
                isPurchasing = false
            }
            await MainActor.run {
                presentAlert("未知错误")
            }
        }
    }

    func restorePurchases() async {
        guard await isLoggedIn() else {
            await MainActor.run {
                presentAlert("请先登录")
            }
            return
        }

        guard let appToken = await currentAppToken() else {
            await MainActor.run {
                presentAlert("账户标识缺失，请重新登录后再试")
            }
            return
        }

        let snapshot = await purchaseManager.transactionsSnapshot()
        let (success, errorMessage) = await restoreOrders(appToken: appToken, transactions: snapshot)
        await MainActor.run {
            if success {
                userManager.reload()
                alertMessage = "恢复完成"
            } else {
                alertMessage = errorMessage ?? "恢复失败"
            }
            showAlert = true
        }
    }
}

// MARK: - Helpers

private extension PurchaseView {
    func prepareOrder(productID: String, appToken: String) async -> String? {
        await withCheckedContinuation { continuation in
            Task.detached {
                var tradeNo: String?
                let semaphore = DispatchSemaphore(value: 0)
                NewNetWorkRequest(
                    AQAPIService.prepareIAPOrder(productID: productID, appAccountToken: appToken),
                    modelType: PrepareIAPOrderResponse.self
                ) { model, _ in
                    tradeNo = model?.trade_no
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
                continuation.resume(returning: tradeNo)
            }
        }
    }

    func reportOrder(transaction: StoreKit.Transaction, tradeNo: String?, appToken: String) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            Task.detached {
                var result: (Bool, String?) = (false, "请求超时")
                let semaphore = DispatchSemaphore(value: 0)
                IAPOrderManager.reportOrder(transaction: transaction, tradeNo: tradeNo, appAccountToken: appToken) { success, error in
                    result = (success, error)
                    semaphore.signal()
                }
                let waitResult = semaphore.wait(timeout: .now() + 10)
                if waitResult == .timedOut {
                    continuation.resume(returning: (false, "请求超时"))
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    func restoreOrders(appToken: String, transactions: [[String: Any]]) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            Task.detached {
                var result: (Bool, String?) = (false, "请求超时")
                let semaphore = DispatchSemaphore(value: 0)
                IAPOrderManager.restorePurchases(appAccountToken: appToken, transactions: transactions) { success, error in
                    result = (success, error)
                    semaphore.signal()
                }
                let waitResult = semaphore.wait(timeout: .now() + 10)
                if waitResult == .timedOut {
                    continuation.resume(returning: (false, "请求超时"))
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    func ensureAppToken() async -> String? {
        if let token = await currentAppToken() {
            return token
        }

        await MainActor.run {
            userManager.reload()
        }

        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let token = await currentAppToken() {
                return token
            }
        }

        return nil
    }

    func currentAppToken() async -> String? {
        await MainActor.run {
            let token = userManager.userInfo?.app_account_token ?? ""
            return token.isEmpty ? nil : token
        }
    }

    func isLoggedIn() async -> Bool {
        await MainActor.run {
            userManager.isLoggedIn
        }
    }

    @MainActor
    func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    func loadPlans() {
        NewNetWorkRequest(
            AQAPIService.getPlans,
            modelType: [PlanSummary].self
        ) { model, _ in
            DispatchQueue.main.async {
                plans = model ?? []
            }
        }
    }

    func productIdentifier(groupKey: String, periodCode: String) -> String {
        "com.gy.iflash.\(groupKey).\(periodCode)"
    }

    @ViewBuilder
    func sectionHeader(for group: ProductGroup) -> some View {
        if let plan = plans.first(where: { $0.id == group.planID }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text("每月 \(plan.transferDescription)")
                    if let speed = plan.speedLimit {
                        Text("限速 \(speed)Mbps")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if !plan.contentLines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(plan.contentLines, id: \.self) { line in
                            Text("• \(line)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } else {
            Text(group.displayName)
        }
    }
}

// MARK: - Supporting Models

private extension PurchaseView {
    struct ProductGroup {
        let key: String
        let displayName: String
        let planID: Int64
        let periods: [ProductPeriod]
    }

    struct ProductPeriod {
        let code: String
        let label: String
    }
}

private extension PurchaseView {
    struct SectionItems {
        let group: ProductGroup
        let items: [(product: Product, subtitle: String)]
    }

    func filteredSections(products: [String: Product]) -> [SectionItems] {
        productGroups.compactMap { group in
            let matched = group.periods.compactMap { period -> (Product, String)? in
                let identifier = productIdentifier(groupKey: group.key, periodCode: period.code)
                guard let product = products[identifier] else { return nil }
                return (product, period.label)
            }
            guard !matched.isEmpty else { return nil }
            return SectionItems(group: group, items: matched)
        }
    }
}


private struct PlanSummary: Codable {
    let id: Int64
    let name: String
    let transferEnable: Int64
    let speedLimit: Int64?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case transferEnable = "transfer_enable"
        case speedLimit = "speed_limit"
        case content
    }

    var transferDescription: String {
        if transferEnable >= 10_000 {
            return "无限"
        }
        return "\(transferEnable)G"
    }

    var contentLines: [String] {
        guard let raw = content else { return [] }

        let cleaned = raw
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "</div>", with: "\n")
            .replacingOccurrences(of: "<div", with: "\n<div")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let stripped = cleaned.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: [.regularExpression]
        )
        return stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    PurchaseView().environmentObject(UserManager())
}
