//
//  PartnerPattern4TasteVoteView.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  パターン④「好みスワイプ」— 2択投票型
//
//  コーデ写真の2択に直感でタップするだけ。
//  写真を投稿しない日でも相棒に「好き」を教えられる、
//  最も低負荷なヒューマンインザループ。5票ごとに相棒の発見が届く。
//

import SwiftUI

struct PartnerPattern4TasteVoteView: View {
    @State private var viewModel = PartnerPattern4ViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("コーデを選んでいます...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    headerSection

                    if let pair = viewModel.currentPair {
                        pairSection(pair: pair)
                        bothOrNeitherSection
                        progressSection
                    } else {
                        finishedSection
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }

            // 相棒の発見オーバーレイ
            if let discovery = viewModel.discovery {
                discoveryOverlay(discovery)
            }
        }
        .background(Color.white)
        .partnerExpToast($viewModel.expGained)
        .task {
            if viewModel.pairs.isEmpty && !viewModel.isFinished {
                await viewModel.load()
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            PartnerTalkBubble(text: "直感でえらんでみて。どっちが今のあなたの気分？")

            HStack {
                if let state = viewModel.state {
                    PartnerUnderstandingChip(state: state)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.pink)
                    Text("これまで \(viewModel.votesTotal) 票")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - 2択ペア

    private func pairSection(pair: PartnerQuizPair) -> some View {
        HStack(spacing: 12) {
            voteCard(outfit: pair.left, side: "left")
            voteCard(outfit: pair.right, side: "right")
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: pair.id)
    }

    private func voteCard(outfit: PartnerQuizOutfit, side: String) -> some View {
        Button {
            Haptic.impact(.medium)
            Task { await viewModel.vote(choice: side) }
        } label: {
            ZStack {
                CachedAsyncImage(url: URL(string: outfit.image_url)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.08)
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // 選択時のハートオーバーレイ
                if viewModel.selectedSide == side {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.pink.opacity(0.25))

                    Image(systemName: "heart.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                        .shadow(color: .pink.opacity(0.6), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(viewModel.selectedSide == side ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.selectedSide)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isVoting)
    }

    // MARK: - どっちも / どちらでもない

    private var bothOrNeitherSection: some View {
        HStack(spacing: 12) {
            Button {
                Haptic.impact(.light)
                Task { await viewModel.vote(choice: "both") }
            } label: {
                Label("どっちも好き", systemImage: "heart.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.pink.opacity(0.08))
                    .clipShape(Capsule())
            }
            .disabled(viewModel.isVoting)

            Button {
                Haptic.impact(.light)
                Task { await viewModel.vote(choice: "neither") }
            } label: {
                Label("どっちもちがう", systemImage: "arrow.uturn.right.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(Capsule())
            }
            .disabled(viewModel.isVoting)
        }
    }

    // MARK: - 進捗

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<viewModel.totalPairCount, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.answeredCount ? Color.pink : Color.gray.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            Text(viewModel.votesUntilDiscovery > 0
                 ? "あと \(viewModel.votesUntilDiscovery) 票で相棒の発見が聞ける"
                 : "発見がとどいたよ！")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.top, 4)
    }

    // MARK: - 発見オーバーレイ

    private func discoveryOverlay(_ discovery: String) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissDiscovery() }

            VStack(spacing: 18) {
                Text("💡")
                    .font(.system(size: 50))

                Text("相棒の発見")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)

                Text(discovery)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)

                Button {
                    Haptic.impact(.light)
                    viewModel.dismissDiscovery()
                } label: {
                    Text("つづける")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.pink)
                        .clipShape(Capsule())
                }
            }
            .padding(28)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 36)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.discovery)
    }

    // MARK: - 完了

    private var finishedSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 56))
                    .padding(.top, 16)

                Text("今日のぶんはおしまい！")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.black)

                Text("あなたの「好き」、ちゃんと受け取ったよ。\n投票はぜんぶ、明日からの提案に活きていくからね。")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)

                Button {
                    Haptic.impact(.light)
                    Task { await viewModel.load() }
                } label: {
                    Label("もうすこしあそぶ", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(Color.black)
                        .clipShape(Capsule())
                }

                PartnerAdviceCard()
                    .padding(.top, 8)
            }
            .padding(.bottom, 80)
        }
        .transition(.opacity)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerPattern4ViewModel {
    var pairs: [PartnerQuizPair] = []
    var state: PartnerState?
    var votesTotal = 0
    var totalPairCount = 5
    var answeredCount = 0
    var selectedSide: String?
    var discovery: String?
    var expGained: Int?
    var isLoading = false
    var isVoting = false
    var isFinished = false

    var currentPair: PartnerQuizPair? { pairs.first }

    var votesUntilDiscovery: Int {
        let remainder = votesTotal % 5
        return remainder == 0 ? 5 : 5 - remainder
    }

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        isFinished = false
        answeredCount = 0
        defer { isLoading = false }

        let userId = PartnerPatternUtility.userId

        async let quizTask = try? apiClient.getStyleQuiz(
            userId: userId,
            gender: PartnerPatternUtility.apiGender,
            pairs: 5
        )
        async let homeTask = try? apiClient.getHome(userId: userId)

        if case .success(let response) = await quizTask {
            pairs = response.pairs
            votesTotal = response.votes_total
            totalPairCount = max(response.pairs.count, 1)
            isFinished = pairs.isEmpty
        }
        if case .success(let response) = await homeTask {
            state = response.state
        }
    }

    func vote(choice: String) async {
        guard let pair = currentPair, !isVoting else { return }
        isVoting = true
        selectedSide = (choice == "left" || choice == "right") ? choice : nil

        do {
            let result = try await apiClient.voteStyleQuiz(
                userId: PartnerPatternUtility.userId,
                pairId: pair.pair_id,
                choice: choice,
                leftPoolId: pair.left.pool_id,
                rightPoolId: pair.right.pool_id
            )
            if case .success(let response) = result {
                // 選択演出を見せてから次のペアへ
                try? await Task.sleep(nanoseconds: 450_000_000)

                withAnimation {
                    votesTotal = response.votes_total
                    state = response.state
                    expGained = response.exp_gained
                    answeredCount += 1
                    pairs.removeFirst()
                    if pairs.isEmpty {
                        isFinished = true
                    }
                }

                if let found = response.discovery {
                    Haptic.notify(.success)
                    withAnimation {
                        discovery = found
                    }
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }

        selectedSide = nil
        isVoting = false
    }

    func dismissDiscovery() {
        withAnimation {
            discovery = nil
        }
    }
}

#Preview {
    PartnerPattern4TasteVoteView()
}
