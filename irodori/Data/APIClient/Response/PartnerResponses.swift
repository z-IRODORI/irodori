//
//  PartnerResponses.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  相棒機能（/api/partner/*）のレスポンスモデル群。
//  ヒューマンインザループ形式の5画面パターンで共用する。
//

import Foundation

// MARK: - 共通: 相棒の状態

struct PartnerState: Codable, Hashable {
    let level: Int              // LV = 累計ログイン日数
    let level_name: String
    let exp: Int
    let exp_to_next: Int
    let understanding_pct: Int
    let streak_days: Int
    let total_interactions: Int
    let login_days: Int?        // 累計ログイン日数（= level）

    static func mock(exp: Int = 120, streak: Int = 4) -> PartnerState {
        PartnerState(
            level: 5,
            level_name: "かおみしり",
            exp: exp,
            exp_to_next: 150 - exp > 0 ? 150 - exp : 0,
            understanding_pct: min(100, exp * 100 / 500),
            streak_days: streak,
            total_interactions: 23,
            login_days: 5
        )
    }
}

struct PartnerOnboardingTrait: Codable, Hashable, Identifiable {
    let axis: String            // impression | priority | range | tone
    let axis_label: String      // 「なりたい印象」など
    let value: String           // soft | F | C | gentle など
    let label: String           // 「優しくて、話しかけやすい」など

    var id: String { axis }
}

struct PartnerOnboardingResponse: Codable, Hashable {
    let status: String
    let user_id: String
    let type_code: String
    let type_name: String
    let partner_subtitle: String
    let speaking_style: String
    let speaking_style_label: String
    let birth_greeting: String
    let home_briefing: String
    let traits: [PartnerOnboardingTrait]
    let state: PartnerState

