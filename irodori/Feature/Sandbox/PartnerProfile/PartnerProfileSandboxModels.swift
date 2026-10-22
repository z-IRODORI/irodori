//
//  PartnerProfileSandboxModels.swift
//  irodori - Sandbox
//
//  相棒画面の改善候補 (あなたの特徴 + ミッション制の理解度) で共有するモデルとモック。
//  レスポンスは GET /api/partner/{user_id}/profile の案 (PartnerProfileResponseDraft) と同じ形にしてある。
//  モックの数字はテストアカウントの実データ (服21点・黒白グレー14点・無地24/29 など) を元にしたサンプル。
//

import SwiftUI

// MARK: - レスポンス案

/// GET /api/partner/{user_id}/profile の案
struct PartnerProfileResponseDraft: Codable {
    let status: String
    let understanding: Understanding
    /// 相棒が一文でまとめたあなた (Gemini で1日1回だけ作る。ほかは集計だけで出す)
    let summary: String
    let traits: [Trait]
    /// 相棒の発見 (日記・カード・ストーリーの1件)。新しい順
    let discoveries: [Discovery]
    let missions: [Mission]
    let unlocks: [Unlock]
    /// 前回見たあとにクリアしたミッション (お祝いの表示に使う)
    let recently_cleared: [String]

    struct Understanding: Codable {
        let pct: Int
        let stage: Stage
        let next_stage: Stage?
        /// 次のステージまでに残っているミッションの数
        let remaining_in_stage: Int
    }

    struct Stage: Codable, Hashable {
        let index: Int          // 1...5
        let name: String        // 「かおみしり」など
        let at_pct: Int         // このステージに入る理解度
    }

    struct Trait: Codable, Identifiable, Hashable {
        let id: String          // color_like / pattern / hero ...
        let group: String       // color | style | habit | closet
        let title: String       // 「好きな色」
        let value: String?      // 「黒・白・グレー」 (locked のときは nil)
        let detail: String?     // 相棒のひとこと
        let confidence: String  // low | mid | high
        let status: String      // guess | confirmed | corrected | locked
        let evidence: [Evidence]
        let swatches: [String]? // 色の特徴だけ。#RRGGBB
        let meter: Meter?       // 2択の傾き (カジュアル ↔ きれいめ など)
        let unlock_hint: String? // locked のときの条件 (「あと2日『着る』を決めるとわかる」)
    }

    struct Discovery: Codable, Identifiable, Hashable {
        let id: String
        let date: String            // 2026-10-22
        let hue: String             // pink | sky | lemon | mint | lilac | peach
        let rarity: String          // normal | surprise | rare
        let headline: String?       // locked のときは nil
        let body: String?
        let viz: Viz?
        let dig: Dig?
        let unlock_at: Int
        let teaser: String          // まだのときの予告
        let status: String          // locked | new | read | answered
    }

    struct Viz: Codable, Hashable {
        let type: String            // color_share | weekday | compare | garments
        let labels: [String]
        let values: [Double]
        let unit: String?
        let item_ids: [String]?     // garments のときは手持ちの服 id (画像はクローゼットから)
    }

    struct Dig: Codable, Hashable {
        let question: String
        let options: [String]
        let answer: String?         // 返事済みなら選んだ答え
        let reply: String?          // 相棒の返事 (答えに応じて生成)
    }

    struct Evidence: Codable, Hashable {
        let kind: String        // closet | decided | feedback | pivot | calendar | photo | onboarding
        let text: String
    }

    struct Meter: Codable, Hashable {
        let left: String
        let right: String
        let value: Double       // 0 = left, 1 = right
    }

    struct Mission: Codable, Identifiable, Hashable {
        let id: String
        let stage: Int
        let title: String
        let points: Int
        let current: Int
        let target: Int
        let done: Bool
        let done_at: String?
        /// タップしたときの行き先 (open_home / open_closet / open_camera / open_calendar / check_traits)
        let action: String
    }

    struct Unlock: Codable, Hashable {
        let at_pct: Int
        let label: String
        let unlocked: Bool
    }
}

