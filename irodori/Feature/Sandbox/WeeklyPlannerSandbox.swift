//
//  WeeklyPlannerSandbox.swift
//  irodori - Sandbox
//
//  週間コーデプランナー計画書 (週間コーデプランナー計画_weekly-planner-vision.md) の
//  Now スコープを「実API接続」で確認するための検証画面。
//
//  この画面でできること:
//   1. 実API (POST /api/recommendation/plan) を叩き、計画書 §7 の追加予定フィールドが
//      実際に届いているかを診断パネルで一覧確認する (未着は「サーバ未実装」と表示)
//   2. 実データのまま体験フローを通す:
//      配り演出(§1-2) → 開封リビール(§1-1) → 対照的3択(§2-2) → 栞(§1-3)
//   3. サーバ未実装ぶんは端末内テンプレ(§3-4 フォールバック)で埋めて体験を評価し、
//      「モック(実装後)」と見比べて実装後の姿とのギャップを確認する
//
//  非破壊: この画面は書き込みAPIを一切呼ばない。
//  カレンダー保存 (calendar_outfits) もフィードバック送信も行わないため、
//  本番の Firestore データには影響しない (栞は演出のみのドライラン)。
//

import SwiftUI
import Kingfisher

// MARK: - レスポンス (計画書 §7 の追加予定フィールドを含む superset)

/// 本命 / 入替候補の1件。
/// 本体は本番モデル (`DailyRecommendationItem`) でデコードして本番の契約互換も同時に確認し、
/// 計画書 §2-2 / §7 で追加予定のフィールドは Optional で受ける (未実装なら nil)。
struct WPSPlanCandidate: Decodable, Identifiable {
    let item: DailyRecommendationItem
    let alt_tag: String?              // §2-2 対照的3択のラベル (steady / challenge / change)
    let applied_signals: [String]?    // §7 反映したシグナル

    var id: String { item.id }

    private enum CodingKeys: String, CodingKey {
        case alt_tag, applied_signals
    }

    init(from decoder: Decoder) throws {
        self.item = try DailyRecommendationItem(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.alt_tag = try? c.decode(String.self, forKey: .alt_tag)
        self.applied_signals = try? c.decode([String].self, forKey: .applied_signals)
    }

    init(item: DailyRecommendationItem, alt_tag: String? = nil, applied_signals: [String]? = nil) {
        self.item = item
        self.alt_tag = alt_tag
        self.applied_signals = applied_signals
    }
}

struct WPSPlanDay: Decodable, Identifiable {
    let date: String                        // YYYY-MM-DD
    let weather: DailyRecommendationWeather?
    let item: WPSPlanCandidate              // 本命
    let alternates: [WPSPlanCandidate]      // 入替候補 (現状は最大3)
    let day_line: String?                   // §7 日別ノート (週ナラティブの day_lines)

    var id: String { date }

    /// 候補の並び (本命 + 入替候補)。3択シートと入替の実体はこの配列のインデックス
    var candidates: [WPSPlanCandidate] { [item] + alternates }
}

struct WPSPlanResponse: Decodable {
    let status: String
    let days: [WPSPlanDay]
    // 以下すべて §7 の追加予定フィールド (現行サーバは返さないので nil)
    let week_title: String?               // §3-1 週テーマ
    let week_comment: String?             // §3-1 週の宣言
    let plan_ack: String?                 // §5-2 「先週の声、今週こう変えた」
    let signal_count: Int?                // §3-5 根拠バッジ
    let signal_caption: String?           // §3-5
    let speaking_style: String?           // §7 相棒の話し方
}

// MARK: - APIクライアント

struct WPSPlanFailure: Error {
    let message: String
    /// 失敗時のレスポンス本文 (先頭のみ)。デコード失敗の原因追跡用
    let bodySnippet: String?
}

protocol WPSPlanClientProtocol {
    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String,
        prefectureCode: String?,
        candidatesPerDay: Int?,
        regenToken: Int?
    ) async -> Result<WPSPlanResponse, WPSPlanFailure>
}

/// 実API。baseURL を差し替えて本番(Render) / ローカル(uvicorn) を切り替える。
struct WPSLivePlanClient: WPSPlanClientProtocol {
    let baseURL: String

    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String,
        prefectureCode: String?,
        candidatesPerDay: Int?,
        regenToken: Int?
    ) async -> Result<WPSPlanResponse, WPSPlanFailure> {
        guard var components = URLComponents(string: "\(baseURL)/api/recommendation/plan") else {
            return .failure(.init(message: "URLが不正です: \(baseURL)", bodySnippet: nil))
        }
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.init(message: "URLを組み立てられませんでした", bodySnippet: nil))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180   // 日数ぶん直列生成するため長め (§0 の構造的制約)

        var body: [String: Any] = [
            "gender": gender.apiValue,
            "days": days,
            "start_date": startDate,
        ]
        if let prefectureCode, !prefectureCode.isEmpty {
            body["prefecture_code"] = prefectureCode
        }
        // §2-2: 1日あたりの候補数 (本命含む)。未対応サーバは未知フィールドとして無視し、
        // 従来どおり本命1+入替3 を返す (診断パネルで要求値との差が分かる)
        if let candidatesPerDay {
            body["candidates_per_day"] = candidatesPerDay
        }
        // §2-5: 未実装サーバは未知フィールドとして無視する (旧挙動を壊さないことの確認も兼ねる)
        if let regenToken {
            body["regen_token"] = regenToken
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            let snippet = String(data: data.prefix(700), encoding: .utf8)
            if let http = urlResponse as? HTTPURLResponse, http.statusCode >= 400 {
                return .failure(.init(message: "HTTP \(http.statusCode)", bodySnippet: snippet))
            }
            do {
                return .success(try JSONDecoder().decode(WPSPlanResponse.self, from: data))
            } catch {
                return .failure(.init(message: "デコード失敗: \(error)", bodySnippet: snippet))
            }
        } catch {
            return .failure(.init(message: "通信失敗: \(error.localizedDescription)", bodySnippet: nil))
        }
    }
}

