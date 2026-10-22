//
//  PartnerDiscoveryModels.swift
//  irodori - Sandbox
//
//  相棒の「発見」(あなた自身も気づいていないかもしれない一面) のモックと、案A〜Dで共用する部品。
//  特徴を一覧にするのではなく、相棒が日々の行動から見つけたことを
//  「日記」「めくるカード」「色と形」「ふりかえり」として届け、問いかけで深掘りできるようにする。
//  数字はテストアカウントの実データ (服21点・モノトーン14点・無地24/29 など) を元にしたサンプル。
//

import SwiftUI

// MARK: - 発見

struct PartnerDiscovery: Identifiable, Hashable {
    enum Rarity: String {
        case normal = "発見"
        case surprise = "意外"
        case rare = "レア"
    }

    /// 発見の裏付けを小さく見せるグラフ
    enum Viz: Hashable {
        /// 色の割合 (色, 割合)
        case colorShare([PartnerSwatch])
        /// 曜日ごとの値 (月〜日, 0...1) とハイライトする曜日
        case weekday([Double], highlight: Int)
        /// 2つの比較 (ラベル, 値, 単位)
        case compare(String, Double, String, Double, unit: String)
        /// 服を並べる (服, ラベル)
        case garments([PartnerGarmentMock], caption: String)
    }

    /// 深掘りの問いかけ。答えると相棒がもう一歩踏み込む
    struct Dig: Hashable {
        let question: String
        let options: [String]
        /// 選んだ答え -> 相棒の返事 (次の発見の種)
        let replies: [String: String]
    }

    let id: String
    let date: String          // 「10/21(水)」
    let hue: PartnerHue
    let rarity: Rarity
    let icon: String
    /// 1行の見出し (相棒の口調)
    let headline: String
    /// 2〜3行の本文 (日記の文)
    let body: String
    let viz: Viz
    let dig: Dig
    /// この理解度で届く
    let unlockAt: Int
    /// まだ届いていないときの予告 (伏せ字つき)
    let teaser: String
}

struct PartnerSwatch: Hashable {
    let name: String
    let color: Color
    let share: Double
}

struct PartnerGarmentMock: Hashable {
    enum Kind: Hashable { case top, bottom, outer, shoes }
    let kind: Kind
    let color: Color
    let name: String
}

enum PartnerDiscoveryCatalog {
    private static let black = Color(white: 0.12)
    private static let gray = Color(white: 0.62)
    private static let denim = Color(red: 0.30, green: 0.45, blue: 0.68)
    private static let orange = Color(red: 0.95, green: 0.50, blue: 0.15)
    private static let red = Color(red: 0.82, green: 0.18, blue: 0.20)
    private static let brown = Color(red: 0.50, green: 0.33, blue: 0.22)

