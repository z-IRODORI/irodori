//
//  HomeView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [ViewType]
    @State var viewModel: HomeViewModel
    @State private var showFirstTakePhotoSheet = false
    @State private var showTutorialSheet = false
    @State private var showingPrefecturePicker = false
    @Environment(MainTabViewModel.self) private var tabViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.white)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
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
                            }
                        )
                        .padding(.horizontal, -24)
                    } else {
                        coordinateEmptyState
                    }

                    partnerCard

                    // 表示方式の切替ポイント:
                    //  - DailyRecommendationReasonSection:   下部に理由インラインパネル (B版・現行)
                    //  - DailyRecommendationCaptionSection: 各カード下にキャプション (C版)
                    DailyRecommendationReasonSection(
                        response: viewModel.dailyRecommendation,
                        isLoading: viewModel.isLoadingDailyRecommendation,
                        prefectureName: viewModel.currentPrefectureName,
                        onTap: { item in
                            viewModel.selectedDailyRecommendation = item
                        },
                        onLocationTap: {
                            Haptic.impact(.soft)
                            if viewModel.canChangePrefectureToday {
                                showingPrefecturePicker = true
                            } else {
                                ToastManager.shared.show("お住まいの地域は1日1回まで変更できます")
                            }
                        }
                    )

                    if let tags = viewModel.homeResponse.tags, !tags.isEmpty {
                        tagsSection
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .refreshable {
                await viewModel.onAppear()
            }
        }
        .background(Color.gray.opacity(0.08))
        .onAppear {
            Task {
                if viewModel.homeResponse.recent_coordinates.isEmpty {
                    await viewModel.onAppear()
                }
            }
        }
        .onChange(of: viewModel.isLoadingHome) { oldValue, newValue in
            if oldValue == true && newValue == false {
                if viewModel.homeResponse.recent_coordinates.isEmpty {
                    if let lastDismissedDate = UserDefaults.standard.object(forKey: UserDefaultsKey.lastDismissedFirstTakePhotoDate.rawValue) as? Date {
                        let oneHour: TimeInterval = 3600
                        if Date().timeIntervalSince(lastDismissedDate) >= oneHour {
                            showFirstTakePhotoSheet = true
                        }
                    } else {
                        showFirstTakePhotoSheet = true
                    }
                }
            }
        }
        .onChange(of: tabViewModel.shouldShowFirstTakePhotoOnHome) { _, newValue in
            if newValue {
                showFirstTakePhotoSheet = true
                tabViewModel.shouldShowFirstTakePhotoOnHome = false
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
        .sheet(item: Binding(
            get: { viewModel.selectedDailyRecommendation },
            set: { viewModel.selectedDailyRecommendation = $0 }
        )) { item in
            NavigationStack {
                DailyRecommendationDetailView(
                    item: item,
                    onWear: { item in
                        await viewModel.markWorn(item: item)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            viewModel.selectedDailyRecommendation = nil
                        }
                    }
                }
            }
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
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 20) {
                Spacer()
                Button(action: { path.append(.favorites) }) {
                    Image(systemName: "heart")
                }
                Button(action: { path.append(.calendar) }) {
                    Image(systemName: "calendar")
                }
                Button(action: { showTutorialSheet = true }) {
                    Image(systemName: "questionmark.circle")
                }
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
    }

    // MARK: - 相棒カード（統合）

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                PartnerIconImage(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今週のあなたへ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("相棒からのメッセージ")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                Spacer()
            }
            .padding(.bottom, 14)

            if viewModel.isLoadingAnalysis {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(width: 200, height: 14).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(.init(viewModel.recentCoordinateAnalysis.isEmpty
                    ? "コーデが登録されると分析が表示されます。"
                    : viewModel.recentCoordinateAnalysis))
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
            }

            Divider().padding(.vertical, 16)

            HStack(spacing: 10) {
                Button(action: { path.append(.tomorrowPlanner) }) {
                    Label("コーデ提案して", systemImage: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button(action: { path.append(.generalChat(conversationId: nil)) }) {
                    Label("質問する", systemImage: "bubble.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
//                PartnerIconImage(size: 44)
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
        viewModel: HomeViewModel(apiClient: MockHomeClient())
    )
    .environment(MainTabViewModel())
}
