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
//  replaceContext を渡すと「タップで商品画像に差し替え」モードになり、
//  拡大プレビューに差し替え CTA が付く (クローゼットの撮影切り抜きアイテム用)。
//  10件で気に入るものが無いときは行末の「検索して探す」タイルから
//  検索ワードを変えられる画面 (ItemImageReplaceView) へ進める。
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

/// 「タップで商品画像に差し替え」モードの設定。
/// クローゼットのアイテム (ClosetItem) を対象に、選んだ画像で差し替えて onReplaced を呼ぶ。
struct WebItemImagesReplaceContext {
    let item: ClosetItem
    /// 差し替え時の注意書きに追記する文言 (例: 編集中の内容は反映されない旨)
    var extraWarning: String? = nil
    let onReplaced: (_ oldId: String, _ newItem: ClosetItem) -> Void
}

struct WebItemImagesRow: View {
    @State private var viewModel: WebItemImagesRowViewModel
    private let typeLabel: String?
    /// 非 nil のとき、拡大プレビューから商品画像への差し替えができる
    private let replaceContext: WebItemImagesReplaceContext?
    /// 非 nil のとき、行末に「検索して探す」タイルを出す (検索ワードを変えたい時の導線)
    private let onSearchMore: (() -> Void)?

    /// 拡大プレビュー中の画像 (タップで原寸を確認できる)
    @State private var previewResult: SearchImageResult?

    init(
        searchWord: String,
        typeLabel: String? = nil,
        replaceContext: WebItemImagesReplaceContext? = nil,
        onSearchMore: (() -> Void)? = nil,
        scraper: ImageSearchScraping? = nil
    ) {
        _viewModel = State(initialValue: WebItemImagesRowViewModel(searchWord: searchWord, scraper: scraper))
        self.typeLabel = typeLabel
        self.replaceContext = replaceContext
        self.onSearchMore = onSearchMore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .task { await viewModel.loadIfNeeded() }
        .sheet(item: $previewResult) { result in
            WebImagePreviewSheet(result: result, replaceContext: replaceContext)
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
            Text(replaceContext != nil
                 ? "タップして選ぶと、商品画像に差し替えられます"
                 : "ネットで見つけた参考画像")
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
                if let onSearchMore {
                    searchMoreTile(onSearchMore)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// 10件で気に入るものが無いとき、検索ワードを変えて探せる画面への導線
    private func searchMoreTile(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                Text("検索して探す")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(width: 110, height: 110)
            .background(Color.gray.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
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
/// replaceContext があるときは、下部に「この画像に差し替える」バーを出す。
struct WebImagePreviewSheet: View {
    let result: SearchImageResult
    var replaceContext: WebItemImagesReplaceContext? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var useThumbnail = false
    @State private var isApplying = false

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
                        .disabled(isApplying)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if let context = replaceContext {
                    replaceBar(context)
                }
            }
            .overlay {
                if isApplying {
                    applyingOverlay
                }
            }
        }
        .interactiveDismissDisabled(isApplying)
    }

    // MARK: - 差し替えバー

    /// 「いまの画像 → この画像」の比較と差し替え CTA
    private func replaceBar(_ context: WebItemImagesReplaceContext) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                compareThumb(url: URL(string: context.item.image_url ?? ""))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                compareThumb(url: result.thumbnailURL)
                Spacer(minLength: 8)
                Button {
                    Haptic.impact(.medium)
                    Task { await apply(context) }
                } label: {
                    Text("この画像に差し替える")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isApplying)
            }
            Text(noteText(context))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.white)
    }

    private func noteText(_ context: WebItemImagesReplaceContext) -> String {
        var note = "元の画像は削除され、カテゴリなどの情報は引き継がれます"
        if let warning = context.extraWarning {
            note += "。\(warning)"
        }
        return note
    }

    private func compareThumb(url: URL?) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Color.gray.opacity(0.1)
            }
        }
        .frame(width: 44, height: 44)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
    }

    private var applyingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.3)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("差し替えています…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(Color.black.opacity(0.7))
            .cornerRadius(14)
        }
    }

    /// 差し替え実行: 処理は ItemImageReplaceViewModel (検索画面と同じ) を再利用する
    private func apply(_ context: WebItemImagesReplaceContext) async {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        let replacer = ItemImageReplaceViewModel(item: context.item)
        guard let newItem = await replacer.applyReplacement(result) else { return }
        Haptic.notify(.success)
        ToastManager.shared.show("商品画像に差し替えました", style: .normal)
        context.onReplaced(context.item.id, newItem)
        dismiss()
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

#Preview("差し替えモード (クローゼット編集)") {
    ScrollView {
        WebItemImagesRow(
            searchWord: "グレー スウェット",
            typeLabel: "トップス",
            replaceContext: .init(
                item: ClosetItem(
                    id: "1", item_type: "トップス", category: "スウェット", color: "グレー",
                    image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg",
                    date: nil
                ),
                extraWarning: "いまの編集内容は反映されません",
                onReplaced: { _, _ in }
            ),
            onSearchMore: {},
            scraper: MockImageSearchScraper()
        )
        .padding(24)
    }
    .background(.gray.opacity(0.08))
}