// MARK: - ステージとミッションの定義

/// 理解度はミッションの点数の合計 (満点 100)。
/// 目安: 1日目で 25〜30%、2日目で 45%、3〜5日目で 60% 前後。そこから先は 1〜3週間で 80%、1〜2か月で 100%。
enum PartnerMissionCatalog {
    struct Def: Identifiable, Hashable {
        let id: String
        let stage: Int
        let title: String
        let hint: String
        let points: Int
        let target: Int
        let action: String
        let icon: String
    }

    static let stages: [PartnerProfileResponseDraft.Stage] = [
        .init(index: 1, name: "はじめまして", at_pct: 0),
        .init(index: 2, name: "かおみしり", at_pct: 25),
        .init(index: 3, name: "ともだち", at_pct: 45),
        .init(index: 4, name: "しんゆう", at_pct: 62),
        .init(index: 5, name: "あいぼう", at_pct: 82),
    ]

    /// ステージごとの目安の日数 (表示用)
    static let stageDays: [Int: String] = [
        1: "1日目", 2: "2〜3日目", 3: "3〜5日目", 4: "1〜3週間", 5: "1〜2か月",
    ]

    static let all: [Def] = [
        // ステージ1 はじめまして (1日目) 計25
        .init(id: "onboarding", stage: 1, title: "4つの質問にこたえる", hint: "なりたい印象や話し方を教える", points: 6, target: 1, action: "open_onboarding", icon: "questionmark.bubble"),
        .init(id: "closet_5", stage: 1, title: "服を5点おぼえさせる", hint: "写真からまとめて登録できる", points: 6, target: 5, action: "open_closet", icon: "tshirt"),
        .init(id: "first_view", stage: 1, title: "はじめての3案を見る", hint: "ホームを開くだけ", points: 3, target: 1, action: "open_home", icon: "rectangle.stack"),
        .init(id: "first_react", stage: 1, title: "3案のどれかに反応する", hint: "いいね／ちょっと違う", points: 4, target: 1, action: "open_home", icon: "hand.thumbsup"),
        .init(id: "first_decide", stage: 1, title: "1案を「着る」と決める", hint: "明日着る、でもOK", points: 6, target: 1, action: "open_home", icon: "checkmark.circle"),
        // ステージ2 かおみしり (2〜3日目) 計20
        .init(id: "return_day2", stage: 2, title: "2日目も会いに来る", hint: "連続でなくてもOK", points: 4, target: 2, action: "open_home", icon: "sun.max"),
        .init(id: "closet_10", stage: 2, title: "服を10点おぼえさせる", hint: "トップス・ボトムス・靴がそろうと提案が広がる", points: 5, target: 10, action: "open_closet", icon: "square.grid.2x2"),
        .init(id: "pivot", stage: 2, title: "主役の服を選んで組む", hint: "着たい服から3案を作り直す", points: 4, target: 1, action: "open_home", icon: "star"),
        .init(id: "react_3", stage: 2, title: "3案への反応を3回", hint: "いいね／ちょっと違うの合計", points: 3, target: 3, action: "open_home", icon: "hand.thumbsup"),
        .init(id: "trait_check_2", stage: 2, title: "相棒の発見に2回返事する", hint: "日記やカードの問いかけに答える", points: 4, target: 2, action: "check_traits", icon: "checklist"),
        // ステージ3 ともだち (3〜5日目) 計17
        .init(id: "login_3", stage: 3, title: "3日会いに来る", hint: "連続でなくてもOK", points: 4, target: 3, action: "open_home", icon: "calendar"),
        .init(id: "decide_3", stage: 3, title: "3日分「着る」と決める", hint: "決めた日はカレンダーに残る", points: 5, target: 3, action: "open_home", icon: "checkmark.seal"),
        .init(id: "photo_1", stage: 3, title: "着た日の全身写真を1枚撮る", hint: "実際に着た服がいちばんの手がかり", points: 5, target: 1, action: "open_camera", icon: "camera"),
        .init(id: "reason_1", stage: 3, title: "ピンとこない理由を1回教える", hint: "色・系統・気温など", points: 3, target: 1, action: "open_home", icon: "text.bubble"),
        // ステージ4 しんゆう (1〜3週間) 計20
        .init(id: "login_7", stage: 4, title: "7日会いに来る", hint: "連続でなくてもOK", points: 5, target: 7, action: "open_home", icon: "calendar.badge.clock"),
        .init(id: "decide_7", stage: 4, title: "7日分「着る」と決める", hint: "1週間分の癖が見えてくる", points: 5, target: 7, action: "open_home", icon: "checkmark.seal"),
        .init(id: "closet_20", stage: 4, title: "服を20点おぼえさせる", hint: "アウターや小物も", points: 4, target: 20, action: "open_closet", icon: "cabinet"),
        .init(id: "photo_3", stage: 4, title: "全身写真を3枚撮る", hint: "", points: 3, target: 3, action: "open_camera", icon: "camera.on.rectangle"),
        .init(id: "trait_check_all", stage: 4, title: "相棒の発見に8回返事する", hint: "返事するほど提案が変わる", points: 3, target: 8, action: "check_traits", icon: "checklist.checked"),
        // ステージ5 あいぼう (1〜2か月) 計18
        .init(id: "login_20", stage: 5, title: "20日会いに来る", hint: "", points: 6, target: 20, action: "open_home", icon: "heart"),
        .init(id: "season", stage: 5, title: "季節の変わり目をいっしょに越える", hint: "気温帯が2つ以上の日に「着る」を決める", points: 5, target: 2, action: "open_home", icon: "leaf"),
        .init(id: "calendar_10", stage: 5, title: "ひと月に10日カレンダーに残す", hint: "", points: 4, target: 10, action: "open_calendar", icon: "calendar.day.timeline.left"),
        .init(id: "revive_3", stage: 5, title: "眠っている服を3着もう一度着る", hint: "30日出番がない服", points: 3, target: 3, action: "open_home", icon: "arrow.uturn.backward"),
    ]

