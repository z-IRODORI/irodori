//
//  GuidedOnboardingSandboxView.swift
//  irodori - Sandbox
//
//  ウォークスルー型 + ツールチップ型のオンボーディングを確かめる入口。
//  本番の流れ: 初回起動 → ★ウォークスルー (3枚) → 4つの質問 → 相棒誕生 → ホーム (★ツールチップ)
//  「通しで」は 4つの質問と相棒誕生を1枚のつなぎで省略して、流れ全体を体験できる。
//

import SwiftUI

struct GuidedOnboardingSandboxView: View {
    enum Part: String, CaseIterable, Identifiable {
        case flow = "通しで"
        case walkthrough = "ウォークスルー"
        case tooltip = "ツールチップ"
        var id: String { rawValue }
    }

    enum Stage { case walkthrough, bridge, home }

    @State private var part: Part = .flow
    @State private var stage: Stage = .walkthrough
    @State private var tooltipMode: GuidedHomeTooltipView.Mode = .tour
    @State private var runID = 0

    private var showsModePicker: Bool {
        part == .tooltip || (part == .flow && stage == .home)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("見るもの", selection: $part) {
                    ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if showsModePicker {
                    Picker("出し方", selection: $tooltipMode) {
                        ForEach(GuidedHomeTooltipView.Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RenewalTokens.surface)
            Divider()

            content
                .id(runID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: showsModePicker)
        .onChange(of: part) { _, _ in restart() }
        .onChange(of: tooltipMode) { _, _ in runID += 1 }
        .navigationTitle("オンボーディング案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("最初から") { restart() }
                    .foregroundStyle(RenewalTokens.ink)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch part {
        case .walkthrough:
            GuidedWalkthroughView(onFinish: { restart() })
        case .tooltip:
            GuidedHomeTooltipView(mode: tooltipMode)
        case .flow:
            switch stage {
            case .walkthrough:
                GuidedWalkthroughView(onFinish: { withAnimation { stage = .bridge } })
                    .transition(.opacity)
            case .bridge:
                bridge.transition(.opacity)
            case .home:
                GuidedHomeTooltipView(mode: tooltipMode).transition(.opacity)
            }
        }
    }

    private var caption: String {
        switch part {
        case .flow:
            switch stage {
            case .walkthrough: return "初回起動。3枚で IRODORI と相棒を伝える (どのページからでもスキップ可)"
            case .bridge: return "4つの質問と相棒誕生は今のまま (ここでは省略)"
            case .home: return tooltipMode == .tour
                ? "初めてのホーム。4つを順に指す (暗くして1つずつ・スキップ可)"
                : "初めてのホーム。必要になった瞬間に1つずつ。スクロールや「着る」「ちょっと違う」を試してください"
            }
        case .walkthrough: return "最後のページの「4つの質問に答える」かスキップで、最初に戻ります"
        case .tooltip: return tooltipMode == .tour
            ? "来た直後に4つを順に。画面のどこを押しても次へ"
            : "来た直後は相棒のひとことだけ。相棒カードまでスクロール・「着る」・「ちょっと違う」で出ます"
        }
    }

    /// 4つの質問 → 相棒誕生 のつなぎ (Sandbox では省略)
    private var bridge: some View {
        VStack(spacing: 18) {
            PartnerIconImage(size: 96)
            Text("あなたの相棒が誕生しました")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
            Text("（4つの質問と誕生の画面は今のまま。ここでは省略しています）")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .multilineTextAlignment(.center)
            DataOnbPrimaryButton(title: "相棒とコーデを見てみる") {
                withAnimation { stage = .home }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RenewalTokens.ground)
    }

    private func restart() {
        stage = .walkthrough
        runID += 1
    }
}

#Preview {
    NavigationStack { GuidedOnboardingSandboxView() }
}
