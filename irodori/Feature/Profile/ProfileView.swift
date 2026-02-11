import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var selectedTab = 0
    @State private var hasLoadedItems = false

    let itemSpacing: CGFloat = 4
    // グリッドのレイアウト設定 (3列)
    var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: itemSpacing),
            GridItem(.flexible(), spacing: itemSpacing),
            GridItem(.flexible(), spacing: itemSpacing)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. トップナビゲーション
            headerNavigationBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    userProfileHeader
                    actionButtons
                    tabSegmentView

                    VStack(spacing: 16) {
                        categorySelector
                        itemsGrid
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 10)
            }
        }
        .background(Color.white)
        .task {
            if !hasLoadedItems {
                await viewModel.loadItems()
                hasLoadedItems = true
            }
        }
    }

    // MARK: - 1. headerNavigationBar
    private var headerNavigationBar: some View {
        HStack {
            Text("dahama")
                .font(.system(size: 24, weight: .bold))

            Spacer()

            HStack(spacing: 20) {
                Button(action: {}) { Image(systemName: "calendar") }
                Button(action: {}) { Image(systemName: "clock.arrow.circlepath") }
                Button(action: {}) { Image(systemName: "line.3.horizontal") }
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - 2. userProfileHeader
    private var userProfileHeader: some View {
        HStack(spacing: 20) {
            // プロフィール画像
            ZStack(alignment: .bottomTrailing) {
                Image(.wolf) // Assets内の画像
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))

                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .background(Color.white.clipShape(Circle()))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("だはま")
                    .font(.system(size: 18, weight: .bold))

                HStack(spacing: 16) {
                    statsColumn(value: "0", label: "フォロワー")
                    statsColumn(value: "0", label: "フォロー中")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func statsColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 12)).foregroundStyle(.gray)
        }
    }

    // MARK: - 3. actionButtons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            actionButton(title: "プロフィールを編集")
            actionButton(title: "プロフィールを共有")
        }
        .padding(.horizontal, 20)
    }

    private func actionButton(title: String) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - 4. tabSegmentView
    private var tabSegmentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(title: "アイテム", index: 0)
                tabButton(title: "コーデ", index: 1)
            }
            Divider()
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundStyle(selectedTab == index ? .black : .gray)

                Rectangle()
                    .fill(selectedTab == index ? Color.black : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categorySelector: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Enum の CaseIterable を利用してループ
                    ForEach(ClothingCategory.allCases) { category in
                        Button {
                            viewModel.selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(viewModel.selectedCategory == category ? .black : Color.gray.opacity(0.1))
                                .foregroundStyle(viewModel.selectedCategory == category ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // 右側の三点リーダーやフィルターアイコン
//            HStack(spacing: 12) {
//                Image(systemName: "line.3.horizontal.decrease.circle.fill")
//                Image(systemName: "ellipsis.circle.fill")
//            }
//            .font(.system(size: 24))
//            .foregroundStyle(Color.gray.opacity(0.2))
//            .padding(.trailing, 20)
        }
    }

    // アイテムグリッド
    private var itemsGrid: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
            } else if viewModel.filteredItems.isEmpty {
                Text("アイテムが登録されていません")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
            } else {
                LazyVGrid(columns: columns, spacing: itemSpacing) {
                    ForEach(viewModel.filteredItems) { item in
                        if let imageUrl = item.image_url, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .padding(30)
                                        .foregroundStyle(.gray.opacity(0.5))
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .padding(30)
                                .foregroundStyle(.gray.opacity(0.5))
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}