    /// ステージに入るとできるようになること (stages と同じ並び・同じ%)
    static let unlocks: [(Int, String)] = [
        (0, "手持ちの服から毎日3案"),
        (25, "好きな色・柄・系統がわかる"),
        (45, "着こなしの癖 (主役・決め方・体感) がわかる"),
        (62, "1週間先まで予定コーデを組める"),
        (82, "季節の変わり目の先回りと、月のふりかえり"),
    ]

    static func stage(for pct: Int) -> PartnerProfileResponseDraft.Stage {
        stages.last(where: { pct >= $0.at_pct }) ?? stages[0]
    }

    static func nextStage(for pct: Int) -> PartnerProfileResponseDraft.Stage? {
        stages.first(where: { pct < $0.at_pct })
    }
}

// MARK: - 特徴の候補

/// 相棒が出せる特徴の候補。どのデータから・どれくらい貯まったら出せるかを持つ。
/// 計算は集計だけで済ませ (Gemini 不要)、ひとことの言い回しだけ相棒の話し方に寄せる。
struct PartnerTraitMock: Identifiable, Hashable {
    enum Group: String, CaseIterable {
        case color = "色"
        case style = "系統・形"
        case habit = "癖"
        case closet = "クローゼット"
    }

    let id: String
    let group: Group
    let icon: String
    let title: String
    let value: String
    let detail: String
    let evidence: [String]
    var swatches: [Color] = []
    var meter: (left: String, right: String, value: Double)? = nil
    /// この理解度に届くと見えるようになる
    let unlockAt: Int
    let unlockHint: String
    /// 1 = 見立て, 2 = たぶん, 3 = わかった
    var confidence: Int

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var confidenceLabel: String {
        switch confidence {
        case 3: return "わかった"
        case 2: return "たぶん"
        default: return "見立て"
        }
    }
}

