//
//  ClosetBridgeSection.swift
//  irodori
//
//  「買い足すなら」セクション。
//  クローゼット + 明日の天気から、手持ち服が活きる買い足しアイテムを3件提案する。
//  各カードをタップすると Yahoo Shopping の商品ページ（アフィリエイト URL）を WebView で開く。
//

import SwiftUI

struct ClosetBridgeSection: View {
    let response: ClosetBridgeResponse?
    let isLoading: Bool
    let hasError: Bool
    let onTapItem: (ClosetBridgeItem) -> Void
    let onRetry: () -> Void

    var body: some View {
        // 成功したが提案0件の場合はセクションごと非表示（ホームの情報過多を避ける）
        if !isLoading && !hasError && (response?.items.isEmpty ?? true) {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader
                content
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("買い足すなら")
                .font(.system(size: 20, weight: .bold))
            Text("いまの服が活きる3着")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeleton
        } else if let items = response?.items, !items.isEmpty {
            VStack(spacing: 12) {
                // index ベースで識別（product.url 欠落時の id 衝突を避ける）
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ClosetBridgeItemCard(item: item) {
                        Haptic.impact(.soft)
                        onTapItem(item)
                    }
                }
            }
        } else {
            errorState
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 88, height: 110)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 60, height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 140, height: 12)
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 70, height: 14)
                    }
                    .frame(height: 110)
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        HStack(spacing: 12) {
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("提案を読み込めませんでした")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Button(action: onRetry) {
                    Text("再試行する")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .underline()
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Item Card

struct ClosetBridgeItemCard: View {
    let item: ClosetBridgeItem
    let onTap: () -> Void

    private var priceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let number = formatter.string(from: NSNumber(value: item.product.price)) ?? "\(item.product.price)"
        return "¥\(number)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                productImage
                VStack(alignment: .leading, spacing: 6) {
                    categoryChip
                    Text(item.product.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !item.outfit_caption.isEmpty {
                        Text(item.outfit_caption)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(priceText)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text("見る")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var productImage: some View {
        Group {
            // image_url が空だと URL(string:"") は nil となり CachedAsyncImage が
            // .empty のまま無限スピナーになるため、空の場合はプレースホルダを直接表示
            if !item.product.image_url.isEmpty, let url = URL(string: item.product.image_url) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholderIcon
                    @unknown default:
                        Color.gray.opacity(0.1)
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 88, height: 110)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 22))
            .foregroundStyle(Color.gray.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var categoryChip: some View {
        HStack(spacing: 6) {
            chip(text: item.spec.sub_category.isEmpty ? item.spec.category : item.spec.sub_category)
            if !item.spec.color.isEmpty {
                chip(text: item.spec.color)
            }
        }
    }

    private func chip(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.08))
            .clipShape(Capsule())
    }
}

#Preview {
    ScrollView {
        ClosetBridgeSection(
            response: .mock(),
            isLoading: false,
            hasError: false,
            onTapItem: { _ in },
            onRetry: {}
        )
        .padding()
    }
    .background(Color.gray.opacity(0.08))
}
