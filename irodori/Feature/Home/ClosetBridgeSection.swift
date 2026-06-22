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
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("買い足すなら")
                    .font(.system(size: 20, weight: .bold))
                Text("いまの服が活きる3カテゴリ")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // アフィリエイト/外部ストア導線を含むため PR 表記（景表法・ステマ規制対応）
            Text("PR")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1)
                )
                .accessibilityLabel("広告。アフィリエイトリンクを含みます")
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
            ForEach(0..<3, id: \.self) { _ in
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
                .accessibilityLabel("再試行する")
                .accessibilityHint("提案の読み込みをやり直します")
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Button Style

/// カードタップ時に軽い押下フィードバック（縮小+減光）を与えるスタイル。
/// .buttonStyle(.plain) では押下が視覚化されないため、横スクロール内の
/// 商品カードや CTA に適用してタップの反応を明確にする。
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

                // 「買う理由」を見出し直後に置き、件数/ソートより先に購買判断の文脈を伝える。
                if !item.outfit_caption.isEmpty {
                    Text(item.outfit_caption)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Text("\(item.products.count)件")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    sortMenu
                }
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
            // LazyHStack でビューポート外カードの生成・画像ロードを遅延させ、
            // 初期表示の負荷（最大10件×3カテゴリの同時ロード）を抑える。
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(sortedProducts.enumerated()), id: \.offset) { _, product in
                        Button {
                            Haptic.impact(.soft)
                            onTapProduct(product)
                        } label: {
                            ClosetBridgeProductCard(product: product)
                        }
                        .buttonStyle(PressableCardButtonStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(productAccessibilityLabel(product))
                        .accessibilityHint("タップで商品ページが開きます")
                    }
                }
                .padding(.vertical, 2)
                .animation(.easeInOut(duration: 0.2), value: sortOrder)
            }

            // ZOZOTOWN 検索導線（横スクロールの商品＝主導線に対する補助。
            // 主従を明確にするためアウトラインのセカンダリボタンにする）
            if !item.zozo_search_url.isEmpty {
                Button {
                    Haptic.impact(.soft)
                    onTapZozo(item)
                } label: {
                    HStack(spacing: 6) {
                        Text("ZOZOTOWNでもっと探す")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.25), lineWidth: 1.2)
                    )
                }
                .buttonStyle(PressableCardButtonStyle())
                .accessibilityLabel("ZOZOTOWNでもっと探す")
                .accessibilityHint("外部サイトの検索結果が開きます")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ownedAccessibilityLabel(owned))
    }

    /// 手持ちアイテムサムネの読み上げ用ラベル（例:「合わせる手持ち：ホワイトのTシャツ」）
    private func ownedAccessibilityLabel(_ owned: ClosetBridgeOwnedItem) -> String {
        let color = owned.color ?? ""
        let kind = (owned.category?.isEmpty == false ? owned.category! : owned.item_type)
        let name = [color, kind].filter { !$0.isEmpty }.joined(separator: "の")
        return name.isEmpty ? "手持ちアイテム" : "合わせる手持ち：\(name)"
    }

    /// 商品カードの読み上げ用ラベル（画像/名前/価格/店名を1要素に統合）
    private func productAccessibilityLabel(_ product: ClosetBridgeProduct) -> String {
        var parts: [String] = [product.name]
        parts.append(product.price > 0 ? "\(product.price)円" : "価格はページで確認")
        if !product.store_name.isEmpty { parts.append(product.store_name) }
        return parts.joined(separator: "、")
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

    private var isPriceAvailable: Bool { product.price > 0 }

    private var priceText: String {
        // 価格0は「未取得」を意味する。¥0 と誤認させないため CTA 文言に置き換える。
        guard isPriceAvailable else { return "価格を見る" }
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
                .font(.system(size: 14, weight: isPriceAvailable ? .bold : .semibold))
                .foregroundStyle(isPriceAvailable ? Color.primary : Color.gray.opacity(0.7))
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
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