enum PartnerTraitCatalog {
    static let all: [PartnerTraitMock] = [
        .init(id: "color_like", group: .color, icon: "paintpalette", title: "好きな色",
              value: "黒・白・グレー", detail: "モノトーンが落ち着くタイプ。差し色は小物で少しだけ、がちょうどいいみたい。",
              evidence: ["クローゼット21点のうち14点がモノトーン", "「着る」と決めた3案すべてに黒が入っていた"],
              swatches: [Color(white: 0.07), .white, Color(white: 0.62)],
              unlockAt: 15, unlockHint: "服を5点おぼえるとわかる", confidence: 3),
        .init(id: "color_avoid", group: .color, icon: "eye.slash", title: "避けがちな色",
              value: "オレンジ・赤の主役", detail: "明るい色が真ん中に来る案は見送りが多め。小さく入るだけなら大丈夫かも。",
              evidence: ["「色が好みじゃない」で3回見送り", "オレンジのアウターは登録後まだ出番なし"],
              swatches: [Color(red: 0.95, green: 0.5, blue: 0.15), Color(red: 0.85, green: 0.15, blue: 0.2)],
              unlockAt: 30, unlockHint: "ピンとこない理由を1回教えるとわかる", confidence: 2),
        .init(id: "pattern", group: .style, icon: "square.grid.3x3", title: "柄の好み",
              value: "無地派", detail: "柄はロゴやワンポイントくらいまで。形と素材で変化をつけるのが上手。",
              evidence: ["29点のうち24点が無地", "ロゴ3点・ボーダー1点"],
              unlockAt: 15, unlockHint: "服を5点おぼえるとわかる", confidence: 3),
        .init(id: "taste", group: .style, icon: "sparkles", title: "系統",
              value: "カジュアル寄りのミニマル", detail: "スポーティな要素をちょっと混ぜるのがあなたらしさ。",
              evidence: ["カジュアル22・ミニマル15・クラシック9・スポーティ8 (服のタグ)", "4つの質問で「着心地」を大事にすると回答"],
              meter: ("カジュアル", "きれいめ", 0.28),
              unlockAt: 20, unlockHint: "服を10点おぼえるとわかる", confidence: 2),
        .init(id: "silhouette", group: .style, icon: "figure.stand", title: "シルエット",
              value: "ジャストサイズが基本", detail: "ゆったりは上か下のどちらか1点だけ。全身ゆるくはしない派。",
              evidence: ["レギュラー18点・リラックス3点・オーバー2点"],
              meter: ("ジャスト", "ゆったり", 0.25),
              unlockAt: 25, unlockHint: "服を10点おぼえるとわかる", confidence: 2),
        .init(id: "hero", group: .habit, icon: "star", title: "主役にしがちな服",
              value: "ブルーのジーンズ", detail: "迷ったらまずジーンズから組む。上を替えて表情を変えるタイプ。",
              evidence: ["主役に選んだ5回のうち3回がジーンズ"],
              unlockAt: 40, unlockHint: "主役の服を選んで組むとわかる", confidence: 1),
        .init(id: "decision", group: .habit, icon: "timer", title: "決め方",
              value: "3案から即決派", detail: "開いてから1分以内に決める日が多い。朝は時間をかけたくないのかも。",
              evidence: ["「着る」を決めた3日の平均 48秒", "作り直しは1回だけ"],
              unlockAt: 45, unlockHint: "3日分「着る」を決めるとわかる", confidence: 1),
        .init(id: "temperature", group: .habit, icon: "thermometer.medium", title: "体感",
              value: "ちょっと寒がり", detail: "最高20℃の日でも長袖を選んでる。肌寒い日は早めに羽織りを足すね。",
              evidence: ["最高20〜22℃の日に長袖を選んだ 3/3回"],
              unlockAt: 50, unlockHint: "気温のちがう日に3回「着る」を決めるとわかる", confidence: 1),
        .init(id: "weekday", group: .habit, icon: "calendar", title: "曜日の癖",
              value: "平日きれいめ・休日ラク", detail: "月〜金はシャツやチノ、土日はスウェットやパーカーが多い。",
              evidence: ["平日に決めた4日のうち3日がシャツ／チノ", "休日2日はどちらもパーカー"],
              unlockAt: 62, unlockHint: "7日分「着る」を決めるとわかる", confidence: 1),
        .init(id: "repeat", group: .habit, icon: "arrow.triangle.2.circlepath", title: "着回しの間隔",
              value: "同じトップスは中3日あける", detail: "続けて着るのは避けたい派。ボトムスは気にしないみたい。",
              evidence: ["カレンダー10日分で、同じトップスの間隔は平均4日"],
              unlockAt: 70, unlockHint: "カレンダーに10日残すとわかる", confidence: 1),
        .init(id: "adventure", group: .habit, icon: "dice", title: "冒険度",
              value: "安心派 (ときどき挑戦)", detail: "見慣れない組み合わせは5回に1回くらい採用。週末なら冒険しやすいかも。",
              evidence: ["新しい組み合わせの採用 1/5回"],
              meter: ("いつもの", "新しい", 0.2),
              unlockAt: 55, unlockHint: "3案への反応を5回するとわかる", confidence: 1),
        .init(id: "closet_gap", group: .closet, icon: "chart.bar", title: "クローゼットの偏り",
              value: "トップス多め・羽織り少なめ", detail: "トップス9点にアウター3点。これから寒くなるから、羽織りが1着あると組み方が倍に増えるよ。",
              evidence: ["トップス9・ボトムス6・アウター3・靴2・バッグ0"],
              unlockAt: 20, unlockHint: "服を10点おぼえるとわかる", confidence: 3),
        .init(id: "first_string", group: .closet, icon: "crown", title: "一軍の服",
              value: "白のシャツ", detail: "決めたコーデの半分に入ってる。きれいめにもカジュアルにも振れる万能選手。",
              evidence: ["「着る」と決めた6日のうち3日"],
              unlockAt: 50, unlockHint: "5日分「着る」を決めるとわかる", confidence: 2),
        .init(id: "sleeping", group: .closet, icon: "moon.zzz", title: "眠っている服",
              value: "レッドのTシャツほか2点", detail: "30日出番なし。黒のパンツと合わせれば色が浮きにくいよ。",
              evidence: ["登録から30日以上、提案でも決めたコーデでも未使用"],
              unlockAt: 75, unlockHint: "登録から30日たつとわかる", confidence: 2),
    ]
}

