//
//  WebItemImagesRow.swift
//  irodori
//
//  アイテム1件に対して、ネット検索で見つけた「きれいな画像」を横並び10件で見せる行。
//  撮影画像の検出結果 (CoordinateReviewView) とクローゼットのアイテム
//  (ItemImageEditView) で共用する。
//
//  - ユーザーに見せる検索ワードは検出結果そのまま (例: "ホワイト コットン Tシャツ")
//  - 実際の検索クエリは「<検索ワード> ユニクロ」。ユニクロを付けると
//    白背景の公式商品画像が上位に来て、参考画像の質が大きく上がる。
//  - 取得は ImageSearchScraper (隠しWebView・バックエンド不要)。結果は
//    セッション内メモリにキャッシュし、同じワードの再表示では再検索しない。
//

import SwiftUI
import Observation

@MainActor
@Observable
final class WebItemImagesRowViewModel {
    let searchWord: String
    var results: [SearchImageResult] = []
    var isLoading = false
    var errorMessage: String?

    static let imageCount = 10

    /// 検索ワード → 結果のセッション内キャッシュ (画面再構築・再訪問での再検索防止)
    private static var cache: [String: [SearchImageResult]] = [:]

    private let scraper: ImageSearchScraping?
    private var hasLoaded = false

    // ImageSearchScraper は @MainActor のため、デフォルト引数(非分離で評価)では
    // 生成できない。nil を既定にし、@MainActor な load 本体で生成する。
    init(searchWord: String, scraper: ImageSearchScraping? = nil) {
        self.searchWord = searchWord
        self.scraper = scraper
    }

    /// 実際に投げる検索クエリ。「ユニクロ」を付けると白背景の公式商品画像が
    /// 上位に来て参考画像の質が上がる (ユーザーに見せるワードには付けない)。
    nonisolated static func searchQuery(for word: String) -> String {
        "\(word) ユニクロ"
    }

    /// 初回表示時のみ検索する (.task から呼ぶ)
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        let word = searchWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        if let cached = Self.cache[word] {
            results = cached
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let scraper = self.scraper ?? ImageSearchScraper()
            let found = try await scraper.search(
                keyword: Self.searchQuery(for: word),
                gender: nil,
                limit: Self.imageCount
            )
            results = found
            if found.isEmpty {
                errorMessage = ImageSearchError.noResults.errorDescription
            } else {
                Self.cache[word] = found
            }
        } catch {
            errorMessage = (error as? ImageSearchError)?.errorDescription ?? "検索に失敗しました"
        }
    }
}

struct WebItemImagesRow: View {
    @State private var viewModel: WebItemImagesRowViewModel
    private let typeLabel: String?

    /// 拡大プレビュー中の画像 (タップで原寸を確認できる)
    @State private var previewResult: SearchImageResult?

    init(searchWord: String, typeLabel: String? = nil, scraper: ImageSearchScraping? = nil) {
        _viewModel = State(initialValue: WebItemImagesRowViewModel(searchWord: searchWord, scraper: scraper))
        self.typeLabel = typeLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .task { await viewModel.loadIfNeeded() }
        .sheet(item: $previewResult) { result in
            WebImagePreviewSheet(result: result)
        }
    }

    // MARK: - ヘッダー (種類チップ + 検出結果ワード + キャプション)

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let typeLabel, !typeLabel.isEmpty {
                    Text(typeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                }
                Text(viewModel.searchWord)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text("ネットで見つけた参考画像")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 本体 (スケルトン / エラー / 画像横スクロール)

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            skeletonRow
        } else if let message = viewModel.errorMessage, viewModel.results.isEmpty {
            errorRow(message)
        } else if !viewModel.results.isEmpty {
            imagesRow
        }
    }

    private var imagesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.results) { result in
                    Button {
                        Haptic.impact(.soft)
                        previewResult = result
                    } label: {
                        thumbnailCard(result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func thumbnailCard(_ result: SearchImageResult) -> some View {
        CachedAsyncImage(url: result.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ProgressView()
            case .failure:
                placeholderIcon
            @unknown default:
                Color.gray.opacity(0.1)
            }
        }
        .frame(width: 110, height: 110)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 22))
            .foregroundStyle(Color.gray.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<WebItemImagesRowViewModel.imageCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 110, height: 110)
                }
            }
            .padding(.vertical, 2)
        }
        .disabled(true)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                Haptic.impact(.soft)
                Task { await viewModel.retry() }
            } label: {
                Text("リトライ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 拡大プレビュー

/// タップした画像を原寸で確認するシート。原寸の読み込みに失敗したらサムネで代替する。
struct WebImagePreviewSheet: View {
    let result: SearchImageResult
    @Environment(\.dismiss) private var dismiss
    @State private var useThumbnail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                CachedAsyncImage(url: useThumbnail ? result.thumbnailURL : result.originalURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .empty:
                        ProgressView().tint(.white)
                    case .failure:
                        if useThumbnail {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                Text("画像を読み込めませんでした")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Color.clear.onAppear { useThumbnail = true }
                        }
                    @unknown default:
                        Color.clear
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview("参考画像の行") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            WebItemImagesRow(
                searchWord: "ホワイト コットン Tシャツ",
                typeLabel: "トップス",
                scraper: MockImageSearchScraper()
            )
            WebItemImagesRow(
                searchWord: "ブルー デニム ジーンズ",
                typeLabel: "ボトムス",
                scraper: MockImageSearchScraper()
            )
        }
        .padding(24)
    }
    .background(.gray.opacity(0.08))
}
