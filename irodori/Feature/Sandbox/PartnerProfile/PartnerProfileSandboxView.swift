//
//  PartnerProfileSandboxView.swift
//  irodori - Sandbox
//
//  相棒画面の改善候補 (案A〜D) とレスポンス案を切り替えて見比べる入口。
//  上の「1日目／3日目／5日目／3週間」で、ユーザーの進み具合ごとの見え方を確認できる。
//

import SwiftUI

struct PartnerProfileSandboxView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case a = "A 日記"
        case b = "B カード"
        case c = "C 色と形"
        case d = "D 週報"
        case json = "JSON"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .a
    @State private var preset: PartnerProfileSandboxStore.Preset = .day3
    @State private var store = PartnerProfileSandboxStore(preset: .day3)
    @State private var discoveries = PartnerDiscoveryState()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("案", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("進み具合", selection: $preset) {
                    ForEach(PartnerProfileSandboxStore.Preset.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RenewalTokens.surface)
            Divider()

            Group {
                switch tab {
                case .a: PartnerProfileDesignA(store: store, discoveries: discoveries)
                case .b: PartnerProfileDesignB(store: store, discoveries: discoveries)
                case .c: PartnerProfileDesignC(store: store, discoveries: discoveries)
                case .d: PartnerProfileDesignD(store: store, discoveries: discoveries)
                case .json: PartnerProfileResponsePreview(store: store, discoveries: discoveries)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            if let m = store.lastCleared {
                PartnerMissionClearedToast(mission: m)
                    .padding(.top, 96)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: m.id) {
                        try? await Task.sleep(for: .seconds(1.8))
                        withAnimation { store.lastCleared = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: store.lastCleared)
        .onAppear {
            if discoveries.answers.isEmpty && discoveries.opened.isEmpty { discoveries.prefill(pct: store.pct) }
        }
        .navigationTitle("相棒画面の改善案")
        .navigationBarTitleDisplayMode(.inline)
        // 発見への返事はミッション (発見に返事する) にも数える
        .onChange(of: discoveries.answers.count) { _, n in
            let base = store.verdicts.count
            withAnimation {
                store.progress["trait_check_2"] = min(2, base + n)
                store.progress["trait_check_all"] = min(8, base + n)
            }
        }
        .onChange(of: preset) { _, p in
            withAnimation {
                store.apply(p)
                discoveries.prefill(pct: store.pct)
            }
        }
    }
}

// MARK: - レスポンス案 (今の Sandbox の状態をそのまま JSON にする)

struct PartnerProfileResponsePreview: View {
    let store: PartnerProfileSandboxStore
    let discoveries: PartnerDiscoveryState

    private static let hex: [String: [String]] = [
        "color_like": ["#121212", "#FFFFFF", "#9E9E9E"],
        "color_avoid": ["#F28026", "#D92633"],
    ]

    private var draft: PartnerProfileResponseDraft {
        let traits = PartnerTraitCatalog.all.map { t -> PartnerProfileResponseDraft.Trait in
            let open = store.pct >= t.unlockAt
            let status: String = {
                guard open else { return "locked" }
                switch store.verdicts[t.id] {
                case true?: return "confirmed"
                case false?: return "corrected"
                case nil: return "guess"
                }
            }()
            return .init(
                id: t.id,
                group: ["色": "color", "系統・形": "style", "癖": "habit", "クローゼット": "closet"][t.group.rawValue] ?? "habit",
                title: t.title,
                value: open ? t.value : nil,
                detail: open ? t.detail : nil,
                confidence: ["low", "mid", "high"][store.confidence(t) - 1],
                status: status,
                evidence: open ? t.evidence.map { .init(kind: "closet", text: $0) } : [],
                swatches: open ? Self.hex[t.id] : nil,
                meter: open ? t.meter.map { .init(left: $0.left, right: $0.right, value: $0.value) } : nil,
                unlock_hint: open ? nil : t.unlockHint
            )
        }
        let missions = PartnerMissionCatalog.all.map {
            PartnerProfileResponseDraft.Mission(
                id: $0.id, stage: $0.stage, title: $0.title, points: $0.points,
                current: store.current($0), target: $0.target, done: store.isDone($0),
                done_at: store.isDone($0) ? "2026-10-23T08:12:00+09:00" : nil, action: $0.action
            )
        }
        let remaining = store.activeMissions.count
        return .init(
            status: "success",
            understanding: .init(pct: store.pct, stage: store.stage, next_stage: store.nextStage, remaining_in_stage: remaining),
            summary: store.summary,
            traits: traits,
            discoveries: discoveryDrafts,
            missions: missions,
            unlocks: PartnerMissionCatalog.unlocks.map { .init(at_pct: $0.0, label: $0.1, unlocked: store.pct >= $0.0) },
            recently_cleared: store.lastCleared.map { [$0.id] } ?? []
        )
    }

    private var discoveryDrafts: [PartnerProfileResponseDraft.Discovery] {
        PartnerDiscoveryCatalog.all.map { d in
            let open = store.pct >= d.unlockAt
            let answer = discoveries.answers[d.id]
            let viz: PartnerProfileResponseDraft.Viz = {
                switch d.viz {
                case .colorShare(let s): return .init(type: "color_share", labels: s.map(\.name), values: s.map(\.share), unit: "%", item_ids: nil)
                case .weekday(let v, _): return .init(type: "weekday", labels: ["月", "火", "水", "木", "金", "土", "日"], values: v, unit: nil, item_ids: nil)
                case .compare(let l, let lv, let r, let rv, let unit): return .init(type: "compare", labels: [l, r], values: [lv, rv], unit: unit, item_ids: nil)
                case .garments(let g, _): return .init(type: "garments", labels: g.map(\.name), values: [], unit: nil, item_ids: g.map { _ in "<closet item id>" })
                }
            }()
            let status = !open ? "locked" : answer != nil ? "answered" : discoveries.opened.contains(d.id) ? "read" : "new"
            return .init(
                id: d.id, date: d.date, hue: d.hue.rawValue,
                rarity: ["発見": "normal", "意外": "surprise", "レア": "rare"][d.rarity.rawValue] ?? "normal",
                headline: open ? d.headline : nil, body: open ? d.body : nil,
                viz: open ? viz : nil,
                dig: open ? .init(question: d.dig.question, options: d.dig.options, answer: answer, reply: answer.flatMap { d.dig.replies[$0] }) : nil,
                unlock_at: d.unlockAt, teaser: d.teaser, status: status
            )
        }
    }

    private var json: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(draft) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                notes
                Text(json)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RenewalTokens.raised)
                    .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
            }
            .padding(16)
        }
        .background(RenewalTokens.surface)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GET /api/partner/{user_id}/profile")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            bullet("理解度はミッションの点数の合計 (満点100)。ミッションの達成は既存のデータ (服の数・owned_first_log・calendar_outfits・ログイン日数・写真) を読むたびに数え直す。新しく書き込むのは特徴の答え合わせだけ")
            bullet("既存の state.understanding_pct もこの値に置き換える (ホームのカードや見比べも同じ数字になる)。exp は履歴として残す")
            bullet("特徴は集計だけで出す。summary の一文だけ Gemini で1日1回作ってキャッシュ (flash で1人1日 約0.1円)")
            bullet("発見は毎日1件まで作る。候補は集計 (色の割合・曜日・気温・決めるまでの秒数・いいね/見送り) から「ふつうと差が大きいもの」を選び、見出しと本文と問いかけだけ Gemini で相棒の口調にする")
            bullet("返事: POST /api/partner/{user_id}/discoveries/{id}/answer  { \"answer\": \"着てみたい\" } → { reply, learned }。答えは提案の重みに反映し、理解度のミッション (見立てに返事) にも数える")
            bullet("週のふりかえり (案D) は discoveries の直近3件 + 数字1つ (例: 黒を選んだ回数) を週1回まとめるだけ。追加の生成はなし")
            bullet("recently_cleared は前回 profile を返したあとにクリアしたもの。iOS はお祝いのトーストに使う")
        }
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("・")
            Text(s).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .foregroundStyle(RenewalTokens.ink)
    }
}

#Preview {
    NavigationStack { PartnerProfileSandboxView() }
}
