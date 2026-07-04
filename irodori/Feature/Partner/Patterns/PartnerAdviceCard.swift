//
//  PartnerAdviceCard.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  「相棒からあなたへ」カード — 5パターン共通の追加要素。
//
//  ① 理解: あなたをこう見てる（根拠つき）
//  ② 提案: だから、こうしてみない？（理由つきで納得できる）
//  ③ 発見: それとね、こんな発見があった（本人も気づいていない一面）
//
//  の3段構成で、最後に「やってみる / 参考になった / 今はいいかな」の
//  フィードバックが相棒の学習に返るヒューマンインザループ。
//  自己完結コンポーネントなので、どのパターンにも1行で埋め込める。
//

import SwiftUI

struct PartnerAdviceCard: View {
    @State private var viewModel = PartnerAdviceCardViewModel()
    @State private var showStyleSheet = false
    @State private var showRegenerateConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if viewModel.isLoading || viewModel.isRegenerating {
                ProgressView(viewModel.isRegenerating ? "相棒が考え直してるよ…" : "")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if let advice = viewModel.advice {
                stepsTimeline(advice: advice)

                if let hint = advice.evidence_hint {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(hint)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.gray)
                }

                Divider()

                feedbackArea
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.35), .purple.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        .task {
            if viewModel.advice == nil {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $showStyleSheet) {
            SpeakingStyleSheet(
                response: viewModel.styleResponse,
                isSaving: viewModel.isSavingStyle,
                onSelect: { style in
                    Task {
                        if await viewModel.setStyle(style) {
                            showStyleSheet = false
                            ToastManager.shared.show("話し方を変更しました", style: .normal)
                        }
                    }
                },
                onClose: { showStyleSheet = false }
            )
        }
        .confirmationDialog("いまのコメントを作り直しますか？", isPresented: $showRegenerateConfirm, titleVisibility: .visible) {
            Button("作り直す") {
                Task { await viewModel.regenerate() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「相棒からあなたへ」を、もう一度生成します。")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(spacing: 10) {
            PartnerIconImage(size: 30)

            Text("相棒からあなたへ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            Spacer()

            // 再生成（作り直すかは確認ダイアログでユーザーが選ぶ）
            Button {
                Haptic.impact(.soft)
                showRegenerateConfirm = true
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.pink)
                    .padding(6)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(viewModel.isRegenerating)

            Button {
                Haptic.impact(.soft)
                Task { await viewModel.loadStyle() }
                showStyleSheet = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 10))
                    Text("話し方")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.pink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.pink.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - 理解 → 提案 → 発見 のタイムライン

    private func stepsTimeline(advice: PartnerAdvice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            adviceStep(
                icon: "hand.thumbsup.fill", color: .green, label: "いいところ",
                text: advice.good_point, isLast: false
            )
            adviceStep(
                icon: "exclamationmark.bubble.fill", color: .orange, label: "気になるところ",
                text: advice.concern, isLast: false
            )
            adviceStep(
                icon: "wand.and.stars", color: .pink, label: "ワンポイントアドバイス",
                text: advice.advice, isLast: true
            )
        }
    }

    private func adviceStep(icon: String, color: Color, label: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                }

                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineSpacing(4)
                    .padding(.bottom, isLast ? 0 : 18)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - フィードバック（HITL）

    private var feedbackArea: some View {
        Group {
            if let reply = viewModel.reply {
                HStack(alignment: .top, spacing: 8) {
                    PartnerIconImage(size: 24)

                    Text(reply)
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                        .lineSpacing(3)

                    Spacer()

                    if let exp = viewModel.expGained {
                        Text("+\(exp)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pink)
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(spacing: 8) {
                    feedbackButton(title: "やってみる", emoji: "💪", reaction: "try_it", color: .pink)
                    feedbackButton(title: "参考になった", emoji: "🤍", reaction: "helpful", color: .blue)
                    feedbackButton(title: "今はいいかな", emoji: "🌷", reaction: "not_for_me", color: .gray)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.reply)
    }

    private func feedbackButton(title: String, emoji: String, reaction: String, color: Color) -> some View {
        Button {
            Haptic.impact(.light)
            Task { await viewModel.sendFeedback(reaction) }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color == .gray ? .gray : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
        }
        .disabled(viewModel.isSending)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerAdviceCardViewModel {
    var advice: PartnerAdvice?
    var reply: String?
    var expGained: Int?
    var isLoading = false
    var isSending = false
    var styleResponse: PartnerSpeakingStyleResponse?
    var isSavingStyle = false
    var isRegenerating = false

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func regenerate() async {
        guard !isRegenerating else { return }
        isRegenerating = true
        defer { isRegenerating = false }
        if let result = try? await apiClient.regenerateAdvice(userId: PartnerPatternUtility.userId),
           case .success(let response) = result {
            advice = response.advice
            reply = nil
            expGained = nil
        }
    }

    func loadStyle() async {
        if let result = try? await apiClient.getSpeakingStyle(userId: PartnerPatternUtility.userId),
           case .success(let response) = result {
            styleResponse = response
        }
    }

    /// 話し方を保存してコメントを作り直す。成功可否を返す (呼び出し側でシートを閉じる判断に使う)
    @discardableResult
    func setStyle(_ style: String) async -> Bool {
        guard !isSavingStyle else { return false }
        isSavingStyle = true
        defer { isSavingStyle = false }
        if let result = try? await apiClient.setSpeakingStyle(userId: PartnerPatternUtility.userId, style: style),
           case .success(let response) = result {
            styleResponse = response
            // 話し方が変わったので「相棒からあなたへ」を取り直す
            advice = nil
            reply = nil
            expGained = nil
            await load()
            return true
        }
        ToastManager.shared.show("話し方の変更に失敗しました")
        return false
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await apiClient.getAdvice(userId: PartnerPatternUtility.userId)
            if case .success(let response) = result {
                advice = response.advice
            }
        } catch {
            // 表示できない場合はカードごと非表示（advice == nil のまま）
        }
    }

    func sendFeedback(_ reaction: String) async {
        guard let advice, !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            let result = try await apiClient.sendAdviceFeedback(
                userId: PartnerPatternUtility.userId,
                adviceId: advice.id,
                reaction: reaction
            )
            if case .success(let response) = result {
                Haptic.notify(.success)
                withAnimation {
                    reply = response.reply
                    expGained = response.exp_gained
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }
    }
}

// MARK: - 話し方を変えるシート

struct SpeakingStyleSheet: View {
    let response: PartnerSpeakingStyleResponse?
    let isSaving: Bool
    let onSelect: (String) -> Void
    let onClose: () -> Void

    @State private var customText = ""
    /// 選択中の話し方 (プリセット key または現在の設定値)。
    /// 選んだだけでは反映せず、下部の「この話し方にする」で確定する。
    @State private var selectedKey: String?

    private var trimmedCustom: String {
        customText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 適用対象: プリセット選択が優先。自由入力中 (selectedKey = nil) は入力テキスト
    private var effectiveStyle: String? {
        if let selectedKey { return selectedKey }
        return trimmedCustom.isEmpty ? nil : trimmedCustom
    }

    /// 現在の設定と同じ選択のままなら適用ボタンは無効
    private var canApply: Bool {
        guard let style = effectiveStyle, !style.isEmpty else { return false }
        return style != response?.speaking_style
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("相棒の話し方を選んで「この話し方にする」を押すと反映されます。")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)

                    if let presets = response?.presets {
                        VStack(spacing: 8) {
                            ForEach(presets) { option in
                                presetRow(option)
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("自由に決める")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                        TextField("例: 海賊みたいに / 落語家風に", text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customText) { _, newValue in
                                // 入力を始めたら自由入力を選択扱いにする (プリセット選択は解除)
                                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    selectedKey = nil
                                }
                            }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { applyBar }
            .navigationTitle("相棒の話し方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { onClose() }
                        .foregroundColor(.black)
                }
            }
            .onAppear {
                if selectedKey == nil, trimmedCustom.isEmpty {
                    selectedKey = response?.speaking_style
                }
            }
            .onChange(of: response?.speaking_style) { _, newValue in
                // プリセット読込が開いた後に届いた場合に現在値を選択状態にする
                if selectedKey == nil, trimmedCustom.isEmpty {
                    selectedKey = newValue
                }
            }
        }
    }

    private func presetRow(_ option: PartnerSpeakingStyleOption) -> some View {
        let isSelected = selectedKey == option.key
        return Button {
            Haptic.impact(.soft)
            selectedKey = option.key
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(option.text)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .pink : .gray.opacity(0.35))
            }
            .padding(14)
            .background(isSelected ? Color.pink.opacity(0.06) : Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.pink.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    // 下部固定の適用バー (選択しただけでは反映されないことを保証する唯一の確定導線)
    private var applyBar: some View {
        VStack(spacing: 10) {
            Divider()
            if isSaving {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("話し方を変えて、コメントを作り直してるよ…")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            Button {
                Haptic.impact(.medium)
                if let style = effectiveStyle { onSelect(style) }
            } label: {
                Text("この話し方にする")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canApply && !isSaving ? Color.pink : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
            }
            .disabled(!canApply || isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .background(.white)
    }
}

#Preview {
    ScrollView {
        PartnerAdviceCard()
            .padding(20)
    }
}
