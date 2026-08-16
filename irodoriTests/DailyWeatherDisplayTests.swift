//
//  DailyWeatherDisplayTests.swift
//  irodoriTests
//
//  天気アイコン判定がウェザーニュースのアイコン体系
//  (https://weathernews.jp/s/topics/img/wxicon/) に沿うことの回帰テスト。
//  - 複合天気は「前半の天気がベース系統」(100/200/300/400 番台の思想)
//  - 特殊コード (霧・みぞれ・小雨・大雨/嵐・大雪/吹雪・猛暑・雷) は専用アイコン
//  - 使用する SF Symbols 名がすべて実在すること (typo すると無表示になるため)
//

import Foundation
import SwiftUI
import UIKit
import Testing
@testable import irodori

struct DailyWeatherDisplayTests {

    // MARK: - 前半ベースの複合マトリクス

    @Test("晴れベースの複合 (100番台)")
    func sunnyFamily() {
        #expect(DailyWeatherDisplay.style(for: "晴れ").iconName == "sun.max.fill")
        #expect(DailyWeatherDisplay.style(for: "晴れ時々くもり").iconName == "cloud.sun.fill")
        #expect(DailyWeatherDisplay.style(for: "晴れのち雨").iconName == "cloud.sun.rain.fill")
        #expect(DailyWeatherDisplay.style(for: "晴れ一時雪").iconName == "sun.snow")
    }

    @Test("くもりベースの複合 (200番台)")
    func cloudyFamily() {
        #expect(DailyWeatherDisplay.style(for: "くもり").iconName == "cloud.fill")
        #expect(DailyWeatherDisplay.style(for: "曇りのち晴れ").iconName == "cloud.sun.fill")
        #expect(DailyWeatherDisplay.style(for: "くもり時々雨").iconName == "cloud.rain.fill")
        #expect(DailyWeatherDisplay.style(for: "くもり一時雪").iconName == "cloud.snow.fill")
    }

    @Test("雨ベースの複合 (300番台)")
    func rainFamily() {
        #expect(DailyWeatherDisplay.style(for: "雨").iconName == "cloud.rain.fill")
        #expect(DailyWeatherDisplay.style(for: "雨のち晴れ").iconName == "cloud.sun.rain.fill")
        #expect(DailyWeatherDisplay.style(for: "雨のちくもり").iconName == "cloud.rain.fill")
        #expect(DailyWeatherDisplay.style(for: "雨時々雪").iconName == "cloud.sleet.fill")
    }

    @Test("雪ベースの複合 (400番台)")
    func snowFamily() {
        #expect(DailyWeatherDisplay.style(for: "雪").iconName == "cloud.snow.fill")
        #expect(DailyWeatherDisplay.style(for: "雪時々晴れ").iconName == "sun.snow")
        #expect(DailyWeatherDisplay.style(for: "雪のち雨").iconName == "cloud.sleet.fill")
    }

    @Test("前半ベースの向きはベース色で区別される (101 vs 201)")
    func directionIsEncodedInTint() {
        // 晴れ時々くもり (101) はオレンジ、くもり時々晴れ (201) はグレー
        let sunnyBase = DailyWeatherDisplay.style(for: "晴れ時々くもり")
        let cloudyBase = DailyWeatherDisplay.style(for: "くもり時々晴れ")
        #expect(sunnyBase.iconName == cloudyBase.iconName)   // グリフは同じ複合
        #expect(sunnyBase.tint == Color.orange)
        #expect(cloudyBase.tint == Color.gray)
    }

    // MARK: - 特殊コード (専用アイコン)

    @Test("特殊コードは専用アイコンへマップされる")
    func specialCodes() {
        #expect(DailyWeatherDisplay.style(for: "霧").iconName == "cloud.fog.fill")            // 200 霧
        #expect(DailyWeatherDisplay.style(for: "みぞれ").iconName == "cloud.sleet.fill")       // 430
        #expect(DailyWeatherDisplay.style(for: "小雨").iconName == "cloud.drizzle.fill")       // 650
        #expect(DailyWeatherDisplay.style(for: "大雨").iconName == "cloud.heavyrain.fill")     // 850
        #expect(DailyWeatherDisplay.style(for: "嵐").iconName == "tropicalstorm")              // 850 嵐
        #expect(DailyWeatherDisplay.style(for: "大雪").iconName == "snowflake")                // 950
        #expect(DailyWeatherDisplay.style(for: "吹雪").iconName == "wind.snow")                // 950 吹雪
        #expect(DailyWeatherDisplay.style(for: "猛暑").iconName == "thermometer.sun.fill")     // 550
        #expect(DailyWeatherDisplay.style(for: "雷を伴う雨").iconName == "cloud.bolt.rain.fill")
    }

    @Test("霧が副側に来る複合はくもり扱いで破綻しない")
    func fogAsSecondary() {
        #expect(DailyWeatherDisplay.style(for: "晴れのち霧").iconName == "cloud.sun.fill")
    }