/// モック。`future = true` で計画書 §2-1 / §3-1 / §2-2 実装後のレスポンス形を返す。
struct WPSMockPlanClient: WPSPlanClientProtocol {
    var future: Bool = false
    var delay: TimeInterval = 0.8

    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String,
        prefectureCode: String?,
        candidatesPerDay: Int?,
        regenToken: Int?
    ) async -> Result<WPSPlanResponse, WPSPlanFailure> {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        let genres = ["きれいめ", "カジュアル", "モード", "ナチュラル", "ストリート", "クラシック"]
        let reasons = [
            "3日前に着ていた白トップスと相性がいい組み合わせ。",
            "気温18〜23℃に合う薄手のレイヤード。",
            "お気に入りに入れていたコーデと同じ系統。",
            "手持ちのネイビーパンツがそのまま使える。",
        ]
        let start = WPSDate.parse(startDate) ?? Date()
        // 冒険日は週の真ん中あたりに1日だけ (§2-3 縮小版の見え方確認用)
        let adventureIndex = min(3, max(1, days / 2))

        let planDays: [WPSPlanDay] = (0..<days).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
            let dateString = WPSDate.string(from: date)
            let isAdventure = future && offset == adventureIndex

            func makeItem(_ seed: Int, discovery: Bool, owned: Int) -> DailyRecommendationItem {
                DailyRecommendationItem(
                    pool_id: "wps_\(offset)_\(seed)",
                    kind: "pool",
                    image_url: "asset:coordinate-\((seed + offset) % 9 + 1)",
                    reason: future ? reasons[(offset + seed) % reasons.count] : nil,
                    main_colors: ["ホワイト", "ネイビー"],
                    items: ["tops": "白シャツ", "bottoms": "ネイビーパンツ", "outer": nil, "accessory": nil],
                    vibe: "落ち着いた清潔感",
                    style: genres[(offset + seed) % genres.count],
                    cleanliness: 3,
                    is_favorite: false,
                    is_discovery: future && discovery,
                    owned_items: (0..<owned).map { i in
                        DailyOwnedItem(
                            slot: i == 0 ? "tops" : "bottoms",
                            item_id: "closet_\(offset)_\(i)",
                            image_url: "asset:coordinate-\((offset + i) % 9 + 1)",
                            label: i == 0 ? "白 シャツ" : "ネイビー パンツ"
                        )
                    },
                    missing_items: owned >= 2 ? [] : ["黒 スラックス"]
                )
            }

            return WPSPlanDay(
                date: dateString,
                weather: DailyRecommendationWeather(
                    min_temp: 16 + offset % 3,
                    max_temp: 23 + offset % 4,
                    condition: ["晴れ", "曇り", "晴れ時々曇り", "雨"][offset % 4],
                    area_code: "130000"
                ),
                item: WPSPlanCandidate(
                    item: makeItem(0, discovery: isAdventure, owned: offset % 3),
                    alt_tag: nil
                ),
                // 実装後モックは要求された候補数を返す。現状モックは従来どおり3件で頭打ち
                alternates: (1..<max(2, future ? (candidatesPerDay ?? 4) : 4)).map { seed in
                    WPSPlanCandidate(
                        item: makeItem(seed, discovery: seed % 4 == 2, owned: seed % 3),
                        alt_tag: future ? ["steady", "challenge", "change"][safe: seed - 1] : nil
                    )
                },
                day_line: future ? "この日は雨予報。濡れても気にならない素材でまとめた。" : nil
            )
        }

        return .success(
            WPSPlanResponse(
                status: "success",
                days: planDays,
                week_title: future ? "手持ちで勝つ一週間" : nil,
                week_comment: future ? "今週は手持ちが活きる日が多い。木曜だけ、いつもと違う系統を混ぜておいた。" : nil,
                plan_ack: future ? "先週きれいめを3回入れ替えてたから、今週は最初から控えめにしといた。" : nil,
                signal_count: future ? 42 : nil,
                signal_caption: future ? "あなたの42回の記録と週間予報から組んだ7日分" : nil,
                speaking_style: future ? "normal" : nil
            )
        )
    }
}

// MARK: - 相棒の語り (端末内・決定論。§1-2 実況 / §3-3 入替リアクション / §3-4 フォールバック)

/// 話し方7種 (サーバの SPEAKING_STYLE_LABELS と同じキー)
enum WPSStyle: String, CaseIterable, Identifiable {
    case normal, gentle, spicy, kansai, cool, gal, ojou

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "ふつう"
        case .gentle: return "やさしい"
        case .spicy: return "毒舌・辛口"
        case .kansai: return "関西弁"
        case .cool: return "クール"
        case .gal: return "ギャル"
        case .ojou: return "お嬢様"
        }
    }
}

enum WPSVoice {
    /// §1-2 配り演出の実況 (進行段階ごと)
    static func dealingLines(for style: WPSStyle) -> [String] {
        switch style {
        case .normal:
            return ["週間予報をチェック中…", "あなたの記録を読み返してる…", "1日ずつ並べてるところ…", "もうすぐ出来上がり…"]
        case .gentle:
            return ["天気を見ていますね…", "これまでの記録を思い出しています…", "1日ずつ選んでいます…", "もう少しだけ待ってくださいね…"]
        case .spicy:
            return ["天気くらい自分で見なよ…まあいいや", "あんたの記録、読み返してる", "似たようなのばっか着てるね", "はい、まとめといたよ"]
        case .kansai:
            return ["週間予報、見てるとこや", "あんたの記録も読み返しとる", "ええ感じに並べてるで", "もうちょいで出来上がりや"]
        case .cool:
            return ["週間予報を確認", "記録を照合中", "候補を配列", "まもなく完了"]
        case .gal:
            return ["天気チェック中〜！", "記録も見返してるよ〜", "いま並べてるとこ！", "もうちょいまってて！"]
        case .ojou:
            return ["週間予報を拝見しております", "あなた様の記録を辿っております", "1日ずつ整えております", "もう少々お待ちくださいませ"]
        }
    }

    /// §3-4 週ナラティブのフォールバック。
    /// 事実 (手持ちで組める日数・冒険日の曜日) だけを差し込み、捏造しない。
    static func weekFallback(
        style: WPSStyle,
        ownedDays: Int,
        totalDays: Int,
        adventureWeekday: String?
    ) -> (title: String, comment: String) {
        let adventure = adventureWeekday.map { "\($0)曜だけ、いつもと違う系統を混ぜてある。" } ?? ""
        let ownedPhrase = ownedDays > 0
            ? "\(totalDays)日のうち\(ownedDays)日は手持ちが活きる組み合わせ。"
            : "今回は手持ちと重なるコーデが無かったから、気温と天気で組んである。"

        switch style {
        case .normal:
            return ("手持ちで組み立てる\(totalDays)日", "\(ownedPhrase)\(adventure)")
        case .gentle:
            return ("無理のない\(totalDays)日", "\(ownedPhrase)\(adventure)ゆっくり選んでくださいね。")
        case .spicy:
            return ("手持ちで勝てる\(totalDays)日", "\(ownedPhrase)\(adventure)ちゃんと着なよ。")
        case .kansai:
            return ("手持ちで回す\(totalDays)日", "\(ownedPhrase)\(adventure)ええ感じやろ。")
        case .cool:
            return ("\(totalDays)日の構成", "\(ownedPhrase)\(adventure)")
        case .gal:
            return ("手持ちでいける\(totalDays)日！", "\(ownedPhrase)\(adventure)いい感じっしょ？")
        case .ojou:
            return ("手持ちで整える\(totalDays)日", "\(ownedPhrase)\(adventure)")
        }
    }

