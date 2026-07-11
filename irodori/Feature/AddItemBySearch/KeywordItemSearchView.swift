//
//  KeywordItemSearchView.swift
//  irodori
//
//  キーワードで服の画像を検索し (検索結果のWeb画面は出さず、画像だけを取得)、
//  ネイティブのグリッドに表示する。タップすると背景除去して登録画面を開く。
//

import SwiftUI

struct KeywordItemSearchView: View {
    @State private var viewModel = KeywordItemSearchViewModel()
    @State private var picked: SearchImageResult?
    @FocusState private var searchFocused: Bool

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
        } else if viewModel.results.isEmpty {
            messageView(
                icon: "tshirt",
                text: viewModel.hasSearched ? "画像が見つかりませんでした" : "キーワードを入力して、登録したい服の画像を探しましょう",
                showRetry: false
            )
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

    private func resultCell(result: SearchImageResult) -> some View {
        Button {
            Haptic.impact(.soft)
            picked = result
        } label: {
            CachedAsyncImage(url: result.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.12)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()
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

