//
//  ItemCategory.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation

enum ItemCategory: Hashable, Equatable {
    case outer(OuterType)
    case tops(TopsType)
    case bottoms(BottomsType)
    case shoes(ShoesType)
    case accessories(AccessoryType)
    case unknown

    // アウターのサブタイプ
    enum OuterType {
        case coat
        case jacket
        case hoodie
        case vest
        case down
        case militaryCoat
        case other

        var iconName: String {
            switch self {
            case .coat: return "wind.snow"
            case .jacket: return "figure.outdoor.cycle"
            case .hoodie: return "wind"
            case .vest: return "tshirt.fill"
            case .down: return "snowflake"
            case .militaryCoat: return "wind.snow"
            case .other: return "wind.snow"
            }
        }
    }

    // トップスのサブタイプ
    enum TopsType {
        case tshirt
        case shirt
        case knit
        case sweater
        case other

        var iconName: String {
            switch self {
            case .tshirt: return "tshirt"
            case .shirt: return "tshirt"
            case .knit: return "tshirt.fill"
            case .sweater: return "tshirt.fill"
            case .other: return "tshirt"
            }
        }
    }

    // ボトムスのサブタイプ
    enum BottomsType {
        case pants
        case jeans
        case widePants
        case shorts
        case skirt
        case sweatPants
        case other

        var iconName: String {
            switch self {
            case .pants: return "figure.dress.line.vertical.figure"
            case .jeans: return "figure.dress.line.vertical.figure"
            case .widePants: return "figure.dress.line.vertical.figure"
            case .shorts: return "figure.walk"
            case .skirt: return "figure.dress.line.vertical.figure"
            case .sweatPants: return "figure.cooldown"
            case .other: return "figure.dress.line.vertical.figure"
            }
        }
    }

    // シューズのサブタイプ
    enum ShoesType {
        case sneakers
        case sandals
        case boots
        case loafers
        case platformShoes
        case other

        var iconName: String {
            switch self {
            case .sneakers: return "shoe.2"
            case .sandals: return "shoe.2.fill"
            case .boots: return "shoe.2"
            case .loafers: return "shoe.2"
            case .platformShoes: return "shoe.2.fill"
            case .other: return "shoe.2"
            }
        }
    }

    // アクセサリーのサブタイプ
    enum AccessoryType {
        case bag
        case handbag
        case shoulderBag
        case hat
        case glasses
        case sunglasses
        case watch
        case necklace
        case keychain
        case other

        var iconName: String {
            switch self {
            case .bag: return "bag"
            case .handbag: return "handbag"
            case .shoulderBag: return "bag.fill"
            case .hat: return "hat"
            case .glasses: return "eyeglasses"
            case .sunglasses: return "sunglasses"
            case .watch: return "applewatch"
            case .necklace: return "circlebadge.2"
            case .keychain: return "key.horizontal"
            case .other: return "bag"
            }
        }
    }

    // カテゴリ文字列から判定
    init(from categoryString: String) {
        let components = categoryString.split(separator: "_").map { String($0) }
        guard !components.isEmpty else {
            self = .unknown
            return
        }

        let mainCategory = components[0]
        let subCategory = components.count > 1 ? components[1] : ""

        switch mainCategory {
        case "アウター":
            self = .outer(Self.parseOuterType(subCategory))
        case "トップス":
            self = .tops(Self.parseTopsType(subCategory))
        case "ボトムス":
            self = .bottoms(Self.parseBottomsType(subCategory))
        case "シューズ":
            self = .shoes(Self.parseShoesType(subCategory))
        case "アクセサリー":
            self = .accessories(Self.parseAccessoryType(subCategory))
        default:
            self = .unknown
        }
    }

    // アイコン名を返す
    var iconName: String {
        switch self {
        case .outer(let type): return type.iconName
        case .tops(let type): return type.iconName
        case .bottoms(let type): return type.iconName
        case .shoes(let type): return type.iconName
        case .accessories(let type): return type.iconName
        case .unknown: return "questionmark.circle"
        }
    }

    // サブカテゴリの判定メソッド
    private static func parseOuterType(_ subCategory: String) -> OuterType {
        switch subCategory {
        case let s where s.contains("コート"): return .coat
        case let s where s.contains("ミリタリーコート"): return .militaryCoat
        case let s where s.contains("ジャケット"): return .jacket
        case let s where s.contains("パーカー"): return .hoodie
        case let s where s.contains("ベスト"): return .vest
        case let s where s.contains("ダウン"): return .down
        default: return .other
        }
    }

    private static func parseTopsType(_ subCategory: String) -> TopsType {
        switch subCategory {
        case let s where s.contains("Tシャツ"): return .tshirt
        case let s where s.contains("シャツ"): return .shirt
        case let s where s.contains("ニット"): return .knit
        case let s where s.contains("セーター"): return .sweater
        default: return .other
        }
    }

    private static func parseBottomsType(_ subCategory: String) -> BottomsType {
        switch subCategory {
        case let s where s.contains("ジーンズ"): return .jeans
        case let s where s.contains("ワイドパンツ"): return .widePants
        case let s where s.contains("ショート"): return .shorts
        case let s where s.contains("スカート"): return .skirt
        case let s where s.contains("スウェットパンツ"): return .sweatPants
        case let s where s.contains("パンツ"): return .pants
        default: return .other
        }
    }

    private static func parseShoesType(_ subCategory: String) -> ShoesType {
        switch subCategory {
        case let s where s.contains("スニーカー"): return .sneakers
        case let s where s.contains("サンダル"): return .sandals
        case let s where s.contains("ブーツ"): return .boots
        case let s where s.contains("ローファー"): return .loafers
        case let s where s.contains("厚底"): return .platformShoes
        default: return .other
        }
    }

    private static func parseAccessoryType(_ subCategory: String) -> AccessoryType {
        switch subCategory {
        case let s where s.contains("ハンドバッグ"): return .handbag
        case let s where s.contains("ショルダーバッグ"): return .shoulderBag
        case let s where s.contains("バッグ"): return .bag
        case let s where s.contains("帽子"): return .hat
        case let s where s.contains("サングラス"): return .sunglasses
        case let s where s.contains("メガネ"): return .glasses
        case let s where s.contains("腕時計"): return .watch
        case let s where s.contains("ネックレス"): return .necklace
        case let s where s.contains("キーホルダー"): return .keychain
        default: return .other
        }
    }
}