    /// §1-3 栞の締めの一言
    static func closing(for style: WPSStyle) -> String {
        switch style {
        case .normal: return "この調子でいこう。"
        case .gentle: return "きっと素敵な一週間になりますよ。"
        case .spicy: return "決めたからには着なよ。"
        case .kansai: return "ほな、ええ一週間にしよか。"
        case .cool: return "以上。あとは着るだけ。"
        case .gal: return "楽しみにしてて〜！"
        case .ojou: return "よい一週間になりますように。"
        }
    }

    /// §3-3 入替リアクション。実データの差分だけに反応し、差分がなければ nil (=沈黙。§3-6)
    static func swapReaction(
        style: WPSStyle,
        from: DailyRecommendationItem,
        to: DailyRecommendationItem
    ) -> String? {
        let ownedDiff = to.owned_items.count - from.owned_items.count
        let genreChanged = !to.style.isEmpty && to.style != from.style
        let toChallenge = to.is_discovery && !from.is_discovery

        if toChallenge {
            switch style {
            case .normal: return "お、冒険するんだ。いいと思う。"
            case .gentle: return "いつもと違う系統ですね。楽しみです。"
            case .spicy: return "ふーん、挑戦する気あるんだ。"
            case .kansai: return "お、攻めるやん。ええで。"
            case .cool: return "挑戦枠を選択。記録しておく。"
            case .gal: return "え、それ攻めてる〜！いいじゃん！"
            case .ojou: return "普段と違う趣向ですのね。"
            }
        }
        if ownedDiff > 0 {
            switch style {
            case .normal: return "手持ち\(to.owned_items.count)点で作れるやつだね。"
            case .gentle: return "手持ちが\(to.owned_items.count)点そろっていますよ。"
            case .spicy: return "お、それ手持ち\(to.owned_items.count)点で作れるやつ。今日は冴えてるじゃん。"
            case .kansai: return "それ手持ち\(to.owned_items.count)点でいけるで。"
            case .cool: return "手持ち一致 \(to.owned_items.count)点。効率的。"
            case .gal: return "それ手持ち\(to.owned_items.count)点でいけるやつ〜！"
            case .ojou: return "お手持ちが\(to.owned_items.count)点ございますわ。"
            }
        }
        if genreChanged {
            let genre = WPSGenre.display(to.style)
            switch style {
            case .normal: return "\(genre)に切り替えたね。"
            case .gentle: return "\(genre)寄りになりましたね。"
            case .spicy: return "\(genre)ね。まあ悪くない。"
            case .kansai: return "\(genre)にしたんやな。"
            case .cool: return "系統を\(genre)へ変更。"
            case .gal: return "\(genre)にチェンジね〜！"
            case .ojou: return "\(genre)にお変えになりましたのね。"
            }
        }
        return nil   // 差分なし = 喋らない
    }
}

// MARK: - 対照的3択の軸 (§2-2)

enum WPSAxis: String, Identifiable {
    case steady, challenge, change

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steady: return "堅実"
        case .challenge: return "挑戦"
        case .change: return "気分転換"
        }
    }

    var caption: String {
        switch self {
        case .steady: return "手持ちで組める"
        case .challenge: return "いつもと違う系統"
        case .change: return "別の切り口"
        }
    }

    var icon: String {
        switch self {
        case .steady: return "checkmark.seal"
        case .challenge: return "sparkles"
        case .change: return "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .steady: return .black
        case .challenge: return .teal
        case .change: return .orange
        }
    }

    static func from(altTag: String?) -> WPSAxis? {
        guard let altTag else { return nil }
        return WPSAxis(rawValue: altTag)
    }
}

enum WPSAxisAssign {
    /// 入替候補に「堅実 / 挑戦 / 気分転換」を割り当てる。
    /// サーバが alt_tag を返していればそれを正とし、無ければ実データから導出する
    /// (この導出が3軸そろうかどうかが、そのまま §2-2 の候補4→8拡大の要否になる)。
    static func assign(day: WPSPlanDay) -> [Int: WPSAxis] {
        var result: [Int: WPSAxis] = [:]

        // サーバ実装後: alt_tag をそのまま使う
        let serverTagged = day.alternates.enumerated().compactMap { index, candidate -> (Int, WPSAxis)? in
            guard let axis = WPSAxis.from(altTag: candidate.alt_tag) else { return nil }
            return (index, axis)
        }
        if !serverTagged.isEmpty {
            for (index, axis) in serverTagged { result[index] = axis }
            return result
        }

        // 端末側導出 (サーバ未実装時)
        let primary = day.item.item
        let alternates = day.alternates.map(\.item)
        var remaining = Array(alternates.indices)

        // 挑戦: 発見枠 → 無ければ本命と別系統で手持ち一致が最少のもの
        if let index = remaining.first(where: { alternates[$0].is_discovery }) {
            result[index] = .challenge
            remaining.removeAll { $0 == index }
        } else if let index = remaining
            .filter({ !alternates[$0].style.isEmpty && alternates[$0].style != primary.style })
            .min(by: { alternates[$0].owned_items.count < alternates[$1].owned_items.count }) {
            result[index] = .challenge
            remaining.removeAll { $0 == index }
        }

        // 堅実: 手持ち一致が最多 (1点以上あること)
        if let index = remaining
            .filter({ !alternates[$0].owned_items.isEmpty })
            .max(by: { alternates[$0].owned_items.count < alternates[$1].owned_items.count }) {
            result[index] = .steady
            remaining.removeAll { $0 == index }
        }

        // 気分転換: 本命と別系統
        if let index = remaining.first(where: {
            !alternates[$0].style.isEmpty && alternates[$0].style != primary.style
        }) {
            result[index] = .change
            remaining.removeAll { $0 == index }
        }

        return result
    }
}

// MARK: - 診断 (計画書のどのフィールドが実際に届いているか)

struct WPSDiagnosticRow: Identifiable {
    enum Status {
        case ok       // 実装済み・値あり
        case missing  // サーバ未実装 (値が来ていない)
        case warn     // 値はあるが計画書の条件を満たさない
        case info     // 参考値

        var icon: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .missing: return "minus.circle"
            case .warn: return "exclamationmark.triangle.fill"
            case .info: return "info.circle"
            }
        }

        var tint: Color {
            switch self {
            case .ok: return .green
            case .missing: return Color.gray.opacity(0.6)
            case .warn: return .orange
            case .info: return Color.gray.opacity(0.6)
            }
        }
    }

    let title: String
    let value: String
    let status: Status
    let note: String    // 計画書の該当節

    var id: String { title }
}