    static let all: [PartnerDiscovery] = [
        .init(
            id: "hidden_color", date: "10/22(木)", hue: .pink, rarity: .rare, icon: "paintpalette",
            headline: "クローゼットはモノトーン。でも、いいねは色もの",
            body: "持ってる服の7割は黒・白・グレー。なのに「いいね」した案の半分は、ブルーやブラウンが入ってた。ほんとは色も着たいんじゃない？",
            viz: .compare("持ってる服の色もの", 0.33, "いいねした案の色もの", 0.5, unit: "%"),
            dig: .init(question: "色もの、本音はどう？",
                       options: ["着てみたい", "見るのが好きなだけ", "合わせ方がわからない"],
                       replies: [
                        "着てみたい": "やっぱり！まずは靴か小物で1色だけ入れてみよう。今週どこかで出すね",
                        "見るのが好きなだけ": "なるほど、眺める派ね。じゃあ提案はモノトーン中心のまま、色は1案だけにしておく",
                        "合わせ方がわからない": "それなら任せて。黒・白に足すならブラウンかネイビーが失敗しにくいよ",
                       ]),
            unlockAt: 25, teaser: "クローゼットと「いいね」に、ちょっとしたズレがあるみたい"),
        .init(
            id: "black_fast", date: "10/21(水)", hue: .lilac, rarity: .surprise, icon: "bolt",
            headline: "黒が入る案だと、決めるのが2倍速い",
            body: "黒が入った案は平均40秒で「着る」。入ってない案は1分半くらい迷ってた。黒はあなたの安心スイッチなのかも。",
            viz: .compare("黒あり", 40, "黒なし", 92, unit: "秒"),
            dig: .init(question: "朝、迷いたくない派？",
                       options: ["迷いたくない", "迷うのも楽しい"],
                       replies: [
                        "迷いたくない": "了解。平日の朝は、黒を軸にした案を1番上に置くね",
                        "迷うのも楽しい": "いいね。じゃあ週末は、黒を使わない冒険案も混ぜてみる",
                       ]),
            unlockAt: 30, teaser: "決めるのが速い日には、共通点があったよ"),
        .init(
            id: "friday", date: "10/20(火)", hue: .lemon, rarity: .surprise, icon: "sun.max",
            headline: "金曜だけ、ちょっと明るくなる",
            body: "月〜木は暗めの色がほとんど。でも金曜になると白やブルーが増える。週末が近いと気分が上がるタイプ？",
            viz: .weekday([0.15, 0.2, 0.1, 0.2, 0.7, 0.5, 0.4], highlight: 4),
            dig: .init(question: "金曜って、何かある日？",
                       options: ["予定が入りがち", "なんとなく気分", "気づかなかった"],
                       replies: [
                        "予定が入りがち": "なるほど！金曜は「ちょっと人に会う日」向けに組むね",
                        "なんとなく気分": "気分で色を変えられるの、いいね。金曜は明るい案を多めにする",
                        "気づかなかった": "でしょ？相棒だから気づけたやつ。これからも見ておくね",
                       ]),
            unlockAt: 45, teaser: "ある曜日だけ、色の選び方が変わるみたい"),
        .init(
            id: "denim_hero", date: "10/19(月)", hue: .sky, rarity: .normal, icon: "star",
            headline: "迷ったら、まずジーンズ",
            body: "主役を自分で選んだ5回のうち3回がブルーのジーンズ。上を替えて表情を変えるのがあなたの組み方みたい。",
            viz: .garments([
                .init(kind: .bottom, color: denim, name: "ジーンズ"),
                .init(kind: .top, color: .white, name: "白シャツ"),
                .init(kind: .top, color: black, name: "黒T"),
                .init(kind: .outer, color: gray, name: "パーカー"),
            ], caption: "ジーンズと組んだトップス"),
            dig: .init(question: "ジーンズ以外で主役にしたい服はある？",
                       options: ["チノパン", "スウェットパンツ", "ジーンズが一番"],
                       replies: [
                        "チノパン": "チノなら白シャツとの相性が抜群。次の主役候補に入れておくね",
                        "スウェットパンツ": "ラクな日の主役ね。休日の案で使ってみる",
                        "ジーンズが一番": "わかる、頼れる相棒だもんね。ジーンズの新しい合わせ方を探しておく",
                       ]),
            unlockAt: 40, teaser: "主役を選ぶときのクセが見えてきた"),
        .init(
            id: "cold_switch", date: "10/18(日)", hue: .mint, rarity: .surprise, icon: "thermometer.low",
            headline: "20℃を切ると、一気に黒が増える",
            body: "最高気温が20℃を下回った日は、黒の割合が3割から6割に。寒くなると色も冬支度するタイプだね。",
            viz: .compare("20℃以上の日の黒", 0.3, "20℃未満の日の黒", 0.6, unit: "%"),
            dig: .init(question: "寒い日に黒を選ぶのは？",
                       options: ["暖かく見えるから", "汚れが目立たないから", "なんとなく"],
                       replies: [
                        "暖かく見えるから": "なるほど。じゃあ寒い日はブラウンやネイビーも暖かく見えるから、たまに混ぜるね",
                        "汚れが目立たないから": "実用派！雨の日も黒多めにしておく",
                        "なんとなく": "無意識のクセって面白いよね。冬は黒以外の暖色も1案だけ入れてみる",
                       ]),
            unlockAt: 50, teaser: "気温で、色の選び方が変わる境目があった"),
        .init(
            id: "orange_area", date: "10/17(土)", hue: .peach, rarity: .normal, icon: "circle.lefthalf.filled",
            headline: "オレンジは嫌いじゃない。大きいと苦手なだけ",
            body: "オレンジのアウターが主役の案は見送り。でもオレンジの小物が入った案には「いいね」してた。面積の問題かも。",
            viz: .colorShare([
                .init(name: "小物で", color: orange, share: 0.8),
                .init(name: "主役で", color: orange.opacity(0.35), share: 0.2),
            ]),
            dig: .init(question: "オレンジ、どのくらいなら着られそう？",
                       options: ["小物ならOK", "インナーならOK", "やっぱり苦手"],
                       replies: [
                        "小物ならOK": "了解！オレンジは靴下やバッグくらいの面積にするね",
                        "インナーならOK": "羽織りの下からちらっと見せるのはアリね。覚えた",
                        "やっぱり苦手": "わかった、オレンジは提案から外しておく。正直に言ってくれてありがとう",
                       ]),
            unlockAt: 35, teaser: "苦手だと思ってた色、実は条件つきかも"),
        .init(
            id: "rotation", date: "10/16(金)", hue: .lilac, rarity: .rare, icon: "arrow.triangle.2.circlepath",
            headline: "パーカーは続けない、ジーンズは続けても平気",
            body: "パーカーは中3日あけて着てる。でもジーンズは3日続いても気にしてない。上は人の目、下は自分の楽さで選んでる？",
            viz: .compare("パーカーの間隔", 4, "ジーンズの間隔", 1, unit: "日"),
            dig: .init(question: "同じ服が続くの、気になる？",
                       options: ["上だけ気になる", "全部気になる", "気にしない"],
                       replies: [
                        "上だけ気になる": "やっぱり。トップスだけ連続しないように組むね",
                        "全部気になる": "了解、上下とも3日はあけるようにする",
                        "気にしない": "身軽でいいね。気に入った服は続けて出すよ",
                       ]),
            unlockAt: 62, teaser: "同じ服を着る間隔に、上下で差がある"),
        .init(
            id: "white_shirt", date: "10/15(木)", hue: .sky, rarity: .normal, icon: "crown",
            headline: "白シャツは「ちゃんとしたい日」担当",
            body: "白シャツを選んだ日は、カレンダーに予定がある日が多かった。本人より先に、服がスイッチを入れてるのかも。",
            viz: .garments([
                .init(kind: .top, color: .white, name: "白シャツ"),
                .init(kind: .bottom, color: brown, name: "チノ"),
                .init(kind: .shoes, color: brown, name: "スニーカー"),
            ], caption: "予定がある日のいつもの組み合わせ"),
            dig: .init(question: "大事な日の服、決まってる？",
                       options: ["だいたい白シャツ", "日によって違う"],
                       replies: [
                        "だいたい白シャツ": "勝負服だね。予定がある日は白シャツを軸にするね",
                        "日によって違う": "じゃあ予定の種類も覚えていくね。カレンダーに入れてくれると助かる",
                       ]),
            unlockAt: 70, teaser: "ある服を着る日には、決まった理由があるみたい"),
    ]
}