// MARK: - Sandbox 用の状態 (ミッションをタップしてクリア/戻すと理解度が動く)

@Observable
final class PartnerProfileSandboxStore {
    /// ミッションごとの進み (current)。プリセットで切り替えられる
    var progress: [String: Int] = [:]
    /// 答え合わせした特徴 (id -> true=合ってる / false=ちょっと違う)
    var verdicts: [String: Bool] = [:]
    var lastCleared: PartnerMissionCatalog.Def?

    enum Preset: String, CaseIterable, Identifiable {
        case day1 = "1日目"
        case day3 = "3日目"
        case day5 = "5日目"
        case week3 = "3週間"
        var id: String { rawValue }
    }

    init(preset: Preset = .day3) { apply(preset) }

    func apply(_ preset: Preset) {
        var p: [String: Int] = [:]
        func set(_ id: String, _ v: Int) { p[id] = v }
        // 1日目: 質問・登録・3案・反応・決定まで
        set("onboarding", 1); set("closet_5", 5); set("first_view", 1); set("first_react", 1); set("first_decide", 1)
        set("closet_10", 8); set("react_3", 1); set("return_day2", 1); set("login_3", 1); set("decide_3", 1); set("login_7", 1); set("decide_7", 1); set("closet_20", 8); set("login_20", 1)
        if preset != .day1 {
            set("return_day2", 2); set("closet_10", 10); set("pivot", 1); set("react_3", 3); set("trait_check_2", 2)
            set("login_3", 3); set("decide_3", 2); set("reason_1", 1); set("login_7", 3); set("decide_7", 2); set("closet_20", 12); set("login_20", 3)
        }
        if preset == .day5 || preset == .week3 {
            set("decide_3", 3); set("photo_1", 1)
            set("login_7", 5); set("decide_7", 4); set("closet_20", 14); set("photo_3", 1); set("trait_check_all", 3); set("login_20", 5)
        }
        if preset == .week3 {
            set("login_7", 7); set("decide_7", 7); set("closet_20", 21); set("photo_3", 3); set("trait_check_all", 8)
            set("login_20", 14); set("season", 1); set("calendar_10", 7); set("revive_3", 1)
        }
        progress = p
        verdicts = preset == .day1 ? [:] : ["color_like": true, "pattern": true]
        lastCleared = nil
    }