enum WPSDiagnostics {
    static func build(
        response: WPSPlanResponse,
        elapsedMs: Int,
        requestedCandidates: Int,
        regenOverlap: Double?
    ) -> [WPSDiagnosticRow] {
        let days = response.days
        let total = days.count
        guard total > 0 else { return [] }

        let items = days.map(\.item.item)
        let reasonCount = items.filter { !($0.reason ?? "").isEmpty }.count
        let discoveryCount = items.filter(\.is_discovery).count
        let ownedDays = items.filter { !$0.owned_items.isEmpty }.count
        let altCounts = days.map(\.alternates.count)
        let minAlt = altCounts.min() ?? 0
        let maxAlt = altCounts.max() ?? 0
        let dayLineCount = days.filter { !($0.day_line ?? "").isEmpty }.count
        let altTagCount = days.filter { day in day.alternates.contains { $0.alt_tag != nil } }.count

        // 3軸 (堅実/挑戦/気分転換) がそろった日
        let axisOKDays = days.filter { Set(WPSAxisAssign.assign(day: $0).values).count >= 3 }.count

        // 同系統の最長連続 (§2-4 クォータの要否)
        var longestRun = 1
        var currentRun = 1
        var runGenre = items.first?.style ?? ""
        for i in 1..<max(items.count, 1) {
            if items[i].style == items[i - 1].style, !items[i].style.isEmpty {
                currentRun += 1
                if currentRun > longestRun {
                    longestRun = currentRun
                    runGenre = items[i].style
                }
            } else {
                currentRun = 1
            }
        }
        let uniqueGenres = Set(items.map(\.style).filter { !$0.isEmpty }).count

        // コーデ重複
        let ids = items.map(\.pool_id)
        let duplicateCount = ids.count - Set(ids).count

        var rows: [WPSDiagnosticRow] = [
            .init(
                title: "生成",
                value: "\(total)日分 / \(String(format: "%.1f", Double(elapsedMs) / 1000))秒",
                status: elapsedMs > 15000 ? .warn : .info,
                note: "§4-1 signals の1回読み最適化前は日数ぶん Firestore を読む"
            ),
            .init(
                title: "理由文 (reason)",
                value: "\(reasonCount)/\(total)日",
                status: reasonCount > 0 ? .ok : .missing,
                note: "§2-1 generate_for_user が計算済みの理由文を詰め替えるだけ"
            ),
            .init(
                title: "発見枠 (is_discovery)",
                value: discoveryCount > 0 ? "\(discoveryCount)/\(total)日" : "全日 false",
                status: discoveryCount > 0 ? .ok : .missing,
                note: "§2-1 items_meta.discovery が捨てられている"
            ),
            .init(
                title: "1日あたりの候補数",
                value: "要求\(requestedCandidates)件 / 実際\(minAlt + 1)〜\(maxAlt + 1)件 (本命含む)",
                status: minAlt + 1 >= requestedCandidates ? .ok : .warn,
                note: "§2-2 candidates_per_day (2〜15)。パラメータ未送信なら従来どおり4件"
            ),
            .init(
                title: "3軸が成立した日",
                value: "\(axisOKDays)/\(total)日",
                status: axisOKDays == total ? .ok : .warn,
                note: "§2-2 堅実/挑戦/気分転換 が実データで揃うか (端末側導出)"
            ),
            .init(
                title: "手持ち一致 (owned_items)",
                value: "\(ownedDays)/\(total)日",
                status: ownedDays > 0 ? .ok : .warn,
                note: "§2-2「堅実」軸と §3-5 根拠の供給源"
            ),
            .init(
                title: "週テーマ (week_title)",
                value: response.week_title ?? "未着 (端末テンプレで代替)",
                status: response.week_title != nil ? .ok : .missing,
                note: "§3-1 週ナラティブ flash-lite 1コール"
            ),
            .init(
                title: "週の宣言 (week_comment)",
                value: response.week_comment ?? "未着 (端末テンプレで代替)",
                status: response.week_comment != nil ? .ok : .missing,
                note: "§3-1 / 失敗時は §3-4 のテンプレで声色を割らない"
            ),
            .init(
                title: "日別ノート (day_line)",
                value: dayLineCount > 0 ? "\(dayLineCount)/\(total)日" : "未着",
                status: dayLineCount > 0 ? .ok : .missing,
                note: "§7 週ナラティブの day_lines"
            ),
            .init(
                title: "3択ラベル (alt_tag)",
                value: altTagCount > 0 ? "\(altTagCount)/\(total)日" : "未着 (端末側で導出)",
                status: altTagCount > 0 ? .ok : .missing,
                note: "§2-2 サーバが軸を決めるまでは端末導出でも体験は成立する"
            ),
            .init(
                title: "反映宣言 (plan_ack)",
                value: response.plan_ack ?? "未着",
                status: response.plan_ack != nil ? .ok : .missing,
                note: "§5-2 steering が効いた時だけ宣言する (嘘バッジ禁止)"
            ),
            .init(
                title: "根拠バッジ (signal_count)",
                value: response.signal_count.map { "\($0)回の記録" } ?? "未着",
                status: response.signal_count != nil ? .ok : .missing,
                note: "§3-5 日次で本番稼働中の signal_count を週次にも載せる"
            ),
            .init(
                title: "系統の連続",
                value: "最長\(longestRun)日連続 (\(runGenre.isEmpty ? "不明" : WPSGenre.display(runGenre))) / \(uniqueGenres)系統",
                status: longestRun >= 3 ? .warn : .ok,
                note: "§2-4 同系統3日連続はクォータで回避する対象"
            ),
            .init(
                title: "コーデ重複",
                value: duplicateCount == 0 ? "なし" : "\(duplicateCount)件",
                status: duplicateCount == 0 ? .ok : .warn,
                note: "現行 generate_plan の used_ids で防いでいる想定"
            ),
        ]

        if let overlap = regenOverlap {
            rows.append(
                .init(
                    title: "同条件の再生成",
                    value: "前回と\(Int(overlap * 100))%一致",
                    status: overlap >= 0.999 ? .ok : .missing,
                    note: "§2-5 regen_token 未実装のうちは base_seed=time() で毎回変わる"
                )
            )
        }

        return rows
    }
}

// MARK: - 系統 (genre) 表示

/// API の `style` は母集団CSV由来の英語値 (casual / korean / office_casual / sporty / vintage / minimal) が
/// そのまま返るため、確認しやすいよう日本語に直す。未知の値は原文のまま出す。
enum WPSGenre {
    private static let japanese: [String: String] = [
        "casual": "カジュアル", "korean": "韓国っぽい", "office_casual": "オフィスカジュアル",
        "sporty": "スポーティ", "vintage": "ヴィンテージ", "minimal": "ミニマル",
        "mode": "モード", "street": "ストリート", "natural": "ナチュラル",
        "kirei": "きれいめ", "kireime": "きれいめ", "feminine": "フェミニン",
        "girly": "ガーリー", "american": "アメカジ", "amekaji": "アメカジ",
    ]

    static func display(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        return japanese[raw] ?? raw
    }
}

// MARK: - 天気の表示

/// 気象庁の condition は「晴れ 後 くもり 夜 雨 所により 昼過ぎ から 夜のはじめ頃 雷を伴い 非常に 激しく 降る」
/// のような長文が入るため、カードに収まるよう主要語だけに短縮する。
enum WPSWeather {
    /// 天気そのものを表す語 (完全一致で拾う。「雷を伴い」等の修飾句は落とす)
    private static let terms: Set<String> = [
        "晴れ", "晴", "くもり", "曇り", "曇", "雨", "大雨", "雪", "大雪", "みぞれ", "雷雨", "雷",
    ]
    /// 語をつなぐ接続詞
    private static let connectives: Set<String> = ["後", "のち", "時々", "一時"]