    @Test("未知の文言はフォールバックする")
    func unknownFallsBack() {
        #expect(DailyWeatherDisplay.style(for: "不明").iconName == "cloud.sun.fill")
    }

    // MARK: - SF Symbols 実在チェック

    @Test("使用する SF Symbols 名がすべて実在する")
    func allSymbolsExist() {
        let conditions = [
            "晴れ", "晴れ時々くもり", "晴れのち雨", "晴れ一時雪",
            "くもり", "くもり時々晴れ", "くもり時々雨", "くもり一時雪",
            "雨", "雨のち晴れ", "雨のちくもり", "雨時々雪",
            "雪", "雪時々晴れ", "雪のちくもり", "雪のち雨",
            "霧", "みぞれ", "小雨", "霧雨", "大雨", "暴風雨", "嵐", "台風",
            "大雪", "吹雪", "暴風雪", "猛暑", "雷雨", "不明",
        ]
        for condition in conditions {
            let icon = DailyWeatherDisplay.style(for: condition).iconName
            #expect(UIImage(systemName: icon) != nil, "SF Symbol が見つからない: \(icon) (\(condition))")
        }
    }

    // MARK: - ウェザーニュースのアイコンコードと文言

    @Test("アイコンコード: 時々/一時 と のち(後) で番号が分かれる")
    func wxiconCodes() {
        #expect(DailyWeatherDisplay.style(for: "晴れ").wxiconCode == 100)
        #expect(DailyWeatherDisplay.style(for: "晴れ時々くもり").wxiconCode == 101)
        #expect(DailyWeatherDisplay.style(for: "晴れのちくもり").wxiconCode == 110)
        #expect(DailyWeatherDisplay.style(for: "晴れ 後 くもり").wxiconCode == 110)
        #expect(DailyWeatherDisplay.style(for: "くもり時々雨").wxiconCode == 202)
        #expect(DailyWeatherDisplay.style(for: "くもりのち雨").wxiconCode == 212)
        #expect(DailyWeatherDisplay.style(for: "雨時々止む").wxiconCode == 302)
        #expect(DailyWeatherDisplay.style(for: "雨のち晴れ").wxiconCode == 311)
        #expect(DailyWeatherDisplay.style(for: "雪のち雨").wxiconCode == 414)
        #expect(DailyWeatherDisplay.style(for: "みぞれ").wxiconCode == 430)
        #expect(DailyWeatherDisplay.style(for: "猛暑").wxiconCode == 550)
        #expect(DailyWeatherDisplay.style(for: "小雨").wxiconCode == 650)
        #expect(DailyWeatherDisplay.style(for: "大雨").wxiconCode == 850)
        #expect(DailyWeatherDisplay.style(for: "吹雪").wxiconCode == 950)
        #expect(DailyWeatherDisplay.style(for: "不明").wxiconCode == nil)
    }

    @Test("ポップアップ用の文言はウェザーニュースの表記になる")
    func wxLabelsMatchWeathernews() {
        #expect(DailyWeatherDisplay.style(for: "晴れ 後 一時 雨").label == "晴れのち雨")
        #expect(DailyWeatherDisplay.style(for: "くもり時々雪").label == "くもり時々雪")
        #expect(DailyWeatherDisplay.style(for: "霧").label == "霧")
        #expect(DailyWeatherDisplay.style(for: "雷を伴う雨").label == "雷雨")
        #expect(DailyWeatherDisplay.style(for: "大雨").label == "大雨・嵐")
        #expect(DailyWeatherDisplay.style(for: "不明").label == nil)
    }

    @Test("全コードのウェザーニュースアイコンアセットがカタログに存在する")
    func wxAssetsExist() {
        let codes = [
            100, 101, 102, 104, 110, 112, 115,
            200, 201, 202, 204, 210, 212, 215,
            300, 301, 302, 303, 311, 313, 314,
            400, 401, 402, 403, 411, 413, 414,
            430, 550, 650, 850, 950,
        ]
        for code in codes {
            #expect(UIImage(named: "wx\(code)") != nil, "wxicon アセットが無い: wx\(code)")
        }
    }

    // MARK: - 説明文の短縮 (compactCondition)

    @Test("特殊系の語も説明文から欠落しない")
    func compactKeepsSpecialTerms() {
        #expect(DailyWeatherDisplay.compactCondition("霧") == "霧")
        #expect(DailyWeatherDisplay.compactCondition("小雨") == "小雨")
        #expect(DailyWeatherDisplay.compactCondition("雨 時々 止む") == "雨時々止む")
        #expect(DailyWeatherDisplay.compactCondition("くもり 一時 吹雪") == "くもり一時吹雪")
    }

    @Test("気象庁の長文は主要語だけに短縮される (既存仕様の回帰)")
    func compactShortensLongJMAText() {
        #expect(
            DailyWeatherDisplay.compactCondition("晴れ 後 くもり 夜 雨 所により 昼過ぎ から 雷") == "晴れ後くもり雨"
        )
    }
}
