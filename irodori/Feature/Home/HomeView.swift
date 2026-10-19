//
//  HomeView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//
//  2026-07: ファーストビューを「明日のコーデ」3案カルーセル (TomorrowPickSection) に刷新。
//  旧・相棒カード(週間分析)と3×3グリッドはカルーセル+アクションカードに集約した。
//  デザイン検証の経緯は Feature/Sandbox/HomeDesignD.swift を参照。
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [ViewType]
    @State var viewModel: HomeViewModel
    @State private var showFirstTakePhotoSheet = false
    @State private var showTutorialSheet = false
    @State private var showingPrefecturePicker = false
    @State private var showPartnerOnboardingSheet = false
    @State private var showFullBodyPickerSheet = false
    @State private var showStandardItemPickerSheet = false
    @State private var showTasteVoteSheet = false
    #if DEBUG
    @State private var showHomeSandboxSheet = false
    /// リニューアル後アプリの体験 Sandbox (Feature/Sandbox/Renewal)
    @State private var showRenewalSandbox = false
    #endif
    @Environment(MainTabViewModel.self) private var tabViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.white)

            ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    // Layer 1: 相棒のデイリーブリーフィング（タップで相棒画面へ遷移）
                    PartnerHomeBriefingCard(
                        partnerHome: viewModel.partnerHome,
                        persistedOnboarding: viewModel.persistedOnboarding,
                        closetCount: viewModel.closetItems.count,
                        partnerCommentFromDaily: viewModel.dailyRecommendation?.partner_comment,
                        onTapPartnerProfile: {
                            Haptic.impact(.soft)
                            path.append(.partner)
                        },
                        onTapRetakeOnboarding: {
                            Haptic.impact(.soft)
                            showPartnerOnboardingSheet = true
                        }
                    )

                    // Layer 2: 今日/明日/週末の3案カルーセル + 構成アイテム比較 + これにする
                    TomorrowPickSection(
                        viewModel: viewModel,
                        onLocationTap: {
                            Haptic.impact(.soft)
                            if viewModel.canChangePrefectureToday {
                                showingPrefecturePicker = true
                            } else {
                                ToastManager.shared.show("お住まいの地域は1日1回まで変更できます")
                            }
                        }
                    )
                    .padding(.horizontal, -24)
                    .id("hero")

                    // Layer 3: 相棒からのデータ獲得提案カード（コンパクト3タイル）
                    PartnerDataAcquisitionCard(
                        closetCount: viewModel.closetItems.count,
                        onTapPhotoAutoPick: {
                            showFullBodyPickerSheet = true
                        },
                        onTapSelectStandardItems: {
                            showStandardItemPickerSheet = true
                        },
                        onTapKeywordSearch: {
                            path.append(.addItemBySearch)
                        },
                        onTapTasteVote: {
                            showTasteVoteSheet = true
                        }
                    )

                    // 直近コーデ（登録済みのときのみ表示し、未登録時は上の3タイル登録カードに集約）
                    if viewModel.isLoadingHome {
                        recentCoordinatesSkeleton
                    } else if viewModel.hasLoadError {
                        recentCoordinatesError
                    } else if !viewModel.homeResponse.recent_coordinates.isEmpty {
                        RecentCoordinates(
                            recentCoordinates: viewModel.homeResponse.recent_coordinates,
                            isEditMode: viewModel.isEditMode,
                            onToggleEditMode: { viewModel.toggleEditMode() },
                            onDeleteRequest: { coordinateId in
                                viewModel.requestDelete(coordinateId: coordinateId)
                            },
                            onTapCoordinate: { coordinate in
                                path.append(.coordinateDetail(.init(
                                    coordinateId: coordinate.id,
                                    coordinateImageURL: coordinate.displayImageURL,
                                    showHeader: true
                                )))
                            }
                        )
                        .padding(.horizontal, -24)
                    }

                    // 20時以降の「明日の先取り」ティザー (夜→朝ループのトリガー)
                    DailyTeaserSection(
                        viewModel: viewModel,
                        onOpenTomorrow: {
                            viewModel.selectPickScope(.tomorrow)
                            withAnimation(.easeInOut(duration: 0.4)) {
                                scrollProxy.scrollTo("hero", anchor: .top)
                            }
                        }
                    )

                    Spacer().frame(height: 48)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .refreshable {
                await viewModel.onAppear()
            }
            }
        }
        .background(Color.gray.opacity(0.08))
        .onAppear {
            Task {
                if viewModel.homeResponse.recent_coordinates.isEmpty || viewModel.partnerHome == nil {
                    await viewModel.onAppear()
                }
            }
        }
        .onChange(of: tabViewModel.shouldShowFirstTakePhotoOnHome) { _, newValue in
            if newValue {
                showFirstTakePhotoSheet = true
                tabViewModel.shouldShowFirstTakePhotoOnHome = false
            }
        }
        .fullScreenCover(isPresented: $showPartnerOnboardingSheet, onDismiss: {
            Task {
                let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
                await viewModel.loadPartnerHomeSection(uid: uid)
                await viewModel.reloadDailyRecommendation()
            }
        }) {
            PartnerOnboardingFlowView(
                showCloseButton: true,
                onComplete: {
                    showPartnerOnboardingSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: $showFullBodyPickerSheet) {
            FullBodyPickerView(
                onComplete: { images in
                    showFullBodyPickerSheet = false
                    if let first = images.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            path.append(.coordinateReview(.init(
                                image: first,
                                fromFirstTakePhotoView: false
                            )))
                        }
                    }
                },
                onClose: {
                    showFullBodyPickerSheet = false
                }
            )
        }
        .sheet(isPresented: $showStandardItemPickerSheet, onDismiss: {
            Task { await viewModel.onAppear() }
        }) {
            NavigationStack {
                SelectStandardItemView(
                    path: $path,
                    onComplete: {
                        showStandardItemPickerSheet = false
                    }
                )
                .navigationTitle("定番アイテムから追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            showStandardItemPickerSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTasteVoteSheet, onDismiss: {
            Task {
                let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
                await viewModel.loadPartnerHomeSection(uid: uid)
            }
        }) {
            NavigationStack {
                PartnerPattern4TasteVoteView()
                    .navigationTitle("2つのコーデを見比べる")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") {
                                showTasteVoteSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingItemPicker },
            set: { viewModel.showingItemPicker = $0 }
        )) {
            ClosetItemPickerView(
                closetItems: viewModel.closetItems,
                isLoading: viewModel.isLoadingCloset,
                onSelect: { closetItem in
                    Task { await viewModel.selectAndRecommend(closetItem: closetItem) }
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingOutfitCollageDetail },
            set: { viewModel.showingOutfitCollageDetail = $0 }
        )) {
            NavigationStack {
                OutfitCollageDetailView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") {
                                viewModel.showingOutfitCollageDetail = false
                            }
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { viewModel.selectedWebLink },
            set: { viewModel.selectedWebLink = $0 }
        )) { link in
            WebViewContainer(url: link.url)
        }
        .sheet(isPresented: $showFirstTakePhotoSheet, onDismiss: {
            Task { await viewModel.onAppear() }
        }) {
            FirstTakePhotoView(
                path: $path,
                viewModel: .init(fashionReviewClient: FashionReviewClient()),
                showCloseButton: true,
                onClose: { showFirstTakePhotoSheet = false },
                okButtonTapped: {},
                onDontShowAgain: {
                    UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.lastDismissedFirstTakePhotoDate.rawValue)
                    showFirstTakePhotoSheet = false
                },
                onCameraButtonTapped: {
                    showFirstTakePhotoSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        path.append(.camera)
                    }
                }
            )
        }
        .sheet(isPresented: $showTutorialSheet) {
            OnboardingView(closeButtonTapped: { showTutorialSheet = false })
        }
        .sheet(isPresented: $showingPrefecturePicker) {
            NavigationStack {
                PrefecturePickerView(
                    selectedCode: viewModel.currentPrefectureCode,
                    onSelect: { prefecture in
                        Task { await viewModel.updatePrefecture(prefecture) }
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { showingPrefecturePicker = false }
                    }
                }
            }
        }
        .alert("コーディネートを削除", isPresented: $viewModel.showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {
                viewModel.coordinateToDelete = nil
            }
            Button("削除", role: .destructive) {
                Task { await viewModel.deleteCoordinate() }
            }
        } message: {
            Text("このコーディネートを削除してもよろしいですか？")
        }
        .overlay {
            if viewModel.isDeletingCoordinate {
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
        #if DEBUG
        .fullScreenCover(isPresented: $showHomeSandboxSheet) {
            NavigationStack {
                PartnerIntegratedHomeSandboxView()
                    .environment(tabViewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("閉じる") {
                                showHomeSandboxSheet = false
                            }
                            .foregroundStyle(.black)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showRenewalSandbox) {
            RenewalExperienceSandboxView()
        }
        #endif
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 16) {
                #if DEBUG
                Button {
                    Haptic.impact(.soft)
                    showHomeSandboxSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flask")
                            .font(.system(size: 12, weight: .semibold))
                        Text("改善案")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    Haptic.impact(.soft)
                    showRenewalSandbox = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("リニューアル体験")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                #endif
                Spacer()
                Button(action: { path.append(.favorites) }) {
                    Image(systemName: "heart")
                }
                // カレンダーはタブに昇格したため、プッシュではなくタブ切り替えで開く
                Button(action: { tabViewModel.selectedTab = .calendar }) {
                    Image(systemName: "calendar")
                }
                Button(action: { showPartnerOnboardingSheet = true }) {
                    Image(systemName: "questionmark.circle")
                }
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
    }

    // MARK: - 別ルートの提案導線 (旧・相棒カードの2ボタンを継承)
    // 2026-08: ホームの整理のため非表示化。「相棒に相談」は相棒タブへ移設した。
    // 「アイテムから」(.outfitSuggestion) を復活させる場合はこのカードごと戻す。
//    private var actionsCard: some View {
//        HStack(spacing: 10) {
//            Button(action: { path.append(.outfitSuggestion) }) {
//                Label("アイテムから", systemImage: "tshirt")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundStyle(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 12)
//                    .background(.black)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//            }
//            Button(action: { path.append(.generalChat(conversationId: nil)) }) {
//                Label("相棒に相談", systemImage: "bubble.left")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundStyle(.black)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 12)
//                    .background(Color.gray.opacity(0.1))
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
//            }
//        }
//        .padding(20)
//        .background(.white)
//        .clipShape(RoundedRectangle(cornerRadius: 16))
//        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
//    }

    // MARK: - コーデコラージュ導線

    private var collageEntryCard: some View {
        Button(action: {
            Haptic.impact(.soft)
            path.append(.coordinateCollage)
        }) {
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("コーデコラージュを作る")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("お気に入りコーデを3枚以上えらんで、1枚のシェア画像に")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            .padding(20)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - ローディング スケルトン

    private var recentCoordinatesSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 100, height: 134)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.10))
                            .frame(width: 56, height: 10)
                            .padding(.vertical, 8)
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, -24)
    }

    // MARK: - ローディングエラー

    private var recentCoordinatesError: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("読み込めませんでした")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Button(action: { Task { await viewModel.onAppear() } }) {
                    Text("再試行する")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .underline()
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - コーデ未登録 空状態

    private var coordinateEmptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("コーデを記録しましょう")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("着こなしを残すと、相棒があなたのスタイルを分析します。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(action: { path.append(.camera) }) {
                HStack {
                    Text("写真を撮って登録する")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - タグ

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("これまでのタグ")
                .font(.system(size: 20, weight: .bold))
            TagsView(
                tags: Array((viewModel.homeResponse.tags ?? []).prefix(8)),
                tagTextColor: .black,
                borderColor: .gray,
                tagFont: .system(size: 14, weight: .regular)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView(
        path: .constant([]),
        viewModel: HomeViewModel(
            apiClient: MockHomeClient(),
            dailyRecommendationClient: MockDailyRecommendationClient()
        )
    )
    .environment(MainTabViewModel())
    .environment(FavoritesStore())
}