    static func mock(
        impression: String = "soft",
        priority: String = "F",
        rangeVal: String = "C",
        tone: String = "gentle"
    ) -> PartnerOnboardingResponse {
        let ax1 = rangeVal == "T" ? "T" : "C"
        let ax2 = (impression == "unique" || impression == "refined") ? "P" : "R"
        let ax3 = priority == "A" ? "A" : "F"
        let ax4 = (impression == "refined" || impression == "unique") ? "Q" : "E"
        let code = "\(ax1)\(ax2)\(ax3)\(ax4)"

        let typeMap: [String: String] = [
            "TPAQ": "アヴァンギャルド・スター",
            "TPAE": "トレンド・エディター",
            "TPFQ": "アクティブ・クリエイター",
            "TPFE": "スマート・フォロワー",
            "TRAQ": "ソーシャル・アイコン",
            "TRAE": "モテ・プランナー",
            "TRFQ": "エグゼクティブ・ノマド",
            "TRFE": "クリーン・スタンダード",
            "CPAQ": "オーセンティック・アーティスト",
            "CPAE": "ヴィンテージ・ミニマリスト",
            "CPFQ": "ヘビー・デューティー",
            "CPFE": "セルフ・ミニマリスト",
            "CRAQ": "ロイヤル・クラシック",
            "CRAE": "トラッド・コンサバ",
            "CRFQ": "プロフェッショナル・ギア",
            "CRFE": "エッセンシャル・ワーカー"
        ]
        let typeName = typeMap[code] ?? "クリーン・スタンダード"

        let impShort: String
        let impLabel: String
        switch impression {
        case "refined":
            impShort = "大人っぽさ"
            impLabel = "大人っぽくて、落ち着いている"
        case "unique":
            impShort = "自分らしさ"
            impLabel = "おしゃれで、自分らしさがある"
        case "clean":
            impShort = "清潔感"
            impLabel = "きちんとしていて、清潔感がある"
        default:
            impShort = "親しみやすさ"
            impLabel = "優しくて、話しかけやすい"
        }

        let priShort = priority == "A" ? "綺麗なシルエット" : "着心地の良さ"
        let priLabel = priority == "A" ? "シルエットが綺麗で、気分が上がること" : "ラクに動けて、着心地がいいこと"
        let rngShort = rangeVal == "T" ? "新鮮な組み合わせ" : "安心できる着回し"
        let rngLabel = rangeVal == "T" ? "マンネリしない、新しい組み合わせ" : "手持ちの服で、安心できる着回し"

        let toneShort: String
        let toneLabel: String
        let birthGreeting: String
        let homeBriefing: String
        switch tone {
        case "normal":
            toneShort = "フランク"
            toneLabel = "友達みたいにフランクに"
            birthGreeting = "よろしくね！これから毎朝、あなたの相棒としてコーデを一緒に考えるよ。\n「\(impShort)」と「\(priShort)」を大事にしつつ、\(rngShort)を提案していくね！"
            homeBriefing = "おはよう！今日は朝晩で少し気温差がありそうだよ。\nあなたの好みに合わせて、「\(impShort)」と「\(priShort)」にぴったりの\(rngShort)を3案まとめておいたよ！"
        case "spicy":
            toneShort = "本音で辛口"
            toneLabel = "本音でズバッと辛口に"
            birthGreeting = "よろしく。今日からあなたの専属相棒として、妥協なしでコーデを組むよ。\n「\(impShort)」も「\(priShort)」も欲張りつつ、一番似合う\(rngShort)を選んでいくからね。"
            homeBriefing = "おはよう。朝晩の寒暖差で服選びをミスりやすい日だから気をつけて。\n「\(impShort)」も「\(priShort)」も外さない\(rngShort)を3つ厳選しておいたよ。"
        case "cool":
            toneShort = "要点シンプル"
            toneLabel = "要点だけシンプルに"
            birthGreeting = "設定完了。「\(impShort)」×「\(priShort)」を軸に、毎朝3つの「\(rngShort)」を提案する。\n迷う時間を減らして、納得できる1日を作ろう。"
            homeBriefing = "朝晩の気温差に注意。あなたの4つの好みに合わせて、「\(impShort)」と「\(priShort)」を満たす\(rngShort)を3案ピックアップした。"
        default:
            toneShort = "やさしく丁寧"
            toneLabel = "やさしく丁寧に"
            birthGreeting = "はじめまして。これからあなたの毎日をサポートしますね。\n「\(impShort)」と「\(priShort)」を大切にしながら、\(rngShort)を毎朝ご提案していきます。"
            homeBriefing = "おはようございます。朝晩の気温差がある一日になりそうですね。\nあなたの好みに合わせて、「\(impShort)」と「\(priShort)」を両立できる\(rngShort)を3つ選びました。"
        }

        let traits: [PartnerOnboardingTrait] = [
            .init(axis: "impression", axis_label: "なりたい印象", value: impression, label: impLabel),
            .init(axis: "priority", axis_label: "大事にしたい感覚", value: priority, label: priLabel),
            .init(axis: "range", axis_label: "毎日の提案", value: rangeVal, label: rngLabel),
            .init(axis: "tone", axis_label: "相棒の話し方", value: tone, label: toneLabel)
        ]

        return PartnerOnboardingResponse(
            status: "success",
            user_id: "mock-user",
            type_code: code,
            type_name: typeName,
            partner_subtitle: "\(impShort)・\(priShort)・\(rngShort)",
            speaking_style: tone,
            speaking_style_label: toneShort,
            birth_greeting: birthGreeting,
            home_briefing: homeBriefing,
            traits: traits,
            state: .mock()
        )
    }
}

struct PartnerHomeResponse: Decodable, Hashable {
    let status: String
    let user_id: String
    let greeting: String
    let sub_greeting: String?
    let state: PartnerState
    var type_code: String? = nil
    var type_name: String? = nil
    var partner_subtitle: String? = nil
    var speaking_style: String? = nil
    var speaking_style_label: String? = nil
    var home_briefing: String? = nil
    var traits: [PartnerOnboardingTrait]? = nil
    var has_completed_onboarding: Bool? = nil

