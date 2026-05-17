//
//  FavoritesView.swift
//  irodori
//
//  お気に入りコーデ一覧画面. 自分のコーデ / おすすめコーデでタブ切替.
//  - pool タップ: DailyRecommendationDetailView を sheet で表示
//  - self タップ: CoordinateDetailView へ push
//

import SwiftUI
import Kingfisher

struct FavoritesView: View {
    @Binding var path: [ViewType]
    @Environment(FavoritesStore.self) private var store
    @State private var selectedKind: FavoriteKind = .pool
    @State private var isLoading: Bool = false
    @State private var presentedPoolItem: DailyRecommendationItem? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let dailyClient: DailyRecommendationClientProtocol

    init(path: Binding<[ViewType]>, dailyClient: DailyRecommendationClientProtocol = DailyRecommendationClient()) {
        self._path = path
        self.dailyClient = dailyClient
    }

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
        .sheet(item: $presentedPoolItem) { item in
            NavigationStack {
                DailyRecommendationDetailView(
                    item: item,
                    onWear: { item in await wear(item: item) }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { presentedPoolItem = nil }
                    }
                }
            }
        }
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
        Button {
            Haptic.impact(.soft)
            handleTap(fav)
        } label: {
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
                    .overlay(alignment: .bottomLeading) {
                        FavoriteToggleButton(isFavorite: true, size: 12, padding: 7) {
                            Task {
                                await store.toggle(
                                    kind: fav.kindEnum,
                                    targetId: fav.target_id,
                                    imageURL: fav.image_url,
                                    date: fav.date
                                )
                            }
                        }
                        .padding(6)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ fav: Favorite) {
        switch fav.kindEnum {
        case .pool:
            presentedPoolItem = DailyRecommendationItem(
                pool_id: fav.target_id,
                kind: "pool",
                image_url: fav.image_url ?? "",
                reason: nil,
                main_colors: [],
                items: [:],
                vibe: "",
                style: "",
                cleanliness: 3,
                is_favorite: true
            )
        case .self:
            path.append(.coordinateDetail(.init(
                coordinateId: fav.target_id,
                coordinateImageURL: fav.image_url ?? "",
                showHeader: true
            )))
        }
    }

    private func wear(item: DailyRecommendationItem) async -> Bool {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let today = formatter.string(from: Date())
        do {
            let result = try await dailyClient.markWorn(uid: uid, poolId: item.pool_id, wornDate: today)
            switch result {
            case .success: return true
            case .failure: return false
            }
        } catch {
            return false
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
        FavoritesView(path: .constant([]))
            .environment(FavoritesStore(client: MockFavoriteClient()))
    }
}
