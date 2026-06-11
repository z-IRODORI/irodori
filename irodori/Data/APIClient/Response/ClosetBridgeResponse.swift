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

/// クローゼットに足したい1着（spec + product + キャプション）
struct ClosetBridgeItem: Decodable, Hashable, Identifiable {
    var id: String { product.url.isEmpty ? "\(spec.category)_\(spec.sub_category)_\(spec.color)" : product.url }
    let spec: ClosetBridgeSpec
    let product: ClosetBridgeProduct
    let outfit_caption: String    // 30字程度のコーデ説明文

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.spec = try c.decode(ClosetBridgeSpec.self, forKey: .spec)
        self.product = try c.decode(ClosetBridgeProduct.self, forKey: .product)
        self.outfit_caption = (try? c.decode(String.self, forKey: .outfit_caption)) ?? ""
    }

    init(spec: ClosetBridgeSpec, product: ClosetBridgeProduct, outfit_caption: String) {
        self.spec = spec
        self.product = product
        self.outfit_caption = outfit_caption
    }

    enum CodingKeys: String, CodingKey {
        case spec, product, outfit_caption
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
    static func mock() -> Self {
        .init(
            status: "success",
            user_id: "mock_user",
            gender: "men",
            elapsed_ms: 1200,
            items: [
                .init(
                    spec: .init(category: "アウター", sub_category: "ステンカラーコート", color: "ベージュ", owned_pair_hint: "白T・黒スラックス"),
                    product: .init(name: "ステンカラーコート メンズ ロング ベージュ", price: 7990, url: "https://shopping.yahoo.co.jp/products/sample1", image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", store_name: "サンプルストア"),
                    outfit_caption: "手持ちの白T×黒パンツに羽織るだけで一気に大人見え。"
                ),
                .init(
                    spec: .init(category: "シューズ", sub_category: "レザースニーカー", color: "ホワイト", owned_pair_hint: "デニム全般"),
                    product: .init(name: "レザースニーカー 白 メンズ", price: 5480, url: "https://shopping.yahoo.co.jp/products/sample2", image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", store_name: "サンプルストア"),
                    outfit_caption: "どんなボトムスとも相性◎の万能白スニーカー。"
                ),
                .init(
                    spec: .init(category: "トップス", sub_category: "ニットベスト", color: "チャコール", owned_pair_hint: "白シャツ"),
                    product: .init(name: "ニットベスト メンズ チャコール", price: 3990, url: "https://shopping.yahoo.co.jp/products/sample3", image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", store_name: "サンプルストア"),
                    outfit_caption: "白シャツに重ねるだけで季節感のあるレイヤード。"
                ),
            ]
        )
    }
}