    static func mock() -> PartnerHomeResponse {
        let onb = PartnerOnboardingResponse.mock()
        return PartnerHomeResponse(
            status: "success",
            user_id: "mock-user",
            greeting: "おはよう！このまえの「きれいめカジュアル」、まだ余韻に浸ってるよ。",
            sub_greeting: "4日連続で会えてうれしい 🌷",
            state: .mock(),
            type_code: onb.type_code,
            type_name: onb.type_name,
            partner_subtitle: onb.partner_subtitle,
            speaking_style: onb.speaking_style,
            speaking_style_label: onb.speaking_style_label,
            home_briefing: onb.home_briefing,
            traits: onb.traits,
            has_completed_onboarding: true
        )
    }
}

// MARK: - 共通: 相棒からあなたへ（理解 → 提案 → 発見）

struct PartnerAdvice: Decodable, Hashable, Identifiable {
    let id: String
    let good_point: String      // 良い点（いまのスタイルの良いところ）
    let concern: String         // 気になる点（やさしく・責めない）
    let advice: String          // ワンポイントアドバイス（人物像に近づくファッション提案）
    let evidence_hint: String?

    static func mock() -> PartnerAdvice {
        PartnerAdvice(
            id: "advice-mock-1",
            good_point: "最近の「きれいめカジュアル」な雰囲気、軸が通っていてすごく良いと思う。シンプルなのに地味すぎない、絶妙なバランス。",
            concern: "ワンパターンに見えないように、たまに違う色や小物を混ぜてみるのもありかも。攻めの一着があってもいいな。",
            advice: "差し色の小物をひとつ足すだけで、ぐっとあなたらしさが立つと思う。今度の休日、気が向いたら試してみてほしいな。",
            evidence_hint: "いつものコーデから"
        )
    }
}

struct PartnerAdviceResponse: Decodable, Hashable {
    let status: String
    let advice: PartnerAdvice
    let state: PartnerState

    static func mock() -> PartnerAdviceResponse {
        PartnerAdviceResponse(status: "success", advice: .mock(), state: .mock())
    }
}

struct PartnerAdviceFeedbackResponse: Decodable, Hashable {
    let status: String
    let reply: String
    let exp_gained: Int
    let state: PartnerState

    static func mock(reaction: String) -> PartnerAdviceFeedbackResponse {
        let reply: String
        switch reaction {
        case "helpful": reply = "よかった。あなたのことをずっと見てきた甲斐があったよ ✨"
        case "not_for_me": reply = "正直にありがとう。じゃあ次は別の角度から考えてみるね。こういうやりとりが、いちばん勉強になるんだ。"
        default: reply = "うれしい！試したら、どうだったかぜひ見せてね 🌷"
        }
        return PartnerAdviceFeedbackResponse(status: "success", reply: reply, exp_gained: 5, state: .mock(exp: 125))
    }
}

// MARK: - パターン1: 今日の1問

struct PartnerDailyQuestion: Decodable, Hashable, Identifiable {
    let id: String
    let text: String
    let category: String
    let choices: [String]
    let allows_free_text: Bool

    static func mock() -> PartnerDailyQuestion {
        PartnerDailyQuestion(
            id: "q-mock-1",
            text: "クローゼットで、ついつい手が伸びる色ってある？",
            category: "好み",
            choices: ["白・ベージュ系", "黒・ネイビー系", "差し色系"],
            allows_free_text: true
        )
    }
}

struct PartnerDailyQuestionResponse: Decodable, Hashable {
    let status: String
    let answered_today: Bool
    let question: PartnerDailyQuestion?
    let answered_reaction: String?

    static func mock(answered: Bool = false) -> PartnerDailyQuestionResponse {
        PartnerDailyQuestionResponse(
            status: "success",
            answered_today: answered,
            question: answered ? nil : .mock(),
            answered_reaction: answered ? "今日はもう話せたね。また明日！" : nil
        )
    }
}

struct PartnerAnswerResponse: Decodable, Hashable {
    let status: String
    let reaction: String
    let exp_gained: Int
    let state: PartnerState

    static func mock() -> PartnerAnswerResponse {
        PartnerAnswerResponse(
            status: "success",
            reaction: "「白・ベージュ系」かあ、いいね。あなたの「らしさ」のピースがまたひとつ集まったよ。",
            exp_gained: 10,
            state: .mock(exp: 130)
        )
    }
}

