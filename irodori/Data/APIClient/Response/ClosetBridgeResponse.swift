//
//  ClosetBridgeResponse.swift
//  irodori
//
//  クローゼット + 明日の天気から「買い足すと幅が広がる」アイテムを提案するAPIのレスポンス。
//  GET /api/home/closet-bridge
//

import Foundation

/// LLM が提案するアイテム仕様（Yahoo 検索のクエリ元）
struct ClosetBridgeSpec: Decodable, Hashable {
    let category: String          // "トップス" / "ボトムス" / "アウター" / "シューズ" / "バッグ" / "アクセサリー"
    let sub_category: String      // 具体的な品目 (例: "ワイドパンツ")
    let color: String             // 色名
    let search_keywords: [String]
    let owned_pair_hint: String   // 組み合わせる既存クローゼットアイテム

    enum CodingKeys: String, CodingKey {
        case category, sub_category, color, search_keywords, owned_pair_hint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.category = (try? c.decode(String.self, forKey: .category)) ?? ""
        self.sub_category = (try? c.decode(String.self, forKey: .sub_category)) ?? ""
        self.color = (try? c.decode(String.self, forKey: .color)) ?? ""
        self.search_keywords = (try? c.decode([String].self, forKey: .search_keywords)) ?? []
        self.owned_pair_hint = (try? c.decode(String.self, forKey: .owned_pair_hint)) ?? ""
    }

    init(category: String, sub_category: String, color: String, search_keywords: [String] = [], owned_pair_hint: String = "") {
        self.category = category
        self.sub_category = sub_category
        self.color = color
        self.search_keywords = search_keywords
        self.owned_pair_hint = owned_pair_hint
    }
}

/// Yahoo Shopping から取得した商品情報（アフィリエイト URL 含む）
struct ClosetBridgeProduct: Decodable, Hashable {
    let name: String
    let price: Int
    let url: String               // 商品ページ URL (アフィリエイト付き)
    let image_url: String
    let store_name: String

    enum CodingKeys: String, CodingKey {
        case name, price, url, image_url, store_name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.price = (try? c.decode(Int.self, forKey: .price)) ?? 0
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
        self.image_url = (try? c.decode(String.self, forKey: .image_url)) ?? ""
        self.store_name = (try? c.decode(String.self, forKey: .store_name)) ?? ""
    }

    init(name: String, price: Int, url: String, image_url: String, store_name: String = "") {
        self.name = name
        self.price = price
        self.url = url
        self.image_url = image_url
        self.store_name = store_name
    }
}

/// 買い足し提案 1 アイテム（spec + 商品候補リスト + キャプション + ZOZO検索）
struct ClosetBridgeItem: Decodable, Hashable, Identifiable {
    let spec: ClosetBridgeSpec
    let products: [ClosetBridgeProduct]   // Yahoo スコア順 最大10件
    let outfit_caption: String            // 30字程度のコーデ説明文
    let zozo_search_url: String           // ZOZOTOWN 検索ディープリンク

    var id: String {
        let first = products.first?.url ?? ""
        return first.isEmpty ? "\(spec.category)_\(spec.sub_category)_\(spec.color)" : first
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.spec = try c.decode(ClosetBridgeSpec.self, forKey: .spec)
        // 新形式 products を優先。無ければ旧形式 product(単数)を単体配列にフォールバック。
        if let list = try? c.decode([ClosetBridgeProduct].self, forKey: .products), !list.isEmpty {
            self.products = list
        } else if let single = try? c.decode(ClosetBridgeProduct.self, forKey: .product) {
            self.products = [single]
        } else {
            self.products = []
        }
        self.outfit_caption = (try? c.decode(String.self, forKey: .outfit_caption)) ?? ""
        self.zozo_search_url = (try? c.decode(String.self, forKey: .zozo_search_url)) ?? ""
    }

    init(spec: ClosetBridgeSpec, products: [ClosetBridgeProduct], outfit_caption: String, zozo_search_url: String = "") {
        self.spec = spec
        self.products = products
        self.outfit_caption = outfit_caption
        self.zozo_search_url = zozo_search_url
    }

    enum CodingKeys: String, CodingKey {
        case spec, products, product, outfit_caption, zozo_search_url
    }
}

struct ClosetBridgeResponse: Decodable, Hashable {
    let status: String            // "success" | "partial" | "failed"
    let user_id: String
    let gender: String
    let elapsed_ms: Int
    let items: [ClosetBridgeItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "failed"
        self.user_id = (try? c.decode(String.self, forKey: .user_id)) ?? ""
        self.gender = (try? c.decode(String.self, forKey: .gender)) ?? ""
        self.elapsed_ms = (try? c.decode(Int.self, forKey: .elapsed_ms)) ?? 0
        self.items = (try? c.decode([ClosetBridgeItem].self, forKey: .items)) ?? []
    }

    init(status: String, user_id: String, gender: String, elapsed_ms: Int, items: [ClosetBridgeItem]) {
        self.status = status
        self.user_id = user_id
        self.gender = gender
        self.elapsed_ms = elapsed_ms
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case status, user_id, gender, elapsed_ms, items
    }
}

// MARK: - Mock

extension ClosetBridgeResponse {
    /// モック用に同一プレフィックスの商品を6件生成
    static func mockProducts(prefix: String, base: Int) -> [ClosetBridgeProduct] {
        (0..<6).map { i in
            .init(
                name: "\(prefix) その\(i + 1)",
                price: base + i * 500,
                url: "https://shopping.yahoo.co.jp/products/sample-\(abs(prefix.hashValue))-\(i)",
                image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg",
                store_name: "サンプルストア"
            )
        }
    }

    static func mock() -> Self {
        .init(
            status: "success",
            user_id: "mock_user",
            gender: "men",
            elapsed_ms: 1200,
            items: [
                .init(
                    spec: .init(category: "アウター", sub_category: "ステンカラーコート", color: "ベージュ", search_keywords: ["ベージュ", "ステンカラーコート"], owned_pair_hint: "白T・黒スラックス"),
                    products: Self.mockProducts(prefix: "ステンカラーコート メンズ ベージュ", base: 7990),
                    outfit_caption: "手持ちの白T×黒パンツに羽織るだけで一気に大人見え。",
                    zozo_search_url: "https://zozo.jp/search/?p_keyv=\("ベージュ ステンカラーコート メンズ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                ),
                .init(
                    spec: .init(category: "シューズ", sub_category: "レザースニーカー", color: "ホワイト", search_keywords: ["白", "レザースニーカー"], owned_pair_hint: "デニム全般"),
                    products: Self.mockProducts(prefix: "レザースニーカー 白 メンズ", base: 5480),
                    outfit_caption: "どんなボトムスとも相性◎の万能白スニーカー。",
                    zozo_search_url: "https://zozo.jp/search/?p_keyv=\("白 レザースニーカー メンズ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                ),
                .init(
                    spec: .init(category: "トップス", sub_category: "ニットベスト", color: "チャコール", search_keywords: ["チャコール", "ニットベスト"], owned_pair_hint: "白シャツ"),
                    products: Self.mockProducts(prefix: "ニットベスト メンズ チャコール", base: 3990),
                    outfit_caption: "白シャツに重ねるだけで季節感のあるレイヤード。",
                    zozo_search_url: "https://zozo.jp/search/?p_keyv=\("チャコール ニットベスト メンズ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                ),
            ]
        )
    }
}
