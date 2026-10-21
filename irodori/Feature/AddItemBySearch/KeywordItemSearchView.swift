//
//  KeywordItemSearchView.swift
//  irodori
//
//  キーワードで服の画像を検索し (検索結果のWeb画面は出さず、画像だけを取得)、
//  ネイティブのグリッドに表示する。タップすると背景除去して登録画面を開く。
//

import SwiftUI

struct KeywordItemSearchView: View {
    /// 開いたらすぐ検索する語 (コーデの「似たアイテム」から開いたとき)
    var initialQuery: String? = nil

    @State private var viewModel = KeywordItemSearchViewModel()
    @State private var picked: SearchImageResult?
    @FocusState private var searchFocused: Bool
    @State private var didRunInitial = false

    /// 何を打てばよいか迷わないように、よく登録される定番を候補として並べる
    private let suggestions = ["白 Tシャツ", "黒 Tシャツ", "白 シャツ", "ネイビー ニット", "グレー スウェット",
                               "ブルー ジーンズ", "黒 スラックス", "ベージュ チノパン", "デニムジャケット",
                               "ネイビー カーディガン", "白 スニーカー", "黒 ローファー"]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
        }
        .navigationTitle("検索して追加")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didRunInitial, let q = initialQuery, !q.isEmpty else { return }
            didRunInitial = true
            viewModel.keyword = q
            await viewModel.search()
        }
        .background(Color.gray.opacity(0.05))
        .sheet(item: $picked) { result in
            SearchedItemRegisterView(
                viewModel: SearchedItemRegisterViewModel(
                    originalURL: result.originalURL,
                    thumbnailURL: result.thumbnailURL,
                    keyword: viewModel.keyword
                ),
                onRegistered: {
                    ToastManager.shared.show("アイテムを登録しました", style: .normal)
                }
            )
        }
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                TextField("例: 白いTシャツ / ワイドパンツ ネイビー", text: $viewModel.keyword)
                    .font(.system(size: 15))
                    .tint(.black)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { runSearch() }

                if !viewModel.keyword.isEmpty {
                    Button {
                        viewModel.keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )

            Text("Web上の画像を検索します。ご自身のクローゼット登録用にご利用ください。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
    }

    private func runSearch() {
        searchFocused = false
        Task { await viewModel.search() }
    }

    // MARK: - コンテンツ

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            VStack(spacing: 12) {
                ProgressView().tint(.black)
                Text("検索中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            messageView(icon: "magnifyingglass", text: error, showRetry: true)
        } else if viewModel.results.isEmpty && viewModel.hasSearched {
            messageView(icon: "tshirt", text: "画像が見つかりませんでした", showRetry: false)
        } else if viewModel.results.isEmpty {
            suggestionList
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.results) { result in
                        resultCell(result: result)
                    }
                }
                .padding(16)
            }
        }
    }

    /// 検索前: 定番のキーワードをタップで検索できるようにする
    private var suggestionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("よく登録される服")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                FlowChips(items: suggestions) { word in
                    viewModel.keyword = word
                    runSearch()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func resultCell(result: SearchImageResult) -> some View {
        Button {
            Haptic.impact(.soft)
            picked = result
        } label: {
            // 正方形セルは中身に依存しない Color.clear で確定させ、画像は overlay で
            // 敷き詰めて clip する。こうすると縦長・横長どの画像でもセルの縦横比が崩れない。
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(url: result.thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func messageView(icon: String, text: String, showRetry: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.35))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if showRetry {
                Button {
                    runSearch()
                } label: {
                    Text("再検索")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}



/// 折り返して並ぶチップ
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { word in
                Button { onTap(word) } label: {
                    Text(word)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 横に並べ、はみ出したら次の行へ送るレイアウト
private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