    func current(_ m: PartnerMissionCatalog.Def) -> Int { min(m.target, progress[m.id] ?? 0) }
    func isDone(_ m: PartnerMissionCatalog.Def) -> Bool { current(m) >= m.target }

    var pct: Int {
        min(100, PartnerMissionCatalog.all.filter(isDone).reduce(0) { $0 + $1.points })
    }

    var stage: PartnerProfileResponseDraft.Stage { PartnerMissionCatalog.stage(for: pct) }
    var nextStage: PartnerProfileResponseDraft.Stage? { PartnerMissionCatalog.nextStage(for: pct) }

    /// 今のステージで残っているミッション (なければ次のステージ)
    var activeMissions: [PartnerMissionCatalog.Def] {
        let open = PartnerMissionCatalog.all.filter { !isDone($0) }
        guard let first = open.first else { return [] }
        return open.filter { $0.stage == first.stage }
    }

    func missions(stage: Int) -> [PartnerMissionCatalog.Def] {
        PartnerMissionCatalog.all.filter { $0.stage == stage }
    }

    /// Sandbox ではタップで 1 進める (クリア済みならリセット)
    func tap(_ m: PartnerMissionCatalog.Def) {
        if isDone(m) {
            progress[m.id] = 0
        } else {
            progress[m.id] = current(m) + 1
            if isDone(m) { lastCleared = m }
        }
    }

    func traits(unlocked: Bool) -> [PartnerTraitMock] {
        PartnerTraitCatalog.all.filter { (pct >= $0.unlockAt) == unlocked }
    }

    func verdict(_ t: PartnerTraitMock, agree: Bool) {
        verdicts[t.id] = agree
        // 答え合わせはミッションにも数える
        let count = verdicts.count
        progress["trait_check_2"] = min(2, count)
        progress["trait_check_all"] = min(8, count)
    }

    /// 答え合わせの結果を反映した確からしさ
    func confidence(_ t: PartnerTraitMock) -> Int {
        if verdicts[t.id] == true { return 3 }
        return t.confidence
    }

    var summary: String {
        if pct < 15 { return "まだ会ったばかり。服をおぼえるほど、あなたのことを話せるようになるよ。" }
        if pct < 40 { return "モノトーンで無地、ジャストサイズ。シンプルに整えるのが好きな人だと思ってる。" }
        return "モノトーンを軸に、ジャストサイズのカジュアルを着回すタイプ。色ものはまだ慎重派で、迷ったらジーンズから組む。"
    }
}

// MARK: - 共通の小物

struct PartnerProfileSwatches: View {
    let colors: [Color]
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                Circle().fill(c)
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
            }
        }
    }
}

struct PartnerProfileMeter: View {
    let left: String
    let right: String
    let value: Double
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(RenewalTokens.rule).frame(height: 4)
                    Circle().fill(RenewalTokens.ink)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, min(geo.size.width - 10, geo.size.width * value - 5)))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 10)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(.system(size: 10))
            .foregroundStyle(RenewalTokens.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left)と\(right)のあいだで、\(value < 0.5 ? left : right)寄り")
    }
}

struct PartnerProfileConfidenceDots: View {
    let level: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= level ? RenewalTokens.ink : RenewalTokens.border)
                    .frame(width: 8, height: 3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// クリアしたときのトースト
struct PartnerMissionClearedToast: View {
    let mission: PartnerMissionCatalog.Def
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(RenewalTokens.accentPink)
            VStack(alignment: .leading, spacing: 2) {
                Text("ミッションクリア ＋\(mission.points)%")
                    .font(.system(size: 13, weight: .bold))
                Text(mission.title)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .renewalCard()
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }
}
