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
    @State private var showSuccess = false
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
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage ?? ""),
                    dismissButton: .default(Text("确定"), action: {
                        alertMessage = nil
                        showAlert = false
                    })
                )
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
            .popup(isPresented: $showSuccess) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 28))
                    Text("购买成功！")
                        .font(.footnote)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.75))
                .cornerRadius(14)
            } customize: {
                $0
                    .type(.toast)
                    .position(.top)
                    .animation(.easeInOut)
                    .autohideIn(1.6)
                    .closeOnTap(true)
                    .closeOnTapOutside(true)
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
        let sections = planSections(products: productDictionary)

        return List {
            ForEach(sections) { section in
                Section {
                    ZStack {
                        planCard(for: section)
                        NavigationLink {
                            PlanDetailView(
                                plan: section.plan,
                                options: section.options,
                                isPurchasing: $isPurchasing,
                                onPurchase: { product in
                                    await purchase(product: product)
                                }
                            )
                        } label: {
                            EmptyView()
                        }
                        .opacity(0.001)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listSectionSeparator(.hidden)
            }

            Section(footer: Text("若已在其它设备购买，可在此恢复购买")) {
                Button("恢复购买") {
                    Task { await restorePurchases() }
                }
                .disabled(isPurchasing)
            }
        }
        .listStyle(.insetGrouped)
        .disabled(isPurchasing)
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
            if success {
                do {
                    try await transaction.finish()
                } catch {
                    NSLog("finish transaction failed: %@", error.localizedDescription)
                }
            }
            await MainActor.run {
                isPurchasing = false
                if success {
                    userManager.reload()
                    showSuccess = true
                } else {
                    alertMessage = "购买成功，但订单同步失败: \(errorMessage ?? "未知错误")"
                    showAlert = true
                }
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

        let snapshot = await purchaseManager.transactionsSnapshot(appAccountToken: appToken)
        if snapshot.isEmpty {
            await MainActor.run { presentAlert("当前没有可恢复的有效订阅") }
            return
        }
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

    func planCard(for section: PlanSection) -> some View {
        let plan = section.plan
        let footer: String? = section.lowestPriceDisplay.map { "最低 \($0) 起" } ?? "查看更多…"

        return VStack(alignment: .leading, spacing: 12) {
            Text(plan.name)
                .font(.title3)
                .fontWeight(.semibold)

            PlanMetaView(plan: plan)

            PlanFeaturesContent(plan: plan, limit: nil, footerText: footer)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .fill(Color(uiColor: .secondarySystemBackground))
//        )
//        .padding(.vertical, 4)
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
    struct PlanSection: Identifiable {
        let plan: PlanSummary
        let options: [PlanOption]
        var id: Int64 { plan.id }

        var lowestPriceDisplay: String? {
            guard let option = options.min(by: { $0.priceValue < $1.priceValue }) else { return nil }
            return "\(option.label) \(option.product.displayPrice)"
        }
    }

    struct PlanOption: Identifiable {
        let product: Product
        let label: String
        var id: String { product.id }

        var priceValue: Decimal { product.price }
    }

    func planSections(products: [String: Product]) -> [PlanSection] {
        productGroups.compactMap { group in
            let plan = plan(for: group) ?? PlanSummary(id: group.planID, name: group.displayName, transferEnable: 0, speedLimit: nil, content: nil)
            let options = group.periods.compactMap { period -> PlanOption? in
                let identifier = productIdentifier(groupKey: group.key, periodCode: period.code)
                guard let product = products[identifier] else { return nil }
                return PlanOption(product: product, label: period.label)
            }
            guard !options.isEmpty else { return nil }
            return PlanSection(plan: plan, options: options)
        }
    }

    func plan(for group: ProductGroup) -> PlanSummary? {
        plans.first(where: { $0.id == group.planID })
    }
}

private struct PlanDetailView: View {
    let plan: PlanSummary
    let options: [PurchaseView.PlanOption]
    @Binding var isPurchasing: Bool
    let onPurchase: (Product) async -> Void

    var body: some View {
        List {
            Section("套餐介绍") {
                VStack(alignment: .leading, spacing: 12) {
                    PlanMetaView(plan: plan)
                    PlanFeaturesContent(plan: plan, limit: nil, footerText: nil)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("选择订阅周期") {
                ForEach(options) { option in
                    PlanOptionRow(option: option, isPurchasing: $isPurchasing) {
                        Task { await onPurchase(option.product) }
                    }
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .disabled(isPurchasing)
    }
}

private struct PlanOptionRow: View {
    let option: PurchaseView.PlanOption
    @Binding var isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.headline)
                    if !option.product.displayName.isEmpty {
                        Text(option.product.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(option.product.displayPrice)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Button {
                guard !isPurchasing else { return }
                onTap()
            } label: {
                Text(isPurchasing ? "处理中…" : "立即购买")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding(.vertical, 8)
    }
}

private struct PlanMetaView: View {
    let plan: PlanSummary

    var body: some View {
        HStack(spacing: 12) {
            Label(plan.transferDescription, systemImage: "arrow.up.arrow.down")
                .font(.callout)
            if let speed = plan.speedLimit {
                Label("限速 \(speed)Mbps", systemImage: "gauge")
                    .font(.callout)
            }
        }
        .foregroundColor(.primary)
    }
}

private struct PlanFeaturesContent: View {
    let plan: PlanSummary
    let limit: Int?
    let footerText: String?

    private var featuresToDisplay: [PlanSummary.PlanFeature] {
        let features = plan.contentFeatures
        guard let limit = limit else { return features }
        return Array(features.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if featuresToDisplay.isEmpty {
                Text("暂无更多介绍")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(featuresToDisplay.enumerated()), id: \.offset) { item in
                    let feature = item.element
                    let iconName = feature.isAvailable ? "checkmark.circle.fill" : "xmark.circle"
                    let iconColor: Color = feature.isAvailable
                        ? (feature.isDimmed ? .accentColor.opacity(0.4) : .accentColor)
                        : .secondary
                    let textColor: Color = feature.isAvailable
                        ? (feature.isDimmed ? .secondary : .primary)
                        : .secondary

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: iconName)
                            .font(.caption2)
                            .foregroundColor(iconColor)
                        Text(feature.text)
                            .font(.caption)
                            .foregroundColor(textColor)
                            .lineLimit(limit != nil ? 1 : nil)
                    }
                }

                if let footerText, !footerText.isEmpty {
                    Text(footerText)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}


private struct PlanSummary: Codable {
    let id: Int64
    let name: String
    let transferEnable: Int64
    let speedLimit: Int64?
    let content: String?

    init(id: Int64, name: String, transferEnable: Int64, speedLimit: Int64?, content: String?) {
        self.id = id
        self.name = name
        self.transferEnable = transferEnable
        self.speedLimit = speedLimit
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case transferEnable = "transfer_enable"
        case speedLimit = "speed_limit"
        case content
    }

    var transferDescription: String {
        if transferEnable <= 0 {
            return "信息同步中"
        }
        if transferEnable >= 10_000 {
            return "无限"
        }
        return "\(transferEnable)G"
    }

    var contentFeatures: [PlanFeature] {
        let parsed = PlanSummary.parseHTMLContent(content)
        if !parsed.isEmpty { return parsed }

        let legacy = PlanSummary.legacyLines(from: content)
        return legacy.map { PlanFeature(text: $0, isAvailable: true, isDimmed: false) }
    }
}

extension PlanSummary {
    struct PlanFeature: Hashable {
        let text: String
        let isAvailable: Bool
        let isDimmed: Bool
    }

    private static func parseHTMLContent(_ html: String?) -> [PlanFeature] {
        guard let html, !html.isEmpty else { return [] }

        let normalized = html
            .replacingOccurrences(of: "</div>", with: "</div>\n")
            .replacingOccurrences(of: "<li", with: "<div")
            .replacingOccurrences(of: "</li>", with: "</div>")
            .replacingOccurrences(of: "<div", with: "\n<div")

        var features: [PlanFeature] = []

        normalized.components(separatedBy: "\n").forEach { line in
            let segment = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty else { return }
            let lower = segment.lowercased()
            guard lower.contains("si si-") || lower.contains("span") else { return }

            let isAvailable = lower.contains("si si-check") || lower.contains("check")
            let isDimmed = lower.contains("opacity:0.3") || lower.contains("opacity: 0.3") || lower.contains("opacity:0.4")

            let cleaned = segment
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: [.regularExpression])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleaned.isEmpty else { return }
            features.append(PlanFeature(text: cleaned, isAvailable: isAvailable, isDimmed: isDimmed))
        }

        return features
    }

    private static func legacyLines(from html: String?) -> [String] {
        guard let raw = html else { return [] }

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
