import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Binding var path: [ViewType]
    @State private var viewModel = ProfileViewModel()
//    @State private var selectedTab = 0  // コーデタブ未実装のためコメントアウト
    @State private var hasLoadedItems = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var itemToEdit: ClosetItem?
    @State private var showStandardItemSheet = false

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
                    actionButton(title: "プロフィールを編集") {
                        path.append(.profileEdit)
                    }
                    .padding(.horizontal, 20)
//                    tabSegmentView  // コーデタブ未実装のためコメントアウト

                    VStack(spacing: 16) {
                        addItemButtons
                        categorySelector
                        itemsGrid
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 90)  // TabBar の高さ分のパディング
            }
            .refreshable {
                await viewModel.loadItems()
            }
        }
        .background(Color.white)
        .sheet(item: $itemToEdit) { item in
            ItemImageEditView(
                viewModel: .init(item: item),
                onSaved: { newItem in
                    viewModel.replaceItem(oldId: item.id, with: newItem)
                }
            )
        }
        .sheet(isPresented: $showStandardItemSheet, onDismiss: {
            // 追加登録後にクローゼットを再読込して反映する
            Task { await viewModel.loadItems() }
        }) {
            NavigationStack {
                SelectStandardItemView()
            }
        }
        .alert("アイテムを削除", isPresented: $viewModel.showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {
                viewModel.itemToDelete = nil
            }
            Button("削除", role: .destructive) {
                Task { await viewModel.deleteItem() }
            }
        } message: {
            Text("このアイテムをクローゼットから削除しますか？\nこの操作は取り消せません。")
        }
        .overlay {
            if viewModel.isDeletingItem {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("削除中...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(16)
                }
            }
        }
        .task {
            if !hasLoadedItems {
                await viewModel.loadItems()
                hasLoadedItems = true
            }
        }
        .onAppear {
            // プロフィール編集から戻ってきたときに情報を再読み込み
            viewModel.reloadProfile()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await viewModel.uploadProfileImage(uiImage)
                }
            }
        }
    }

    // MARK: - 1. headerNavigationBar
    private var headerNavigationBar: some View {
        ZStack {
            Text("プロフィール")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)

            HStack {
                Spacer()
                Button(action: { path.append(.calendar) }) {
                    Image(systemName: "calendar")
                }
                .font(.system(size: 20))
                .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - 2. userProfileHeader
    private var userProfileHeader: some View {
        HStack(spacing: 20) {
            // プロフィール画像
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = viewModel.getProfileImageURL() {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty, .failure:
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.gray)
                            @unknown default:
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.gray)
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .background(Color.white.clipShape(Circle()))
                        .foregroundStyle(.black)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.profileInfo?.displayName ?? "")
                    .font(.system(size: 18, weight: .bold))

                if let createdAt = viewModel.profileInfo?.formattedCreatedAt {
                    Text("登録日: \(createdAt)")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }

                if let lastLoginAt = viewModel.profileInfo?.formattedLastLoginAt {
                    Text("最終ログイン: \(lastLoginAt)")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }

                if !viewModel.locationNames.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                        Text(viewModel.locationNames.joined(separator: "・"))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.gray)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("場所、\(viewModel.locationNames.joined(separator: "、"))")
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
//    private var actionButtons: some View {
//        HStack(spacing: 12) {
//            actionButton(title: "プロフィールを編集")
//            actionButton(title: "プロフィールを共有")
//        }
//        .padding(.horizontal, 20)
//    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - アイテムを追加する導線 (スタンダード選択 / Web検索)
    private var addItemButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("アイテムを追加")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                addItemButton(title: "スタンダードから", systemImage: "square.grid.2x2") {
                    Haptic.impact(.soft)
                    showStandardItemSheet = true
                }
                addItemButton(title: "検索して追加", systemImage: "magnifyingglass") {
                    Haptic.impact(.soft)
                    path.append(.addItemBySearch)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func addItemButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.gray.opacity(0.15))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - 4. tabSegmentView
    // コーデタブ未実装のためコメントアウト
//    private var tabSegmentView: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 0) {
//                tabButton(title: "アイテム", index: 0)
//                tabButton(title: "コーデ", index: 1)
//            }
//            Divider()
//        }
//    }
//
//    private func tabButton(title: String, index: Int) -> some View {
//        Button(action: { selectedTab = index }) {
//            VStack(spacing: 12) {
//                Text(title)
//                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
//                    .foregroundStyle(selectedTab == index ? .black : .gray)
//
//                Rectangle()
//                    .fill(selectedTab == index ? Color.black : Color.clear)
//                    .frame(height: 2)
//            }
//        }
//        .frame(maxWidth: .infinity)
//    }

    private var categorySelector: some View {
        HStack(spacing: 0) {
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

            Button(viewModel.isEditMode ? "完了" : "編集") {
                viewModel.toggleEditMode()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 20)
        }
    }

    // アイテムグリッド
    private var itemsGrid: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
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
                        ZStack(alignment: .topTrailing) {
                            if let imageUrl = item.image_url, let url = URL(string: imageUrl) {
                                VStack(spacing: 6) {
                                    // 画像部分
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(maxWidth: .infinity)
                                                .aspectRatio(1, contentMode: .fit)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(maxWidth: .infinity)
                                                .aspectRatio(1, contentMode: .fit)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .clipped()
                                        case .failure:
                                            Image(systemName: "photo")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity)
                                                .aspectRatio(1, contentMode: .fit)
                                                .padding(30)
                                                .foregroundStyle(.gray.opacity(0.5))
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }

                                    // 情報部分（category & color）
                                    VStack(spacing: 2) {
                                        if let category = item.category {
                                            Text(category)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.black)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        if let color = item.color {
                                            Text(color)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.gray)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
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
                                .onTapGesture {
                                    // 編集モード中は削除操作を優先 (タップで編集画面を開かない)
                                    guard !viewModel.isEditMode else { return }
                                    Haptic.impact(.soft)
                                    itemToEdit = item
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .padding(30)
                                        .foregroundStyle(.gray.opacity(0.5))
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(spacing: 2) {
                                        if let category = item.category {
                                            Text(category)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.black)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        if let color = item.color {
                                            Text(color)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.gray)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                                .padding(8)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }

                            // 編集モード時の削除ボタン
                            if viewModel.isEditMode {
                                Button {
                                    viewModel.requestDelete(itemId: item.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.red).padding(2))
                                }
                                .offset(x: -4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditMode)
                    }
                }
            }
        }
    }
}