// MARK: - Sandbox の状態 (発見への返事)

@Observable
final class PartnerDiscoveryState {
    /// 発見 id -> 選んだ答え
    var answers: [String: String] = [:]
    /// めくった (読んだ) 発見
    var opened: Set<String> = []

    func discoveries(pct: Int) -> [PartnerDiscovery] {
        PartnerDiscoveryCatalog.all.filter { pct >= $0.unlockAt }
    }

    func upcoming(pct: Int) -> [PartnerDiscovery] {
        PartnerDiscoveryCatalog.all.filter { pct < $0.unlockAt }.sorted { $0.unlockAt < $1.unlockAt }
    }

    /// 進み具合のプリセットに合わせて、新しい2件以外は「読んで返事済み」にしておく
    func prefill(pct: Int) {
        answers = [:]
        opened = []
        for d in discoveries(pct: pct).dropFirst(2) {
            opened.insert(d.id)
            answers[d.id] = d.dig.options.first
        }
    }
}

// MARK: - 共通部品

/// 服のシルエット (Renewal の形を流用)
struct PartnerGarmentView: View {
    let garment: PartnerGarmentMock
    var size: CGFloat = 40

    var body: some View {
        let isLight = garment.color == .white
        let stroke = isLight ? RenewalTokens.controlBorder : Color.clear
        Group {
            switch garment.kind {
            case .top:
                Image(systemName: "tshirt.fill").resizable().scaledToFit()
                    .foregroundStyle(garment.color)
                    .overlay(Image(systemName: "tshirt").resizable().scaledToFit().foregroundStyle(stroke))
            case .bottom:
                RenewalPantsShape().fill(garment.color)
                    .overlay(RenewalPantsShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(0.72, contentMode: .fit)
            case .outer:
                RenewalCoatShape().fill(garment.color)
                    .overlay(RenewalCoatShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(0.85, contentMode: .fit)
            case .shoes:
                RenewalShoeShape().fill(garment.color)
                    .overlay(RenewalShoeShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(1.8, contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(garment.name)
    }
}

/// 発見の裏付けグラフ (小)
struct PartnerDiscoveryVizView: View {
    let viz: PartnerDiscovery.Viz
    let hue: PartnerHue

    var body: some View {
        switch viz {
        case .colorShare(let swatches):
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(swatches, id: \.self) { s in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(s.color)
                                .frame(width: max(8, geo.size.width * s.share - 2))
                        }
                    }
                }
                .frame(height: 16)
                HStack(spacing: 12) {
                    ForEach(swatches, id: \.self) { s in
                        Text("\(s.name) \(Int(s.share * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
            }
        case .weekday(let values, let highlight):
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(["月", "火", "水", "木", "金", "土", "日"].enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(i == highlight ? hue.ink : hue.mid)
                            .frame(width: 14, height: max(6, CGFloat(values[i]) * 44))
                        Text(d)
                            .font(.system(size: 10, weight: i == highlight ? .bold : .regular))
                            .foregroundStyle(i == highlight ? hue.ink : RenewalTokens.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64, alignment: .bottom)
        case .compare(let l, let lv, let r, let rv, let unit):
            let maxV = max(lv, rv)
            VStack(spacing: 8) {
                compareRow(l, lv, maxV, unit, strong: lv >= rv)
                compareRow(r, rv, maxV, unit, strong: rv > lv)
            }
        case .garments(let list, let caption):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ForEach(list, id: \.self) { g in
                        PartnerGarmentView(garment: g, size: 34)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(.white))
                    }
                }
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
    }

    private func compareRow(_ label: String, _ v: Double, _ maxV: Double, _ unit: String, strong: Bool) -> some View {
        let shown = unit == "%" ? "\(Int(v * 100))%" : "\(Int(v))\(unit)"
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 104, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                Capsule().fill(strong ? hue.ink : hue.mid)
                    .frame(width: max(8, geo.size.width * CGFloat(v / maxV)))
            }
            .frame(height: 8)
            Text(shown)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(strong ? hue.ink : RenewalTokens.muted)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

/// 深掘りの問いかけ (答えると相棒の返事が出る)
struct PartnerDigView: View {
    let discovery: PartnerDiscovery
    @Bindable var state: PartnerDiscoveryState
    var compact = false

    var body: some View {
        let answer = state.answers[discovery.id]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                PartnerIconImage(size: 26)
                Text(discovery.dig.question)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let answer {
                // あなたの答え (右) と相棒の返事 (左)
                HStack {
                    Spacer(minLength: 40)
                    Text(answer)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(discovery.hue.ink))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                if let reply = discovery.dig.replies[answer] {
                    HStack(alignment: .top, spacing: 8) {
                        PartnerIconImage(size: 26)
                        Text(reply)
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                                    .fill(.white)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    Label("相棒が覚えた", systemImage: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(discovery.hue.ink)
                        .padding(.leading, 34)
                }
            } else {
                PartnerFlowChips(spacing: 6) {
                    ForEach(discovery.dig.options, id: \.self) { o in
                        Button {
                            Haptic.impact(.soft)
                            withAnimation(.spring(duration: 0.4)) { state.answers[discovery.id] = o }
                        } label: {
                            Text(o)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(discovery.hue.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.white))
                                .overlay(Capsule().stroke(discovery.hue.mid, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 34)
            }
        }
    }
}

/// レア度のバッジ
struct PartnerRarityBadge: View {
    let rarity: PartnerDiscovery.Rarity
    let hue: PartnerHue
    var body: some View {
        HStack(spacing: 3) {
            if rarity != .normal {
                Image(systemName: rarity == .rare ? "sparkles" : "exclamationmark")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(rarity.rawValue)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(rarity == .normal ? hue.ink : .white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(rarity == .normal ? Color.white : hue.ink))
    }
}

/// 上部の小さな理解度 + 次のミッション (案A〜Dで共用)
struct PartnerUnderstandingStrip: View {
    @Bindable var store: PartnerProfileSandboxStore
    var onTapMissions: () -> Void

    var body: some View {
        let next = store.activeMissions.first
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(RenewalTokens.rule, lineWidth: 4)
                Circle().trim(from: 0, to: CGFloat(store.pct) / 100)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                PartnerIconImage(size: 40)
            }
            .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("理解度 \(store.pct)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(store.stage.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.muted)
                }
                if let next {
                    Text("次: \(next.title)  +\(next.points)%")
                        .font(.system(size: 11))
                        .foregroundStyle(RenewalTokens.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button {
                Haptic.impact(.soft)
                onTapMissions()
            } label: {
                Text("ミッション")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(RenewalTokens.primaryFill))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RenewalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .animation(.easeOut(duration: 0.4), value: store.pct)
    }
}