// MARK: - パターン2: インサイトカード

struct PartnerInsightCard: Decodable, Hashable, Identifiable {
    let id: String
    let pattern: String   // discovery | ratio | comparison | celebration | question | future
    let emoji: String
    let title: String
    let body: String
    let data_hint: String?

    static func mocks() -> [PartnerInsightCard] {
        [
            PartnerInsightCard(
                id: "card-1", pattern: "ratio", emoji: "🤍",
                title: "気づいたことがあるんだ",
                body: "最近、3回に1回くらいは「ベージュ」を選んでるみたい。自分でも気づいてた？",
                data_hint: "直近12回中4回"
            ),
            PartnerInsightCard(
                id: "card-2", pattern: "celebration", emoji: "🌷",
                title: "ちょっと言わせて",
                body: "最近5日もコーデを残してくれてた。続いてるの、ほんとにすごいと思う。",
                data_hint: "直近の記録日数: 5日"
            ),
            PartnerInsightCard(
                id: "card-3", pattern: "question", emoji: "👀",
                title: "ねえ、ひとつ聞いていい？",
                body: "アクセサリーをつけたあなた、まだちゃんと見たことがない気がする。今度見せてくれない？",
                data_hint: "記録にない種類: アクセサリー"
            ),
        ]
    }
}

struct PartnerInsightCardsResponse: Decodable, Hashable {
    let status: String
    let cards: [PartnerInsightCard]

    static func mock() -> PartnerInsightCardsResponse {
        PartnerInsightCardsResponse(status: "success", cards: PartnerInsightCard.mocks())
    }
}

struct PartnerCardReactionResponse: Decodable, Hashable {
    let status: String
    let reply: String
    let exp_gained: Int
    let state: PartnerState

    static func mock(reaction: String = "accurate") -> PartnerCardReactionResponse {
        let reply: String
        switch reaction {
        case "not_quite": reply = "教えてくれてありがとう。思い込みを直せるの、すごく助かる。次はもっと当てるね。"
        case "tell_me_more": reply = "もっと知りたい？OK、次に会うときまでに深掘りしておくね 🤍"
        default: reply = "よかった、ちゃんと見えてたみたい。これからも観察がんばるね ✨"
        }
        return PartnerCardReactionResponse(status: "success", reply: reply, exp_gained: 5, state: .mock(exp: 125))
    }
}

// MARK: - パターン4: 好みクイズ（2択投票）

struct PartnerQuizOutfit: Decodable, Hashable {
    let pool_id: String
    let image_url: String
    let genre: String?
    let vibe: String?
}

struct PartnerQuizPair: Decodable, Hashable, Identifiable {
    let pair_id: String
    let left: PartnerQuizOutfit
    let right: PartnerQuizOutfit

    var id: String { pair_id }

    static func mocks() -> [PartnerQuizPair] {
        (0..<5).map { i in
            PartnerQuizPair(
                pair_id: "pair-\(i)",
                left: PartnerQuizOutfit(
                    pool_id: "w_l\(i)",
                    image_url: "https://picsum.photos/seed/irodori-left-\(i)/600/800",
                    genre: "カジュアル", vibe: "リラックス"
                ),
                right: PartnerQuizOutfit(
                    pool_id: "w_r\(i)",
                    image_url: "https://picsum.photos/seed/irodori-right-\(i)/600/800",
                    genre: "きれいめ", vibe: "クリーン"
                )
            )
        }
    }
}

struct PartnerStyleQuizResponse: Decodable, Hashable {
    let status: String
    let pairs: [PartnerQuizPair]
    let votes_total: Int

    static func mock() -> PartnerStyleQuizResponse {
        PartnerStyleQuizResponse(status: "success", pairs: PartnerQuizPair.mocks(), votes_total: 12)
    }
}

struct PartnerVoteResponse: Decodable, Hashable {
    let status: String
    let exp_gained: Int
    let votes_total: Int
    let discovery: String?
    let state: PartnerState

