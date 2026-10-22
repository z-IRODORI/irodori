//
//  PartnerProfileSandboxView.swift
//  irodori - Sandbox
//
//  相棒画面の改善候補 (案A/B/C) とレスポンス案を切り替えて見比べる入口。
//  上の「1日目／3日目／5日目／3週間」で、ユーザーの進み具合ごとの見え方を確認できる。
//

import SwiftUI

struct PartnerProfileSandboxView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case a = "A カルテ"
        case b = "B 実績"
        case c = "C 見立て"
        case json = "レスポンス"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .a
    @State private var preset: PartnerProfileSandboxStore.Preset = .day3
    @State private var store = PartnerProfileSandboxStore(preset: .day3)

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
                case .a: PartnerProfileDesignA(store: store)
                case .b: PartnerProfileDesignB(store: store)
                case .c: PartnerProfileDesignC(store: store)
                case .json: PartnerProfileResponsePreview(store: store)
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
        .navigationTitle("相棒画面の改善案")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preset) { _, p in
            withAnimation { store.apply(p) }
        }
    }
}

// MARK: - レスポンス案 (今の Sandbox の状態をそのまま JSON にする)

struct PartnerProfileResponsePreview: View {
    let store: PartnerProfileSandboxStore

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
            missions: missions,
            unlocks: PartnerMissionCatalog.unlocks.map { .init(at_pct: $0.0, label: $0.1, unlocked: store.pct >= $0.0) },
            recently_cleared: store.lastCleared.map { [$0.id] } ?? []
        )
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
            bullet("答え合わせ: POST /api/partner/{user_id}/traits/{trait_id}/feedback  { \"verdict\": \"agree\" | \"disagree\", \"note\": \"...\" }。disagree は提案の重みを下げ、status を corrected に")
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
