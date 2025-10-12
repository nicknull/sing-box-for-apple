//
//  PlanDetailView.swift
//  SharedPaymentKit
//
//  Modularised detail screen and supporting components for plan purchases.
//

import SwiftUI
import StoreKit
import ExytePopupView

struct PlanDetailView: View {
    let plan: PlanSummary
    let options: [PlanOption]
    @Binding var isPurchasing: Bool
    @Binding var showSuccess: Bool
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
        } customize: { popup in
            popup
                .type(.toast)
                .position(.top)
                .animation(.easeInOut)
                .autohideIn(1.6)
                .closeOnTap(true)
                .closeOnTapOutside(true)
        }
    }
}

struct PlanOption: Identifiable {
    let product: Product
    let label: String
    var id: String { product.id }

    var priceValue: Decimal { product.price }
}

struct PlanOptionRow: View {
    let option: PlanOption
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

struct PlanMetaView: View {
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

struct PlanFeaturesContent: View {
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

struct PlanSummary: Codable {
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