    static func mock(votesTotal: Int) -> PartnerVoteResponse {
        PartnerVoteResponse(
            status: "success",
            exp_gained: 3,
            votes_total: votesTotal,
            discovery: votesTotal % 5 == 0
                ? "\(votesTotal)票ありがとう！見えてきたよ。迷ったとき、あなたは「きれいめ」系を選ぶことが多いみたい。"
                : nil,
            state: .mock(exp: 120 + votesTotal * 3)
        )
    }
}

// MARK: - パターン5: あなた研究ノート

struct PartnerHypothesis: Decodable, Hashable, Identifiable {
    let id: String
    let text: String
    let source_hint: String?
    let status: String

    static func mocks() -> [PartnerHypothesis] {
        [
            PartnerHypothesis(id: "h-1", text: "あなたは「カジュアル」な気分の日が多い説", source_hint: "最近のコーデ12回中7回に登場", status: "pending"),
            PartnerHypothesis(id: "h-2", text: "迷ったら「きれいめ」を選ぶ説", source_hint: "好みクイズの投票傾向から", status: "pending"),
            PartnerHypothesis(id: "h-3", text: "雨の日は無難な服に逃げがち説", source_hint: "天気と気分の関係から", status: "pending"),
        ]
    }
}

struct PartnerHypothesesResponse: Decodable, Hashable {
    let status: String
    let hypotheses: [PartnerHypothesis]

    static func mock() -> PartnerHypothesesResponse {
        PartnerHypothesesResponse(status: "success", hypotheses: PartnerHypothesis.mocks())
    }
}

struct PartnerNotebookEntry: Decodable, Hashable, Identifiable {
    let id: String
    let text: String
    let verdict: String   // yes | no | sometimes
    let comment: String?
    let decided_at: String

    static func mocks() -> [PartnerNotebookEntry] {
        [
            PartnerNotebookEntry(id: "n-1", text: "コーデの主役はいつもトップス説", verdict: "yes", comment: "たしかに！", decided_at: "2026-06-08T09:00:00+09:00"),
            PartnerNotebookEntry(id: "n-2", text: "お気に入りの色、実はもう決まってる説", verdict: "sometimes", comment: nil, decided_at: "2026-06-05T20:30:00+09:00"),
            PartnerNotebookEntry(id: "n-3", text: "休日は動きやすさを最優先する説", verdict: "no", comment: "意外とおしゃれ優先", decided_at: "2026-06-01T12:00:00+09:00"),
        ]
    }
}

struct PartnerVerdictResponse: Decodable, Hashable {
    let status: String
    let reply: String
    let exp_gained: Int
    let state: PartnerState
    let notebook_entry: PartnerNotebookEntry?

    static func mock(verdict: String, hypothesis: PartnerHypothesis) -> PartnerVerdictResponse {
        let reply: String
        switch verdict {
        case "no": reply = "そっか、はずれたか〜。でも「違う」が分かるのも大発見。書き直しておくね。"
        case "sometimes": reply = "「ときどき」かあ、それが いちばんリアルだね。条件つきでメモしておく 🤍"
        default: reply = "やっぱり！ノートに「確定」って書いておくね。あなたのこと、また少し分かった ✨"
        }
        return PartnerVerdictResponse(
            status: "success",
            reply: reply,
            exp_gained: 8,
            state: .mock(exp: 128),
            notebook_entry: PartnerNotebookEntry(
                id: hypothesis.id, text: hypothesis.text, verdict: verdict,
                comment: nil, decided_at: "2026-06-11T10:00:00+09:00"
            )
        )
    }
}

struct PartnerNotebookResponse: Decodable, Hashable {
    let status: String
    let entries: [PartnerNotebookEntry]
    let total: Int

    static func mock() -> PartnerNotebookResponse {
        let entries = PartnerNotebookEntry.mocks()
        return PartnerNotebookResponse(status: "success", entries: entries, total: entries.count)
    }
}

// MARK: - パターン3: 育成

struct PartnerLevelInfo: Decodable, Hashable, Identifiable {
    let level: Int
    let name: String
    let threshold: Int
    let perk: String
    let unlocked: Bool

