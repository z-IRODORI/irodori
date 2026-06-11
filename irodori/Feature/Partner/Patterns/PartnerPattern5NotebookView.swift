//
//  PartnerPattern5NotebookView.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  パターン⑤「あなた研究ノート」— 共同編集型
//
//  相棒があなたについての仮説（「あなたは◯◯説」）を立て、
//  あなたが「ある！/ ときどき / ちがう」で検証していく。
//  ふたりで作る「自分の取扱説明書」が増えていく、
//  自己理解にいちばん深く踏み込むヒューマンインザループ。
//

import SwiftUI

struct PartnerPattern5NotebookView: View {
    @State private var viewModel = PartnerPattern5ViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("ノートをひらいています...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        if let reply = viewModel.partnerReply {
                            PartnerTalkBubble(text: reply)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        PartnerAdviceCard()

                        hypothesesSection
                        notebookSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color(red: 0.99, green: 0.98, blue: 0.96))  // ノートらしい生成り色
        .partnerExpToast($viewModel.expGained)
        .task {
            if viewModel.hypotheses.isEmpty && viewModel.entries.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("あなた研究ノート")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)

                    Text("相棒とふたりで書く、自分の取扱説明書")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(viewModel.entries.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.pink)

                    Text("研究成果")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            }

            if let state = viewModel.state {
                HStack {
                    PartnerUnderstandingChip(state: state)
                    Spacer()
                }
            }
        }
    }

    // MARK: - 検証待ちの仮説

    private var hypothesesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)

                Text("検証まちの仮説")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }

            if viewModel.hypotheses.isEmpty {
                Text("いまは仮説を考え中… また明日のぞいてみて 🌿")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.hypotheses) { hypothesis in
                        hypothesisCard(hypothesis)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.hypotheses)
            }
        }
    }

    private func hypothesisCard(_ hypothesis: PartnerHypothesis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Text("仮説")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 6) {
                    Text(hypothesis.text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineSpacing(4)

                    if let hint = hypothesis.source_hint {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 9))
                            Text(hint)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.gray)
                    }
                }
            }

            HStack(spacing: 10) {
                verdictButton(title: "ある！", symbol: "circle", verdict: "yes", color: .green, hypothesis: hypothesis)
                verdictButton(title: "ときどき", symbol: "triangle", verdict: "sometimes", color: .orange, hypothesis: hypothesis)
                verdictButton(title: "ちがう", symbol: "xmark", verdict: "no", color: .gray, hypothesis: hypothesis)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private func verdictButton(title: String, symbol: String, verdict: String, color: Color, hypothesis: PartnerHypothesis) -> some View {
        Button {
            Haptic.impact(.light)
            Task { await viewModel.sendVerdict(hypothesis: hypothesis, verdict: verdict) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
        .disabled(viewModel.isSending)
    }

    // MARK: - 研究成果（ノート）

    private var notebookSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.pink)

                Text("これまでの研究成果")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                Text("\(viewModel.entries.count) 件")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            if viewModel.entries.isEmpty {
                VStack(spacing: 8) {
                    Text("📖")
                        .font(.system(size: 36))

                    Text("まだ白紙のノート。\n仮説に答えると、ここにあなたの「らしさ」が増えていくよ。")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.entries) { entry in
                        notebookEntryRow(entry)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.entries)
            }
        }
    }

    private func notebookEntryRow(_ entry: PartnerNotebookEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: verdictSymbol(entry.verdict))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(verdictColor(entry.verdict))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineSpacing(3)

                if let comment = entry.comment, !comment.isEmpty {
                    Text("メモ: \(comment)")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.gray)
                }

                Text(formatDate(entry.decided_at))
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(verdictColor(entry.verdict).opacity(0.2), lineWidth: 1)
        )
    }

    private func verdictSymbol(_ verdict: String) -> String {
        switch verdict {
        case "yes": return "circle"
        case "sometimes": return "triangle"
        case "no": return "xmark"
        default: return "circle"
        }
    }

    private func verdictColor(_ verdict: String) -> Color {
        switch verdict {
        case "yes": return .green
        case "sometimes": return .orange
        case "no": return .gray
        default: return .green
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let date else { return "" }

        let display = DateFormatter()
        display.locale = Locale(identifier: "ja_JP")
        display.dateFormat = "M月d日"
        return display.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerPattern5ViewModel {
    var hypotheses: [PartnerHypothesis] = []
    var entries: [PartnerNotebookEntry] = []
    var state: PartnerState?
    var partnerReply: String? = "最近のあなたを見て、こんな仮説を立てたんだ。ほんとのところ、どう？"
    var expGained: Int?
    var isLoading = false
    var isSending = false

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let userId = PartnerPatternUtility.userId

        async let hypothesesTask = try? apiClient.getHypotheses(userId: userId)
        async let notebookTask = try? apiClient.getNotebook(userId: userId)
        async let homeTask = try? apiClient.getHome(userId: userId)

        if case .success(let response) = await hypothesesTask {
            hypotheses = response.hypotheses
        }
        if case .success(let response) = await notebookTask {
            entries = response.entries
        }
        if case .success(let response) = await homeTask {
            state = response.state
        }
    }

    func sendVerdict(hypothesis: PartnerHypothesis, verdict: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            let result = try await apiClient.sendVerdict(
                userId: PartnerPatternUtility.userId,
                hypothesisId: hypothesis.id,
                verdict: verdict,
                comment: nil
            )
            if case .success(let response) = result {
                Haptic.notify(.success)
                withAnimation {
                    partnerReply = response.reply
                    expGained = response.exp_gained
                    state = response.state
                    hypotheses.removeAll { $0.id == hypothesis.id }
                    if let entry = response.notebook_entry {
                        entries.insert(entry, at: 0)
                    }
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }
    }
}

#Preview {
    PartnerPattern5NotebookView()
}
