//
//  DataOnboardingSandboxView.swift
//  irodori - Sandbox
//
//  「相棒誕生」のあと・ホームの前に挟むオンボーディングの案 A〜D を見比べる入口。
//  流れ: 4つの質問 → 相棒誕生 (「相棒とコーデを見てみる」) → ★この画面 → ホーム
//  教え方を選ぶと、本番で開く画面名と「記録がひとつ増えた」トーストを出す (実際の画面は開かない)。
//

import SwiftUI

struct DataOnboardingSandboxView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case a = "A 手帳"
        case b = "B 会話"
        case c = "C 見くらべ"
        case d = "D 3日"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .a
    @State private var state = DataOnbSandboxState()
    /// 案を切り替えたり最初からにするたびに、案の画面を作り直す
    @State private var runID = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Picker("案", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RenewalTokens.surface)
            Divider()

            ZStack {
                Group {
                    switch tab {
                    case .a: DataOnboardingDesignA(state: state)
                    case .b: DataOnboardingDesignB(state: state)
                    case .c: DataOnboardingDesignC(state: state)
                    case .d: DataOnboardingDesignD(state: state)
                    }
                }
                .id(runID)

                if state.finished { finishedCover }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            if let c = state.lastPicked {
                DataOnbPickedToast(channel: c)
                    .padding(.top, 84)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: state.picked.count) {
                        try? await Task.sleep(for: .seconds(3.2))
                        withAnimation { state.lastPicked = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: state.lastPicked)
        .animation(.easeInOut(duration: 0.25), value: state.finished)
        .onChange(of: tab) { _, _ in restart() }
        .navigationTitle("誕生後のオンボーディング案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("最初から") { restart() }
                    .foregroundStyle(RenewalTokens.ink)
            }
        }
    }

    private var summary: String {
        switch tab {
        case .a: return "3枚のページで順に伝える。手帳の空欄 → 3案の変化 → 教え方"
        case .b: return "相棒と会話しながら進む。知りたい順に答えが返ってくる"
        case .c: return "1画面。つまみで3案の変化を自分で確かめてから教える"
        case .d: return "最初の3日でやることを3つだけ。済むとスタンプが押される"
        }
    }

    private func restart() {
        state.reset()
        runID += 1
    }

    /// 「ホームへ」を押したあと (Sandbox ではホームに行かず、ここで止める)
    private var finishedCover: some View {
        VStack(spacing: 14) {
            Image(systemName: "house")
                .font(.system(size: 28))
                .foregroundStyle(RenewalTokens.ink)
            Text("ここでホームへ")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
            Text(state.picked.isEmpty
                 ? "教えずに進んだ場合。ホームの「相棒があなたのことを知りたがっています」から、いつでも教えられます"
                 : "教えた方法: \(state.picked.map(\.title).joined(separator: "・"))")
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("最初から見る") { restart() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .frame(minHeight: 44)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RenewalTokens.ground)
        .transition(.opacity)
    }
}

#Preview {
    NavigationStack { DataOnboardingSandboxView() }
}
