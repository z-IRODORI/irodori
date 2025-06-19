//
//  FashionReviewResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import Foundation

struct FashionReviewResponse: Decodable {
    var createdAt: String?
    var tops_image_url: String
    var bottoms_image_url: String
    var coordinate: Coordinate
    var graph_image: String   // URL
    var recommendations: [WEARUser]

    struct Coordinate: Decodable {
        var coordinate_review: String

        // TODO: 01~03 をリストで管理
        var coordinate_item01: String
        var recommend_item01: String
//        var recommend_item01_url: String? = "https://zozo.jp/"

        var coordinate_item02: String
        var recommend_item02: String
//        var recommend_item02_url: String? = "https://zozo.jp/"

        var coordinate_item03: String
        var recommend_item03: String
//        var recommend_item03_url: String? = "https://zozo.jp/"
    }

    struct WEARUser: Decodable, Hashable {
        var username: String
        var post_url: String
        var image_url: String
    }
}

extension FashionReviewResponse {
    static func mock() -> Self {
        .init(
            createdAt: "20250605044340",
            tops_image_url: "https://c.imgz.jp/086/75033086/75033086b_144_d_500.jpg",
            bottoms_image_url: "https://c.imgz.jp/407/81070407/81070407_5_d_500.jpg",
            coordinate: .init(
                coordinate_review: "素敵なコーデですね！グリーンのニットとチェックのシャツが重ね着されていて、明るくて元気な印象を与えています。ギンガムチェックの襟元がオシャレで、スカートのストライプが全体を引き締めています。全体的にカジュアルなのに、ちょっとしたエレガンスも感じられる素敵なスタイルです。",
                coordinate_item01: "グリーンのニット",
                recommend_item01: "白のフレアパンツで、軽やかさを演出するとさらに良いでしょう。",
//                recommend_item01_url: "https://zozo.jp/",
                coordinate_item02: "チェックのシャツ",
                recommend_item02: "無地のブラウスに変えて、よりシンプルにまとめて大人っぽく見せるのもおすすめです。",
//                recommend_item02_url: "https://zozo.jp/",
                coordinate_item03: "ストライプのスカート",
                recommend_item03: "ミディスカートと合わせて、トレンド感をプラスするのも良いですね。"//,
//                recommend_item03_url: "https://zozo.jp/"
            ),
            graph_image: "https://images.wear2.jp/coordinate/bBildLXx/f42NPtI0/1748770665_1000.jpg",
            recommendations: [
                .init(
                    username: "10momoon10",
                    post_url: "https://wear.jp/10momoon10/23659966/",
                    image_url: "https://images.wear2.jp/coordinate/GrigMn7m/QRJwxFx7/1702044228_276.jpg"
                ),
                .init(
                    username: "みさね",
                    post_url: "https://wear.jp/misane1209/25473513/",
                    image_url: "https://images.wear2.jp/coordinate/zaib64wl/3GUjtLHo/1750110272_1000.jpg"
                ),
                .init(
                    username: "UMI",
                    post_url: "https://wear.jp/umichuxx/25450621/",
                    image_url: "https://images.wear2.jp/coordinate/bBildLXx/POZ0Kpli/1749600374_1000.jpg"
                )
            ]
        )
    }
}

extension FashionReviewResponse.Coordinate {
    static func mock() -> Self {
        let coordinateReview: String = """
        黒のショルダーバッグがシンプルでコーデの引き締め役になっていて素敵ですね。
        トップスを軽くインしているので、ラフすぎず清潔感があります。\n程よくワイドなパンツを履いているので、リラックス感のある大人な印象を受けます。
        あなたのシルエットは「I」です。Iが似合うのは、縦長でスタイリッシュな印象を好む方や、シンプルで洗練された雰囲気を持った方です。
        また、あなたのコーデはカジュアルです。
        カジュアルが似合う方におすすめのコーデタイプは、シンプルで洗練された印象が特徴のノームコアです。
        画像の黒パンツに合うのは、白や淡いブルーのシャツです。理由としては、黒のパンツと明るい色味のシャツは相性がよく、シンプルながら爽やかで大人っぽい印象になるからです。
        """

        return .init(
            coordinate_review: coordinateReview,
//            coordinate_item01: "coordinate_item01", recommend_item01: "recommend_item01", recommend_item01_url: "https://zozo.jp/",
//            coordinate_item02: "coordinate_item02", recommend_item02: "recommend_item02", recommend_item02_url: "https://zozo.jp/",
//            coordinate_item03: "coordinate_item03", recommend_item03: "recommend_item03", recommend_item03_url: "https://zozo.jp/"

            coordinate_item01: "coordinate_item01", recommend_item01: "recommend_item01",
            coordinate_item02: "coordinate_item02", recommend_item02: "recommend_item02",
            coordinate_item03: "coordinate_item03", recommend_item03: "recommend_item03"
        )
    }
}
