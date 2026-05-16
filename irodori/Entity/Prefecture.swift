//
//  Prefecture.swift
//  irodori
//
//  47都道府県 (ISO 3166-2:JP の "01"-"47") とその地方分類.
//  天気・コーデ推薦の area_code 解決はバックエンド側で行う。
//

import Foundation

enum Region: String, CaseIterable, Identifiable {
    case hokkaido = "北海道"
    case tohoku = "東北"
    case kanto = "関東"
    case chubu = "中部"
    case kinki = "近畿"
    case chugoku = "中国"
    case shikoku = "四国"
    case kyushu = "九州・沖縄"

    var id: String { rawValue }
}

struct Prefecture: Identifiable, Hashable {
    /// ISO 3166-2:JP のサブディビジョンコード ("01"〜"47")
    let code: String
    let name: String
    let region: Region

    var id: String { code }
}

extension Prefecture {
    static let `default`: Prefecture = .all.first(where: { $0.code == "13" })! // 東京都

    /// 47件すべて (コード昇順)
    static let all: [Prefecture] = [
        .init(code: "01", name: "北海道", region: .hokkaido),
        .init(code: "02", name: "青森県", region: .tohoku),
        .init(code: "03", name: "岩手県", region: .tohoku),
        .init(code: "04", name: "宮城県", region: .tohoku),
        .init(code: "05", name: "秋田県", region: .tohoku),
        .init(code: "06", name: "山形県", region: .tohoku),
        .init(code: "07", name: "福島県", region: .tohoku),
        .init(code: "08", name: "茨城県", region: .kanto),
        .init(code: "09", name: "栃木県", region: .kanto),
        .init(code: "10", name: "群馬県", region: .kanto),
        .init(code: "11", name: "埼玉県", region: .kanto),
        .init(code: "12", name: "千葉県", region: .kanto),
        .init(code: "13", name: "東京都", region: .kanto),
        .init(code: "14", name: "神奈川県", region: .kanto),
        .init(code: "15", name: "新潟県", region: .chubu),
        .init(code: "16", name: "富山県", region: .chubu),
        .init(code: "17", name: "石川県", region: .chubu),
        .init(code: "18", name: "福井県", region: .chubu),
        .init(code: "19", name: "山梨県", region: .chubu),
        .init(code: "20", name: "長野県", region: .chubu),
        .init(code: "21", name: "岐阜県", region: .chubu),
        .init(code: "22", name: "静岡県", region: .chubu),
        .init(code: "23", name: "愛知県", region: .chubu),
        .init(code: "24", name: "三重県", region: .kinki),
        .init(code: "25", name: "滋賀県", region: .kinki),
        .init(code: "26", name: "京都府", region: .kinki),
        .init(code: "27", name: "大阪府", region: .kinki),
        .init(code: "28", name: "兵庫県", region: .kinki),
        .init(code: "29", name: "奈良県", region: .kinki),
        .init(code: "30", name: "和歌山県", region: .kinki),
        .init(code: "31", name: "鳥取県", region: .chugoku),
        .init(code: "32", name: "島根県", region: .chugoku),
        .init(code: "33", name: "岡山県", region: .chugoku),
        .init(code: "34", name: "広島県", region: .chugoku),
        .init(code: "35", name: "山口県", region: .chugoku),
        .init(code: "36", name: "徳島県", region: .shikoku),
        .init(code: "37", name: "香川県", region: .shikoku),
        .init(code: "38", name: "愛媛県", region: .shikoku),
        .init(code: "39", name: "高知県", region: .shikoku),
        .init(code: "40", name: "福岡県", region: .kyushu),
        .init(code: "41", name: "佐賀県", region: .kyushu),
        .init(code: "42", name: "長崎県", region: .kyushu),
        .init(code: "43", name: "熊本県", region: .kyushu),
        .init(code: "44", name: "大分県", region: .kyushu),
        .init(code: "45", name: "宮崎県", region: .kyushu),
        .init(code: "46", name: "鹿児島県", region: .kyushu),
        .init(code: "47", name: "沖縄県", region: .kyushu),
    ]

    static func find(byCode code: String?) -> Prefecture? {
        guard let code else { return nil }
        return all.first { $0.code == code }
    }

    /// 地方ごとにまとめた配列 (順序付き)
    static var grouped: [(region: Region, prefectures: [Prefecture])] {
        Region.allCases.map { region in
            (region, all.filter { $0.region == region })
        }
    }
}
