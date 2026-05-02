//
//  HomeDesignC.swift
//  irodori - Sandbox
//
//  案C: 横スクロール chips 型
//  現状の構造を維持しつつ、2×2グリッドを1行の横スクロール chips に変更。
//  分析の直後にアクションを置くことで文脈を自然につなぐ。
//

import SwiftUI

struct HomeDesignC: View {
    @State private var viewModel = HomeViewModel(apiClient: MockHomeClient())
    @State private var showAllTags = false

    private let shortcuts: [(icon: String, label: String)] = [
        ("wand.and.stars",                    "コーデ提案して"),
        ("bubble.left.and.text.bubble.right", "質問させて"),
        ("arrow.2.squarepath",                "いつもと違うコーデ"),
        ("magnifyingglass",                   "服を探す"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.white)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // 直近のコーデ
                    RecentCoordinates(
                        recentCoordinates: viewModel.homeResponse.recent_coordinates,
                        isEditMode: false,
                        onToggleEditMode: {},
                        onDeleteRequest: { _ in }
                    )
                    .padding(.horizontal, -24)

                    // 分析 → chips をひとまとまりに
                    VStack(spacing: 16) {
                        analysisSection
                        shortcutChipsRow
                    }

                    // タグ
                    tagsSection

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .background(Color.gray.opacity(0.08))
        .task { await viewModel.onAppear() }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 20) {
                Spacer()
                Image(systemName: "calendar")
                Image(systemName: "questionmark.circle")
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
    }

    // MARK: - 分析セクション

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PartnerIconImage(size: 44)
                    .redacted(reason: viewModel.isLoadingAnalysis ? .placeholder : [])
                SpeechBubbleView(text: "これまでのコーデを分析しました")
                    .redacted(reason: viewModel.isLoadingAnalysis ? .placeholder : [])
            }
            if viewModel.isLoadingAnalysis {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !viewModel.recentCoordinateAnalysis.isEmpty {
                Text(.init(viewModel.recentCoordinateAnalysis))
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 横スクロール shortcuts chips

    private var shortcutChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shortcuts, id: \.label) { s in
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(s.label)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, -2)
    }

    // MARK: - タグ

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("これまでのタグ")
                    .font(.system(size: 20, weight: .bold))
                if let tags = viewModel.homeResponse.tags, tags.count > 8 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllTags.toggle() }
                    }) {
                        Text(showAllTags ? "閉じる" : "すべて見る")
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let tags = viewModel.homeResponse.tags, !tags.isEmpty {
                let displayed = showAllTags ? tags : Array(tags.prefix(8))
                TagsView(
                    tags: displayed,
                    tagTextColor: .black,
                    borderColor: .gray,
                    tagFont: .system(size: 14, weight: .regular)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("タグが存在しません")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("案C - 横スクロール chips 型") {
    HomeDesignC()
        .environment(MainTabViewModel())
}
