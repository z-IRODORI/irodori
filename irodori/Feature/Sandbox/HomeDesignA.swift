//
//  HomeDesignA.swift
//  irodori - Sandbox
//
//  案A: 相棒カード統合型
//  AI関連要素（分析 + ショートカット）を1枚のカードにまとめ、
//  「なぜこのアクションを取るか」が自然に伝わる構成。
//

import SwiftUI

struct HomeDesignA: View {
    @State private var viewModel = HomeViewModel(apiClient: MockHomeClient())

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.white)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    RecentCoordinates(
                        recentCoordinates: viewModel.homeResponse.recent_coordinates,
                        isEditMode: false,
                        onToggleEditMode: {},
                        onDeleteRequest: { _ in }
                    )
                    .padding(.horizontal, -24)

//                    accessSection

                    partnerCard

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

    // MARK: - アクセスセクション

    private var accessSection: some View {
        HStack(spacing: 12) {
            // コーデを追加（プライマリ）
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("コーデを追加")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("新しい写真を登録")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // クローゼット（セカンダリ）
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("クローゼット")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                        Text("登録済みアイテム")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }

    // MARK: - 相棒カード（統合）

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 上部：アイコン + ラベル
            HStack(spacing: 10) {
                PartnerIconImage(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今週のあなたへ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("相棒からのメッセージ")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                Spacer()
            }
            .padding(.bottom, 14)

            // 分析テキスト
            if viewModel.isLoadingAnalysis {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 200, height: 14).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(.init(viewModel.recentCoordinateAnalysis.isEmpty
                    ? "コーデが登録されると分析が表示されます。"
                    : viewModel.recentCoordinateAnalysis))
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
            }

            Divider().padding(.vertical, 16)

            // アクションボタン（2つに絞る）
            HStack(spacing: 10) {
                Button(action: {}) {
                    Label("コーデ提案して", systemImage: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button(action: {}) {
                    Label("質問する", systemImage: "bubble.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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

#Preview("案A - 相棒カード統合型") {
    HomeDesignA()
        .environment(MainTabViewModel())
}
