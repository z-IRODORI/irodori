//
//  HomeDesignB.swift
//  irodori - Sandbox
//
//  案B: 今日起点フィード型
//  「明日のコーデ」バナーを頂点に置き、毎日開くモチベーションを作る構成。
//  ショートカットを排除し、1アクションに集中させる。
//

import SwiftUI

struct HomeDesignB: View {
    @State private var viewModel = HomeViewModel(apiClient: MockHomeClient())

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.white)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // 明日のコーデバナー
                    tomorrowBanner
                        .padding(.horizontal, 24)

                    // 直近のコーデ
                    recentSection

                    // 相棒のひとこと
                    partnerComment
                        .padding(.horizontal, 24)

                    // タグ
                    tagsSection
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 60)
                }
                .padding(.top, 20)
            }
        }
        .background(Color.gray.opacity(0.08))
        .task { await viewModel.onAppear() }
    }

    // MARK: - Header（日付付き）

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayString)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("ホーム")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
            }
            Spacer()
            HStack(spacing: 16) {
                Image(systemName: "calendar")
                Image(systemName: "questionmark.circle")
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
    }

    // MARK: - 明日のコーデ バナー

    private var tomorrowBanner: some View {
        Button(action: {}) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("明日のコーデを提案します")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("過去のアイテムから相棒がスタイリング")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 直近のコーデ

    private var recentSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("直近のコーデ")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)

            if viewModel.homeResponse.recent_coordinates.isEmpty {
                Text("コーデが存在しません...")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 12)
                        ForEach(viewModel.homeResponse.recent_coordinates, id: \.id) { coord in
                            VStack(spacing: 0) {
                                CachedAsyncImage(url: URL(string: coord.image_url)!) { phase in
                                    if let img = phase.image { img.resizable() }
                                    else { Color.gray.opacity(0.2) }
                                }
                                .aspectRatio(3/4, contentMode: .fit)
                                .frame(width: 110)
                                Text(coord.date)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer().frame(width: 12)
                    }
                }
            }
        }
    }

    // MARK: - 相棒のひとこと（ミニマル）

    private var partnerComment: some View {
        HStack(alignment: .top, spacing: 12) {
            PartnerIconImage(size: 36)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("相棒より")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if viewModel.isLoadingAnalysis {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)).frame(height: 13)
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)).frame(width: 160, height: 13).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(.init(viewModel.recentCoordinateAnalysis.isEmpty
                        ? "コーデが登録されると分析が表示されます。"
                        : String(viewModel.recentCoordinateAnalysis.prefix(80)) + (viewModel.recentCoordinateAnalysis.count > 80 ? "…" : "")))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - タグ

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("これまでのタグ")
                .font(.system(size: 20, weight: .bold))
            if let tags = viewModel.homeResponse.tags, !tags.isEmpty {
                TagsView(
                    tags: Array(tags.prefix(8)),
                    tagTextColor: .black,
                    borderColor: .gray,
                    tagFont: .system(size: 14, weight: .regular)
                )
            } else {
                Text("タグが存在しません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("案B - 今日起点フィード型") {
    HomeDesignB()
        .environment(MainTabViewModel())
}