    var id: Int { level }
}

struct PartnerQuest: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let exp: Int
    let done: Bool
}

struct PartnerExpEvent: Decodable, Hashable {
    let label: String
    let exp: Int
    let at: String
    let kind: String?           // coordinate | partner（活動ログの種別）
}

struct PartnerGrowthResponse: Decodable, Hashable {
    let status: String
    let state: PartnerState
    let levels: [PartnerLevelInfo]
    let quests: [PartnerQuest]
    let recent_events: [PartnerExpEvent]

    static func mock() -> PartnerGrowthResponse {
        PartnerGrowthResponse(
            status: "success",
            state: .mock(),
            levels: [
                PartnerLevelInfo(level: 1, name: "であったばかり", threshold: 0, perk: "あいさつと「今日の1問」", unlocked: true),
                PartnerLevelInfo(level: 2, name: "かおみしり", threshold: 50, perk: "インサイトカード（相棒の気づき）", unlocked: true),
                PartnerLevelInfo(level: 3, name: "ともだち", threshold: 150, perk: "あなた研究ノート（仮説と検証）", unlocked: false),
                PartnerLevelInfo(level: 4, name: "しんゆう", threshold: 300, perk: "好みの深掘り分析", unlocked: false),
                PartnerLevelInfo(level: 5, name: "あいぼう", threshold: 500, perk: "月間ストーリーの語り", unlocked: false),
            ],
            quests: [
                PartnerQuest(id: "daily_question", title: "今日の1問にこたえる", exp: 10, done: true),
                PartnerQuest(id: "card_reaction", title: "相棒の気づきにリアクションする", exp: 5, done: false),
                PartnerQuest(id: "style_votes", title: "好みクイズに3回投票する", exp: 9, done: false),
            ],
            recent_events: [
                PartnerExpEvent(label: "コーデを記録した — 「きれいめカジュアル」", exp: 0, at: "2026-06-11T08:30:00+09:00", kind: "coordinate"),
                PartnerExpEvent(label: "今日の1問にこたえた", exp: 10, at: "2026-06-10T21:10:00+09:00", kind: "partner"),
                PartnerExpEvent(label: "好みクイズに投票した", exp: 3, at: "2026-06-10T21:05:00+09:00", kind: "partner"),
                PartnerExpEvent(label: "今日も会いに来てくれた", exp: 1, at: "2026-06-10T21:00:00+09:00", kind: "partner"),
            ]
        )
    }
}

// MARK: - 話し方設定

struct PartnerSpeakingStyleOption: Decodable, Hashable, Identifiable {
    let key: String
    let label: String
    let text: String
    var id: String { key }
}

struct PartnerSpeakingStyleResponse: Decodable, Hashable {
    let status: String
    let speaking_style: String
    let speaking_style_text: String
    let presets: [PartnerSpeakingStyleOption]

    static func mock(selected: String = "spicy") -> PartnerSpeakingStyleResponse {
        let presets = [
            PartnerSpeakingStyleOption(key: "normal", label: "ふつう", text: "ふつうの親しい友だち口調"),
            PartnerSpeakingStyleOption(key: "gentle", label: "やさしい", text: "やさしく寄り添う口調"),
            PartnerSpeakingStyleOption(key: "spicy", label: "毒舌・辛口", text: "毒舌・辛口だけど愛のある親友口調"),
            PartnerSpeakingStyleOption(key: "kansai", label: "関西弁", text: "関西弁のにぎやかな口調"),
            PartnerSpeakingStyleOption(key: "cool", label: "クール", text: "クールで大人っぽい口調"),
            PartnerSpeakingStyleOption(key: "gal", label: "ギャル", text: "ギャルっぽい高めの口調"),
            PartnerSpeakingStyleOption(key: "ojou", label: "お嬢様", text: "お嬢様口調"),
        ]
        return PartnerSpeakingStyleResponse(
            status: "success",
            speaking_style: selected,
            speaking_style_text: presets.first { $0.key == selected }?.text ?? selected,
            presets: presets
        )
    }
}