    static func compact(_ condition: String) -> String {
        let tokens = condition
            .replacingOccurrences(of: "　", with: " ")
            .split(separator: " ")
            .map(String.init)

        var kept: [String] = []
        for token in tokens where kept.count < 4 {
            if connectives.contains(token) {
                if let last = kept.last, !connectives.contains(last) {
                    kept.append(token)
                }
            } else if terms.contains(token) {
                kept.append(token)
            }
        }
        while let last = kept.last, connectives.contains(last) {
            kept.removeLast()
        }
        if kept.isEmpty {
            // 想定外の表記はそのまま (長い場合だけ切り詰める)
            let trimmed = condition.replacingOccurrences(of: "　", with: "")
            return trimmed.count > 8 ? String(trimmed.prefix(8)) + "…" : trimmed
        }
        return kept.joined()
    }

    /// 「晴れ後くもり・23〜28°C」の1行表記
    static func line(_ weather: DailyRecommendationWeather) -> String {
        "\(compact(weather.condition))・\(weather.min_temp)〜\(weather.max_temp)°C"
    }
}

// MARK: - 日付ヘルパー

enum WPSDate {
    static func parse(_ ymd: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: ymd)
    }

    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func monthDay(_ ymd: String) -> String {
        guard let date = parse(ymd) else { return ymd }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    static func weekday(_ ymd: String) -> String {
        guard let date = parse(ymd) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class WeeklyPlannerSandboxViewModel {
    enum Phase {
        case setup       // 条件設定
        case dealing     // §1-2 配り演出 (生成待ち)
        case revealing   // §1-1 開封リビール
        case reviewing   // §2-2 3択で決める
        case bookmark    // §1-3 栞
    }

    enum Source: String, CaseIterable, Identifiable {
        case prod = "実API (本番 Render)"
        case local = "実API (localhost:8000)"
        case mockNow = "モック (現状のサーバ)"
        case mockFuture = "モック (計画書 実装後)"
        case mockSlow = "モック (遅延6秒)"

        var id: String { rawValue }

        var isLive: Bool { self == .prod || self == .local }

        var client: WPSPlanClientProtocol {
            switch self {
            case .prod: return WPSLivePlanClient(baseURL: "https://irodori-api.onrender.com")
            case .local: return WPSLivePlanClient(baseURL: "http://localhost:8000")
            case .mockNow: return WPSMockPlanClient(future: false)
            case .mockFuture: return WPSMockPlanClient(future: true)
            case .mockSlow: return WPSMockPlanClient(future: true, delay: 6)
            }
        }
    }

    // 設定
    var source: Source = .prod
    var daysCount: Int = 7
    /// 1日あたりの候補数 (本命+入替。サーバの candidates_per_day)。
    /// 現行サーバは未対応で4件固定のため、要求値と実際の差は診断パネルに出る
    var candidatesPerDay: Int = 15
    var startDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var style: WPSStyle = .normal
    /// §2-5 の互換ガード確認用。ON のときだけ regen_token を送る
    var sendRegenToken: Bool = false

    // 状態
    var phase: Phase = .setup
    var isLoading = false
    var response: WPSPlanResponse?
    var failure: WPSPlanFailure?
    var elapsedMs: Int = 0
    var diagnostics: [WPSDiagnosticRow] = []
    var showDiagnostics = false

    // 演出
    var dealtCount: Int = 0
    var narrationIndex: Int = 0
    var revealedDates: Set<String> = []

    // 選択
    var selections: [String: Int] = [:]      // date -> 候補インデックス
    var swapNotes: [String: String] = [:]    // date -> §3-3 リアクション (沈黙なら未設定)

    private var regenToken: Int = 0
    private var previousPoolIDs: [String] = []
    private var regenOverlap: Double?
    private var animationTask: Task<Void, Never>?

    let uid: String
    let gender: Gender
    let prefectureCode: String?

    init(source: Source = .prod) {
        self.source = source
        self.uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        self.gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        self.prefectureCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
    }

    var days: [WPSPlanDay] { response?.days ?? [] }

    /// §1-1 飽き対策: 11日以上は開封リビールを適用しない
    var revealApplies: Bool { days.count <= 10 }

    var allRevealed: Bool { revealedDates.count >= days.count && !days.isEmpty }

    func selectedCandidate(for day: WPSPlanDay) -> WPSPlanCandidate {
        let index = selections[day.date] ?? 0
        let candidates = day.candidates
        return candidates[min(index, candidates.count - 1)]
    }

    /// 週テーマ。サーバ(§3-1)があればそれ、無ければ端末テンプレ(§3-4)
    var weekNarrative: (title: String, comment: String, isServer: Bool) {
        if let title = response?.week_title, let comment = response?.week_comment {
            return (title, comment, true)
        }
        let ownedDays = days.filter { !selectedCandidate(for: $0).item.owned_items.isEmpty }.count
        let adventureDate = days.first { selectedCandidate(for: $0).item.is_discovery }?.date
        let fallback = WPSVoice.weekFallback(
            style: style,
            ownedDays: ownedDays,
            totalDays: max(days.count, 1),
            adventureWeekday: adventureDate.map { WPSDate.weekday($0) }
        )
        return (fallback.title, fallback.comment, false)
    }

    // MARK: 生成

    func generate() async {
        guard !isLoading else { return }
        isLoading = true
        failure = nil
        revealedDates = []
        selections = [:]
        swapNotes = [:]
        dealtCount = 0
        narrationIndex = 0
        phase = .dealing

        if sendRegenToken { regenToken += 1 }
        let startedAt = Date()

        // 配り演出: 生成を待つあいだカードが1枚ずつ積まれ、実況が進む
        animationTask?.cancel()
        let targetCount = daysCount
        let lineCount = WPSVoice.dealingLines(for: style).count
        animationTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 550_000_000)
                guard let self, self.phase == .dealing else { return }
                tick += 1
                self.dealtCount = min(tick, targetCount)
                self.narrationIndex = min(tick / 2, lineCount - 1)
            }
        }

        let result = await source.client.plan(
            uid: uid,
            gender: gender,
            days: daysCount,
            startDate: WPSDate.string(from: startDate),
            prefectureCode: prefectureCode,
            candidatesPerDay: candidatesPerDay,
            regenToken: sendRegenToken ? regenToken : nil
        )
        animationTask?.cancel()

        let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
        // 演出が一瞬で消えないよう最低尺だけ確保する (CTA はブロックしない)
        if elapsed < 1400 {
            try? await Task.sleep(nanoseconds: UInt64(1400 - elapsed) * 1_000_000)
        }
        elapsedMs = elapsed

        switch result {
        case .success(let planResponse):
            let poolIDs = planResponse.days.map(\.item.item.pool_id)
            regenOverlap = previousPoolIDs.isEmpty ? nil : overlapRatio(previousPoolIDs, poolIDs)
            previousPoolIDs = poolIDs
            response = planResponse
            diagnostics = WPSDiagnostics.build(
                response: planResponse,
                elapsedMs: elapsed,
                requestedCandidates: candidatesPerDay,
                regenOverlap: regenOverlap
            )
            if planResponse.days.isEmpty {
                failure = .init(message: "days が空でした (status: \(planResponse.status))", bodySnippet: nil)
                phase = .setup
            } else if revealApplies {
                phase = .revealing
                Haptic.impact(.soft)
            } else {
                revealedDates = Set(planResponse.days.map(\.date))
                phase = .reviewing
            }
        case .failure(let error):
            failure = error
            response = nil
            diagnostics = []
            phase = .setup
            Haptic.notify(.error)
        }

        isLoading = false
    }

    private func overlapRatio(_ lhs: [String], _ rhs: [String]) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let intersection = Set(lhs).intersection(Set(rhs)).count
        return Double(intersection) / Double(max(lhs.count, rhs.count))
    }

    // MARK: 開封 (§1-1)

    func reveal(_ date: String) {
        guard !revealedDates.contains(date) else { return }
        Haptic.impact(.light)
        revealedDates.insert(date)
        if allRevealed { Haptic.notify(.success) }
    }

    func revealAll() {
        Haptic.impact(.medium)
        revealedDates = Set(days.map(\.date))
    }

    // MARK: 選択 (§2-2 / §3-3)

    func select(date: String, index: Int) {
        guard let day = days.first(where: { $0.date == date }) else { return }
        let candidates = day.candidates
        guard index < candidates.count else { return }
        let previous = selectedCandidate(for: day).item
        selections[date] = index
        let next = candidates[index].item
        Haptic.selection()
        // 差分がなければ喋らない (§3-6 語りの総量規制)
        if let note = WPSVoice.swapReaction(style: style, from: previous, to: next) {
            swapNotes[date] = note
        } else {
            swapNotes.removeValue(forKey: date)
        }
    }

    // MARK: 遷移

    func proceedToReview() {
        revealedDates = Set(days.map(\.date))
        phase = .reviewing
    }

    func finish() {
        Haptic.notify(.success)
        phase = .bookmark
    }

    func backToSetup() {
        phase = .setup
    }
}

