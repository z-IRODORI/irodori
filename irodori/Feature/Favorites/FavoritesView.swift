//
//  FavoritesView.swift
//  irodori
//
//  お気に入りコーデ一覧画面. 自分のコーデ / おすすめコーデでタブ切替.
//

import SwiftUI
import Kingfisher

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var store
    @State private var selectedKind: FavoriteKind = .pool
    @State private var isLoading: Bool = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedKind) {
                ForEach(FavoriteKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white)

            content
        }
        .background(Color.gray.opacity(0.06))
        .navigationTitle("お気に入り")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshIfNeeded() }
        .refreshable { await store.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        let items = store.filtered(kind: selectedKind)
        if isLoading && items.isEmpty {
            ProgressView().padding(.top, 40)
        } else if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { fav in
                        gridCell(fav)
                    }
                }
                .padding(16)
            }
        }
    }

    private func gridCell(_ fav: Favorite) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.gray.opacity(0.15)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let url = fav.image_url, let u = URL(string: url) {
                        KFImage(u)
                            .resizable()
                            .placeholder { Color.gray.opacity(0.15) }
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

            FavoriteToggleButton(isFavorite: true, size: 13, padding: 7) {
                Task {
                    await store.toggle(
                        kind: fav.kindEnum,
                        targetId: fav.target_id,
                        imageURL: fav.image_url
                    )
                }
            }
            .padding(6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 32))
                .foregroundStyle(.gray.opacity(0.5))
            Text(selectedKind == .pool
                 ? "気になるおすすめコーデを♡してみましょう"
                 : "自分のコーデを♡しておくと明日の提案に混ざります")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshIfNeeded() async {
        guard store.favorites.isEmpty else { return }
        isLoading = true
        await store.refresh()
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environment(FavoritesStore(client: MockFavoriteClient()))
    }
}
