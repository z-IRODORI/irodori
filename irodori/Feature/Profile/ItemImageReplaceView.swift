//
//  ItemImageReplaceView.swift
//  irodori
//
//  クローゼットの撮影切り抜きアイテムを、ネット検索の商品画像に差し替える画面。
//  シートのルート = 対象アイテムの一覧 (ItemImageReplaceListView)、
//  アイテムを選ぶと候補グリッド + 下部の確定バー (ItemImageReplaceView) をプッシュする。
//

import SwiftUI
import Kingfisher

// MARK: - 対象アイテムの一覧 (シートのルート)

struct ItemImageReplaceListView: View {
    /// 差し替え対象 (撮影切り抜き) のアイテム。親の一覧と連動して更新される
    let items: [ClosetItem]
    let onReplaced: (_ oldId: String, _ newItem: ClosetItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    completedState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("コーデ撮影から切り抜いたアイテムを、ネットのきれいな商品画像に差し替えられます。アイテムを選んでください。")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(items) { item in
                                    NavigationLink(value: item) {
                                        itemCell(item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("商品画像に差し替え")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ClosetItem.self) { item in
                ItemImageReplaceView(viewModel: .init(item: item), onReplaced: onReplaced)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func itemCell(_ item: ClosetItem) -> some View {
        VStack(spacing: 6) {
            KFImage(URL(string: item.image_url ?? ""))
                .resizable()
                .placeholder { Color.gray.opacity(0.1) }
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()
            VStack(spacing: 2) {
                Text(item.category ?? item.item_type)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.color ?? " ")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    /// 対象が無くなった状態 (全部差し替えた or もともと無い)
    private var completedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.black)
            Text("差し替えできるアイテムはありません")
                .font(.system(size: 15, weight: .semibold))
            Text("撮影切り抜きのままのアイテムはすべて商品画像になっています")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 候補選択 + 差し替え確定

struct ItemImageReplaceView: View {
    @State var viewModel: ItemImageReplaceViewModel
    let onReplaced: (_ oldId: String, _ newItem: ClosetItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                currentItemRow
                searchField
                resultsArea
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("画像をえらぶ")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if viewModel.selected != nil {
                applyBar
            }
        }
        .overlay {
            if viewModel.isApplying {
                applyingOverlay
            }
        }
        .task {
            if !viewModel.hasSearched {
                await viewModel.search()
            }
        }
    }

    // MARK: - いまの画像 (原本)

    private var currentItemRow: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: viewModel.item.image_url ?? ""))
                .resizable()
                .placeholder { Color.gray.opacity(0.1) }
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("いまの画像 (撮影切り抜き)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(ItemImageReplaceViewModel.defaultQuery(for: viewModel.item))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 検索ワード (編集して再検索できる)

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                TextField("検索ワード", text: $viewModel.query)
                    .font(.system(size: 14))
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await viewModel.search() }
            } label: {
                Text("検索")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .disabled(viewModel.isSearching)
        }
    }

    // MARK: - 候補グリッド / 状態

    @ViewBuilder
    private var resultsArea: some View {
        if viewModel.isSearching {
            VStack(spacing: 10) {
                ProgressView()
                Text("商品画像を探しています…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let message = viewModel.errorMessage {
            VStack(spacing: 10) {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await viewModel.search() }
                } label: {
                    Text("再検索する")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .underline()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if !viewModel.results.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("似ている画像をタップして選んでください")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.results) { result in
                        candidateCell(result)
                    }
                }
            }
        }
    }

    private func candidateCell(_ result: SearchImageResult) -> some View {
        let isSelected = viewModel.selected?.id == result.id
        return Button {
            Haptic.selection()
            viewModel.selected = isSelected ? nil : result
        } label: {
            Color.gray.opacity(0.06)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    KFImage(result.thumbnailURL)
                        .resizable()
                        .placeholder { Color.gray.opacity(0.1) }
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.black : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.black)
                            .background(Circle().fill(.white).padding(2))
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 差し替え確定バー (候補選択中のみ下部に出す)

    private var applyBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                compareThumb(url: URL(string: viewModel.item.image_url ?? ""))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                compareThumb(url: viewModel.selected?.thumbnailURL)
                Spacer(minLength: 8)
                Button {
                    Task { await apply() }
                } label: {
                    Text("差し替える")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isApplying)
            }
            Text("元の切り抜き画像は削除され、カテゴリなどの情報は引き継がれます")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .top) { Divider() }
    }

    private func compareThumb(url: URL?) -> some View {
        KFImage(url)
            .resizable()
            .placeholder { Color.gray.opacity(0.1) }
            .scaledToFill()
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

    private func apply() async {
        guard let newItem = await viewModel.applyReplacement() else { return }
        Haptic.notify(.success)
        ToastManager.shared.show("商品画像に差し替えました", style: .normal)
        onReplaced(viewModel.item.id, newItem)
        dismiss()
    }
}

// MARK: - Preview

#Preview("対象アイテム一覧") {
    ItemImageReplaceListView(
        items: [
            ClosetItem(id: "1", item_type: "トップス", category: "スウェット", color: "グレー",
                       image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", date: nil),
            ClosetItem(id: "2", item_type: "ボトムス", category: "デニム", color: "ブルー",
                       image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", date: nil),
        ],
        onReplaced: { _, _ in }
    )
}

#Preview("候補えらび") {
    NavigationStack {
        ItemImageReplaceView(
            viewModel: .init(
                item: ClosetItem(id: "1", item_type: "トップス", category: "スウェット", color: "グレー",
                                 image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg", date: nil),
                scraper: MockImageSearchScraper()
            ),
            onReplaced: { _, _ in }
        )
    }
}