// MARK: - View

struct WeeklyPlannerSandboxView: View {
    @State private var viewModel: WeeklyPlannerSandboxViewModel
    @State private var editingDate: String?
    /// 表示直後に生成を走らせる (プレビューでタップせず確認するため)
    private let autoStart: Bool

    /// 既定は実API(本番)。プレビューからはモックを指定して開く
    init(source: WeeklyPlannerSandboxViewModel.Source = .prod, autoStart: Bool = false) {
        _viewModel = State(initialValue: WeeklyPlannerSandboxViewModel(source: source))
        self.autoStart = autoStart
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup:     setupView
            case .dealing:   dealingView
            case .revealing: revealView
            case .reviewing: reviewView
            case .bookmark:  bookmarkView
            }
        }
        .background(Color.gray.opacity(0.06))
        .navigationTitle("週間プランナー検証")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.diagnostics.isEmpty {
                    Button {
                        viewModel.showDiagnostics = true
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                }
            }
        }
        .task {
            if autoStart, viewModel.response == nil, !viewModel.isLoading {
                await viewModel.generate()
            }
        }
        .sheet(isPresented: $viewModel.showDiagnostics) {
            NavigationStack { diagnosticsSheet }
        }
        .sheet(item: Binding(
            get: { editingDate.map { WPSIdentifiableDate(value: $0) } },
            set: { editingDate = $0?.value }
        )) { wrapper in
            if let day = viewModel.days.first(where: { $0.date == wrapper.value }) {
                choiceSheet(day)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: 条件設定

    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("計画書「週間コーデプランナー」の Now スコープを実APIで確認する画面です。書き込みAPIは呼ばないため、カレンダーやフィードバックには影響しません。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.top, 10)

                card {
                    settingRow("接続先") {
                        Menu {
                            ForEach(WeeklyPlannerSandboxViewModel.Source.allCases) { source in
                                Button(source.rawValue) { viewModel.source = source }
                            }
                        } label: {
                            menuLabel(viewModel.source.rawValue)
                        }
                    }

                    Divider()

                    settingRow("日数") {
                        HStack(spacing: 6) {
                            ForEach([3, 5, 7, 14], id: \.self) { count in
                                chip("\(count)日", selected: viewModel.daysCount == count) {
                                    viewModel.daysCount = count
                                }
                            }
                        }
                    }

                    Divider()

                    settingRow("候補数") {
                        HStack(spacing: 6) {
                            ForEach([4, 8, 15], id: \.self) { count in
                                chip("\(count)件", selected: viewModel.candidatesPerDay == count) {
                                    viewModel.candidatesPerDay = count
                                }
                            }
                        }
                    }
                    Text("1日あたりの候補数 (本命含む)。サーバの candidates_per_day (2〜15) で指定する。未指定のリクエストは従来どおり4件")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    settingRow("開始日") {
                        DatePicker(
                            "",
                            selection: $viewModel.startDate,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(.black)
                    }

                    Divider()

                    settingRow("話し方") {
                        Menu {
                            ForEach(WPSStyle.allCases) { style in
                                Button(style.label) { viewModel.style = style }
                            }
                        } label: {
                            menuLabel(viewModel.style.label)
                        }
                    }

                    Divider()

                    Toggle(isOn: $viewModel.sendRegenToken) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("regen_token を送る")
                                .font(.system(size: 14, weight: .semibold))
                            Text("§2-5 の互換ガード確認。未実装サーバは無視するはず")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.black)
                }

                card {
                    labelValue("user_id", viewModel.uid.isEmpty ? "未設定 (ログインしていない)" : viewModel.uid)
                    labelValue("gender", viewModel.gender.apiValue)
                    labelValue("prefecture_code", viewModel.prefectureCode ?? "未設定 (東京にフォールバック)")
                }

                if let failure = viewModel.failure {
                    failureCard(failure)
                }

                if !viewModel.diagnostics.isEmpty {
                    Button {
                        viewModel.showDiagnostics = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stethoscope")
                            Text("前回の診断結果を見る")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.gray.opacity(0.6))
                        }
                        .foregroundStyle(.black)
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar(
                title: viewModel.source.isLive
                    ? "実APIで生成する（\(viewModel.daysCount)日分）"
                    : "モックで生成する（\(viewModel.daysCount)日分）",
                enabled: !viewModel.isLoading
            ) {
                Task { await viewModel.generate() }
            }
        }
    }

    // MARK: 配り演出 (§1-2)

    private var dealingView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                ForEach(0..<max(viewModel.dealtCount, 1), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white)
                        .frame(width: 150, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
                        .rotationEffect(.degrees(Double(index % 5 - 2) * 2.2))
                        .offset(
                            x: CGFloat(index % 5 - 2) * 5,
                            y: CGFloat(-index) * 3
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(height: 240)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: viewModel.dealtCount)

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    PartnerIconImage(size: 40)
                    DailyPartnerCommentBox(
                        text: WPSVoice.dealingLines(for: viewModel.style)[
                            min(viewModel.narrationIndex, WPSVoice.dealingLines(for: viewModel.style).count - 1)
                        ]
                    )
                }
                Text("\(viewModel.dealtCount) / \(viewModel.daysCount) 日分")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 開封リビール (§1-1)

    private var revealView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                weekHeader

                Text(viewModel.allRevealed
                     ? "ぜんぶ開けました"
                     : "カードをタップしてめくってください（\(viewModel.revealedDates.count) / \(viewModel.days.count)）")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(viewModel.days) { day in
                        revealCard(day)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    if !viewModel.allRevealed {
                        Button {
                            viewModel.revealAll()
                        } label: {
                            Text("一気に開ける")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(.white)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Haptic.impact(.medium)
                        viewModel.proceedToReview()
                    } label: {
                        Text("決めていく")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .background(.white)
        }
    }

    /// 裏向き/表向きの2面を同じ 3:4 の枠に重ねる。
    /// 枠は Color.clear + aspectRatio で作り、中身の高さに依らずセルの大きさを揃える
    /// (中身に aspectRatio を掛けると天気アイコンの有無でカードの高さがバラつく)。
    private func revealCard(_ day: WPSPlanDay) -> some View {
        let revealed = viewModel.revealedDates.contains(day.date)
        let item = day.item.item
        return Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ZStack {
                    cardBack(day, isDiscovery: item.is_discovery)
                        .opacity(revealed ? 0 : 1)
                        .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                    cardFront(day, item: item)
                        .opacity(revealed ? 1 : 0)
                        .rotation3DEffect(.degrees(revealed ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.45), value: revealed)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.reveal(day.date) }
    }

    /// 裏面: 日付・曜日・天気だけを印字する (発見枠は「?」)
    private func cardBack(_ day: WPSPlanDay, isDiscovery: Bool) -> some View {
        VStack(spacing: 3) {
            Text(WPSDate.monthDay(day.date))
                .font(.system(size: 15, weight: .bold))
            Text(WPSDate.weekday(day.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let weather = day.weather {
                let weatherStyle = DailyWeatherDisplay.style(for: weather.condition)
                Image(systemName: weatherStyle.iconName)
                    // multicolor だと雲が白のまま白カードに埋もれるため階層表現+着色にする
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(weatherStyle.tint)
                    .font(.system(size: 20))
                    .padding(.top, 4)
                Text(WPSWeather.compact(weather.condition))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(weather.min_temp)〜\(weather.max_temp)°")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            if isDiscovery {
                Text("?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.teal)
                    .padding(.top, 2)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 表面: コーデ写真 (枠いっぱいにクロップ)
    private func cardFront(_ day: WPSPlanDay, item: DailyRecommendationItem) -> some View {
        Color.gray.opacity(0.12)
            .overlay {
                SandboxCoordImage(source: item.image_url)
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if item.is_discovery {
                    Text("挑戦")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.teal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white)
                        .clipShape(Capsule())
                        .padding(5)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text("\(WPSDate.monthDay(day.date))(\(WPSDate.weekday(day.date)))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .padding(5)
            }
    }

    // MARK: 決める (§2-2)

    private var reviewView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                weekHeader

                if !viewModel.revealApplies {
                    Text("11日以上のため開封リビールは適用していません（§1-1 の縮退条件）")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 10) {
                    ForEach(viewModel.days) { day in
                        dayRow(day)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar(title: "この内容で決める（\(viewModel.days.count)日分）", enabled: true) {
                viewModel.finish()
            }
        }
    }

    private func dayRow(_ day: WPSPlanDay) -> some View {
        let candidate = viewModel.selectedCandidate(for: day)
        let item = candidate.item
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(WPSDate.monthDay(day.date))
                        .font(.system(size: 15, weight: .bold))
                    Text(WPSDate.weekday(day.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44)

                SandboxCoordImage(source: item.image_url)
                    .scaledToFill()
                    .frame(width: 78, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if !item.style.isEmpty {
                            Text(WPSGenre.display(item.style))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        if item.is_discovery {
                            Text("挑戦")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.teal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().stroke(Color.teal.opacity(0.35), lineWidth: 0.8))
                        }
                    }

                    if let weather = day.weather {
                        // 気象庁の condition は長文なので主要語だけに短縮して1行に収める
                        HStack(spacing: 4) {
                            Image(systemName: DailyWeatherDisplay.style(for: weather.condition).iconName)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(DailyWeatherDisplay.style(for: weather.condition).tint)
                                .font(.system(size: 11))
                            Text(WPSWeather.line(weather))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    // §2-1: day_line → reason の順に出す。どちらも無ければ「未着」を明示する
                    Group {
                        if let line = day.day_line, !line.isEmpty {
                            Text(line)
                        } else if let reason = item.reason, !reason.isEmpty {
                            Text(reason)
                        } else {
                            Text("理由文なし（§2-1 未実装）")
                                .foregroundStyle(Color.orange.opacity(0.9))
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                    HStack(spacing: 6) {
                        if !item.owned_items.isEmpty {
                            OwnedItemCircles(items: item.owned_items, size: 20, background: .white)
                            Text("手持ち\(item.owned_items.count)点")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            NoOwnedItemBadge(size: 20)
                            Text("手持ち一致なし")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if let note = viewModel.swapNotes[day.date] {
                // §3-3 入替リアクション (差分がある時だけ出る)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange.opacity(0.75))
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                Haptic.impact(.soft)
                editingDate = day.date
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 11, weight: .medium))
                    Text(day.alternates.isEmpty
                         ? "候補なし"
                         : "候補から選び直す（\(day.candidates.count)件）")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white)
                .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(day.alternates.isEmpty)
            .opacity(day.alternates.isEmpty ? 0.4 : 1)
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    // MARK: 対照的3択シート (§2-2)

    private func choiceSheet(_ day: WPSPlanDay) -> some View {
        let axes = WPSAxisAssign.assign(day: day)
        let selectedIndex = viewModel.selections[day.date] ?? 0
        let usesServerTag = day.alternates.contains { $0.alt_tag != nil }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(WPSDate.monthDay(day.date))(\(WPSDate.weekday(day.date))) のコーデ")
                        .font(.system(size: 15, weight: .bold))
                    Text("候補\(day.candidates.count)件 / 軸ラベル\(Set(axes.values).count)件"
                         + (usesServerTag ? "・サーバの alt_tag" : "・端末側で導出（§2-2 未実装）"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("閉じる") { editingDate = nil }
                    .font(.system(size: 14))
                    .foregroundStyle(.black)
            }
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(day.candidates.enumerated()), id: \.offset) { index, candidate in
                        choiceRow(
                            day: day,
                            index: index,
                            candidate: candidate,
                            axis: index == 0 ? nil : axes[index - 1],
                            isSelected: index == selectedIndex
                        )
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 20)
    }

    private func choiceRow(
        day: WPSPlanDay,
        index: Int,
        candidate: WPSPlanCandidate,
        axis: WPSAxis?,
        isSelected: Bool
    ) -> some View {
        let item = candidate.item
        return Button {
            viewModel.select(date: day.date, index: index)
        } label: {
            HStack(spacing: 12) {
                SandboxCoordImage(source: item.image_url)
                    .scaledToFill()
                    .frame(width: 64, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if index == 0 {
                            Text("いま選んでいる本命")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        } else if let axis {
                            HStack(spacing: 3) {
                                Image(systemName: axis.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                Text(axis.label)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(axis.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .overlay(Capsule().stroke(axis.tint.opacity(0.3), lineWidth: 0.9))
                        } else {
                            Text("候補\(index)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let axis, index > 0 {
                        Text(axis.caption)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.style.isEmpty ? "系統不明" : WPSGenre.display(item.style))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)

                    Text(item.owned_items.isEmpty
                         ? "手持ち一致なし"
                         : "手持ち\(item.owned_items.count)点で作れる")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .black : Color.gray.opacity(0.35))
            }
            .padding(12)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.black.opacity(0.55) : Color.black.opacity(0.08), lineWidth: isSelected ? 1.6 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: 栞 (§1-3)

    private var bookmarkView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                WPSBookmarkCard(
                    days: viewModel.days,
                    selected: { viewModel.selectedCandidate(for: $0).item },
                    title: viewModel.weekNarrative.title,
                    closing: WPSVoice.closing(for: viewModel.style)
                )

                Text("Sandbox では保存しません（calendar_outfits へ書き込まないため、本番の予定コーデは変わりません）")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Button {
                        viewModel.showDiagnostics = true
                    } label: {
                        Text("診断結果を見る")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.backToSetup()
                    } label: {
                        Text("条件を変えてもう一度")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: 診断シート

    private var diagnosticsSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("計画書のフィールドが実際に届いているかの確認結果です。「—」はサーバ未実装を意味します。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(viewModel.diagnostics) { row in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: row.status.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(row.status.tint)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(row.value)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            Text(row.note)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
        .background(Color.gray.opacity(0.06))
        .navigationTitle("API 診断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") { viewModel.showDiagnostics = false }
            }
        }
    }

    // MARK: 共通部品

    /// 週テーマ + 根拠バッジ (§3-1 / §3-5)。サーバ値か端末フォールバックかを明示する
    private var weekHeader: some View {
        let narrative = viewModel.weekNarrative
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(narrative.title)
                    .font(.system(size: 17, weight: .bold))
                Text(narrative.isServer ? "サーバ生成" : "端末フォールバック")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(narrative.isServer ? Color.green : Color.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Capsule().stroke(
                            (narrative.isServer ? Color.green : Color.orange).opacity(0.35),
                            lineWidth: 0.9
                        )
                    )
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                PartnerIconImage(size: 36)
                DailyPartnerCommentBox(text: narrative.comment)
            }

            if let ack = viewModel.response?.plan_ack, !ack.isEmpty {
                Text("反映宣言: \(ack)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let caption = viewModel.response?.signal_caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            content()
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.black : Color.white)
                .overlay(Capsule().stroke(selected ? Color.clear : Color.black.opacity(0.18), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.black)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func failureCard(_ failure: WPSPlanFailure) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("生成に失敗しました")
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(failure.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let snippet = failure.bodySnippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(6)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private func ctaBar(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                action()
            } label: {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(enabled ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }
}

/// sheet(item:) 用の String ラッパー
private struct WPSIdentifiableDate: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - 栞カード (§1-3 サムネイルが順に綴じられる完成儀式)

private struct WPSBookmarkCard: View {
    let days: [WPSPlanDay]
    let selected: (WPSPlanDay) -> DailyRecommendationItem
    let title: String
    let closing: String

    @State private var appearedCount = 0
    @State private var showCheck = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(showCheck ? 1 : 0.2)
            .opacity(showCheck ? 1 : 0)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                    SandboxCoordImage(source: selected(day).image_url)
                        .scaledToFill()
                        .frame(width: 40, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(index < appearedCount ? 1 : 0)
                        .offset(y: index < appearedCount ? 0 : 8)
                }
            }
            .frame(maxWidth: .infinity)

            Text(closing)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .task {
            for index in days.indices {
                try? await Task.sleep(nanoseconds: 110_000_000)
                withAnimation(.easeOut(duration: 0.25)) {
                    appearedCount = index + 1
                }
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                showCheck = true
            }
        }
    }
}

// MARK: - Previews

/// Preview プロセスの UserDefaults は実機アプリと別コンテナで空のため、
/// 未設定の場合のみ検証用の uid / 性別を書き込む (ログイン済み環境の値は上書きしない)。
/// 実ユーザーのクローゼット一致を見たい場合は uid を実際の値に書き換える。
private func wpsConfigureRealAPIPreviewUser() {
    let ud = UserDefaults.standard
    if (ud.string(forKey: UserDefaultsKey.userId.rawValue) ?? "").isEmpty {
        ud.set("ios-sandbox-preview", forKey: UserDefaultsKey.userId.rawValue)
    }
    if (ud.string(forKey: UserDefaultsKey.gender.rawValue) ?? "").isEmpty {
        ud.set(Gender.female.rawValue, forKey: UserDefaultsKey.gender.rawValue)
    }
}

/// 現行サーバと同じ形 (reason=nil / is_discovery=false / 週ナラティブ無し)。
/// 端末フォールバックだけで体験が成立するかを見る。
#Preview("週間プランナー検証 - モック(現状のサーバ)") {
    NavigationStack {
        WeeklyPlannerSandboxView(source: .mockNow)
    }
}

/// 計画書 §2-1 / §2-2 / §3-1 / §5-2 実装後の形。目標とする体験の見え方。
#Preview("週間プランナー検証 - モック(実装後)") {
    NavigationStack {
        WeeklyPlannerSandboxView(source: .mockFuture)
    }
}

/// 配り演出 (§1-2) の尺確認用。生成に6秒かかるケース。
#Preview("週間プランナー検証 - 遅延6秒(配り演出)") {
    NavigationStack {
        WeeklyPlannerSandboxView(source: .mockSlow)
    }
}

/// 実API接続。POST /api/recommendation/plan のみ実通信 (書き込みは無し)。
/// 日数ぶん直列生成するため 7日で数秒かかる (§0 の構造的制約)。
#Preview("週間プランナー検証 - 実API(本番)") {
    wpsConfigureRealAPIPreviewUser()
    return NavigationStack {
        WeeklyPlannerSandboxView(source: .prod)
    }
}
