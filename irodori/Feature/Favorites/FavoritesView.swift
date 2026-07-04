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
    @State private var isLoadingPool: Bool = false
    /// この画面で表示する一覧のスナップショット。
    /// お気に入り解除してもセルは消さず、ハート状態 (store) だけ切り替える。
    /// 一覧との再同期は pull-to-refresh または画面の開き直しで行う。
    @State private var displayed: [Favorite] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let dailyClient: DailyRecommendationClientProtocol
    private let poolClient: RecommendationPoolClientProtocol

    init(
        path: Binding<[ViewType]>,
        dailyClient: DailyRecommendationClientProtocol = DailyRecommendationClient(),
        poolClient: RecommendationPoolClientProtocol = RecommendationPoolClient()
    ) {
        self._path = path
        self.dailyClient = dailyClient
        self.poolClient = poolClient
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
        .task {
            await refreshIfNeeded()
            displayed = store.favorites
        }
        .refreshable {
            await store.refresh()
            displayed = store.favorites
        }
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
        .overlay {
            if isLoadingPool {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let items = displayed.filter { $0.kindEnum == selectedKind }
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
        // カード全体を Button にすると内側のハート Button のタップが奪われるため、
        // 画像に直接 onTapGesture を割り当て、ハートは独立した Button のままにする.
        let isFav = store.isFavorite(kind: fav.kindEnum, targetId: fav.target_id)
        return Color.gray.opacity(0.15)
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
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                Haptic.impact(.soft)
                handleTap(fav)
            }
            .overlay(alignment: .bottomLeading) {
                FavoriteToggleButton(isFavorite: isFav, size: 12, padding: 7) {
                    Task {
                        await store.setFavorite(
                            !isFav,
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

    private func handleTap(_ fav: Favorite) {
        switch fav.kindEnum {
        case .pool:
            Task { await openPool(fav) }
        case .self:
            path.append(.coordinateDetail(.init(
                coordinateId: fav.target_id,
                coordinateImageURL: fav.image_url ?? "",
                showHeader: true
            )))
        }
    }

    private func openPool(_ fav: Favorite) async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        isLoadingPool = true
        defer { isLoadingPool = false }
        do {
            switch try await poolClient.get(poolId: fav.target_id, uid: uid) {
            case .success(let item):
                presentedPoolItem = item
            case .failure:
                // フォールバック: 最低限の表示でも開いてあげる
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
            }
        } catch {
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
