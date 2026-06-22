//
//  ClosetBridgeSection.swift
//  irodori
//
//  「買い足すなら」セクション。
//  クローゼット + 明日の天気から、手持ち服が活きる買い足しカテゴリを3件提案する。
//  各カテゴリは Yahoo Shopping の商品を最大10件 横スクロールで提示し、
//  商品タップで商品ページ（アフィリエイト URL）を、「ZOZOTOWNで探す」で
//  ZOZOTOWN の検索ページを WebView で開く。
//

import SwiftUI

struct ClosetBridgeSection: View {
    let response: ClosetBridgeResponse?
    let isLoading: Bool
    let hasError: Bool
    let onTapProduct: (ClosetBridgeProduct) -> Void
    let onTapZozo: (ClosetBridgeItem) -> Void
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
            Text("いまの服が活きる3カテゴリ")
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
            VStack(spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ClosetBridgeItemRow(
                        item: item,
                        onTapProduct: onTapProduct,
                        onTapZozo: onTapZozo
                    )
                }
            }
        } else {
            errorState
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(spacing: 14) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 160, height: 12)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<4, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)).frame(width: 132, height: 132)
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 100, height: 11)
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 60, height: 13)
                                }
                            }
                        }
                    }
                }
                .padding(14)
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

// MARK: - Sort Order

enum ClosetBridgeSortOrder: CaseIterable, Identifiable {
    case recommended      // Yahoo スコア順 (API 返却順)
    case priceAscending
    case priceDescending

    var id: Self { self }

    var label: String {
        switch self {
        case .recommended: return "おすすめ順"
        case .priceAscending: return "安い順"
        case .priceDescending: return "高い順"
        }
    }

    var iconSystemName: String {
        switch self {
        case .recommended: return "sparkles"
        case .priceAscending: return "arrow.up"
        case .priceDescending: return "arrow.down"
        }
    }
}

// MARK: - Item Row (1カテゴリ = キャプション + 商品横スクロール + ZOZO導線)

struct ClosetBridgeItemRow: View {
    let item: ClosetBridgeItem
    let onTapProduct: (ClosetBridgeProduct) -> Void
    let onTapZozo: (ClosetBridgeItem) -> Void

    @State private var sortOrder: ClosetBridgeSortOrder = .recommended

    private var sortedProducts: [ClosetBridgeProduct] {
        switch sortOrder {
        case .recommended:
            return item.products
        case .priceAscending:
            // 価格 0 (未取得) は末尾に回す
            return item.products.sorted { a, b in
                if a.price == 0 && b.price != 0 { return false }
                if b.price == 0 && a.price != 0 { return true }
                return a.price < b.price
            }
        case .priceDescending:
            return item.products.sorted { a, b in
                if a.price == 0 && b.price != 0 { return false }
                if b.price == 0 && a.price != 0 { return true }
                return a.price > b.price
            }
        }
    }

    /// 見出し文字列: サブカテゴリ(無ければカテゴリ) + 色。例: "テーパードパンツ グレー"
    private var headerTitle: String {
        let cat = item.spec.sub_category.isEmpty ? item.spec.category : item.spec.sub_category
        return item.spec.color.isEmpty ? cat : "\(cat) \(item.spec.color)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ヘッダ: 「サブカテゴリ + 色」(例: テーパードパンツ グレー) を見出しとして目立たせる。
            // 件数/ソートは下段に分離し、見出しが長文でも押し出されないようにする。
            // 見出しは最大2行で折り返し、それ以上は末尾省略 (横スクロールUIを崩さない)。
            VStack(alignment: .leading, spacing: 6) {
                Text(headerTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text("\(item.products.count)件")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    sortMenu
                }
            }

            if !item.outfit_caption.isEmpty {
                Text(item.outfit_caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 相性の良い手持ちアイテム: 「この服と合わせると◎」(色相性で選定, 最大3件)
            if !item.owned_items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("この服と合わせると◎")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(item.owned_items) { owned in
                            ownedItemThumbnail(owned)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            // 商品横スクロール（最大YAHOO_LIMIT_PER_ITEM件、ユーザー選択順）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(sortedProducts.enumerated()), id: \.offset) { _, product in
                        Button {
                            Haptic.impact(.soft)
                            onTapProduct(product)
                        } label: {
                            ClosetBridgeProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .animation(.easeInOut(duration: 0.2), value: sortOrder)
            }

            // ZOZOTOWN 検索導線
            if !item.zozo_search_url.isEmpty {
                Button {
                    Haptic.impact(.soft)
                    onTapZozo(item)
                } label: {
                    HStack(spacing: 6) {
                        Text("ZOZOTOWNで探す")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
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

    // 相性の良い手持ちアイテムのサムネイル (画像 + 色ラベル)
    private func ownedItemThumbnail(_ owned: ClosetBridgeOwnedItem) -> some View {
        VStack(spacing: 3) {
            CachedAsyncImage(url: owned.image_url.isEmpty ? nil : URL(string: owned.image_url)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()

            if let color = owned.color, !color.isEmpty {
                Text(color)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 56)
    }

    // 並び替えメニュー (おすすめ順 / 安い順 / 高い順)
    private var sortMenu: some View {
        Menu {
            ForEach(ClosetBridgeSortOrder.allCases) { order in
                Button {
                    Haptic.impact(.soft)
                    sortOrder = order
                } label: {
                    if order == sortOrder {
                        Label(order.label, systemImage: "checkmark")
                    } else {
                        Label(order.label, systemImage: order.iconSystemName)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9, weight: .semibold))
                Text(sortOrder.label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.08))
            .clipShape(Capsule())
        }
        .accessibilityLabel("商品の並び順")
        .accessibilityValue(sortOrder.label)
    }
}

// MARK: - Product Card (横スクロール内の1商品)

struct ClosetBridgeProductCard: View {
    let product: ClosetBridgeProduct

    private var priceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let number = formatter.string(from: NSNumber(value: product.price)) ?? "\(product.price)"
        return "¥\(number)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            productImage
            Text(product.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 132, height: 32, alignment: .topLeading)
            Text(priceText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            if !product.store_name.isEmpty {
                Text(product.store_name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 132, alignment: .leading)
            }
        }
        .frame(width: 132, alignment: .leading)
    }

    @ViewBuilder
    private var productImage: some View {
        Group {
            // image_url が空だと URL(string:"") は nil となり CachedAsyncImage が
            // .empty のまま無限スピナーになるため、空の場合はプレースホルダを直接表示
            if !product.image_url.isEmpty, let url = URL(string: product.image_url) {
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
        .frame(width: 132, height: 132)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 22))
            .foregroundStyle(Color.gray.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ScrollView {
        ClosetBridgeSection(
            response: .mock(),
            isLoading: false,
            hasError: false,
            onTapProduct: { _ in },
            onTapZozo: { _ in },
            onRetry: {}
        )
        .padding()
    }
    .background(Color.gray.opacity(0.08))
}
