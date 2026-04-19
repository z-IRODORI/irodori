//
//  HomeView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [ViewType]
//    @State var viewModel: HomeViewModel = .init(apiClient: MockHomeClient())
    @State var viewModel: HomeViewModel = .init(apiClient: HomeClient())
    @State private var plannerViewModel: PlannerViewModel = .init()
    @State private var showAllTags = false
    @State private var showFirstTakePhotoSheet = false
    @State private var showTutorialSheet = false
    @Environment(MainTabViewModel.self) private var tabViewModel

    var body: some View {
        VStack(spacing: 12) {
            Header()
                .padding(.horizontal, 24)
                .padding(.top, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    // TODO: 直近のコーデが存在しない場合のUIを考える
                    // 直近のコーデが存在しない場合、コーデだけではなく分析やタグを表示できないので、それも踏まえてUIを考える
                    RecentCoordinates(
                        recentCoordinates: viewModel.homeResponse.recent_coordinates,
                        isEditMode: viewModel.isEditMode,
                        onToggleEditMode: {
                            viewModel.toggleEditMode()
                        },
                        onDeleteRequest: { coordinateId in
                            viewModel.requestDelete(coordinateId: coordinateId)
                        }
                    )
                    .padding(.horizontal, -24)

                    VStack(spacing: 24) {
    //                    Text("コーデ提案")
    //                        .font(.system(size: 20, weight: .bold))
    //                        .frame(maxWidth: .infinity, alignment: .leading)
    //                    Text("3日間分のコーデを提案します。過去に登録したアイテムやコーデから提案します。")
    //                        .font(.system(size: 14, weight: .regular))
    //                        .foregroundStyle(.gray)
    //                        .frame(maxWidth: .infinity, alignment: .leading)
    //                        .padding(.top, -18)
    //                    WeeklyPlannerContent(
    //                        calendarList: plannerViewModel.calendarList,
    //                        selectedDateID: $plannerViewModel.selectedDateID,
    //                        relativeDateText: plannerViewModel.relativeDateText,
    //                        onSelectDate: { id in plannerViewModel.selectDate(id: id) },
    //                        isCurrentMonth: { date in plannerViewModel.isCurrentMonth(date: date) }
    //                    )
    //                    .padding(.horizontal, -24)

    //                    ThreeDaysPlanner(
    //                        calendarList: plannerViewModel.calendarList,
    //                        selectedDateID: $plannerViewModel.selectedDateID,
    //                        relativeDateText: plannerViewModel.relativeDateText,
    //                        selectCoordinateItemForDate: { dateID in viewModel.selectCoordinateItem(for: dateID) },
    //                        onSelectDate: { id in plannerViewModel.selectDate(id: id) },
    //                        isCurrentMonth: { date in plannerViewModel.isCurrentMonth(date: date) },
    //                        coordinatesForDate: { dateID in viewModel.coordinates(for: dateID) },
    //                        isLoadingForDate: { dateID in viewModel.isLoading(for: dateID) },
    //                        onAddCoordinateRandom: { dateID in
    //                            Task {
    //                                await viewModel.addCoordinateByItem(for: dateID)
    //                            }
    //                        },
    //                        onAddCoordinateByItem: { dateID in
    //                            viewModel.showItemPicker(for: dateID)
    //                        },
    //                        onChangeItem: {
    //                            if let dateID = plannerViewModel.selectedDateID {
    //                                viewModel.showItemPicker(for: dateID)
    //                            }
    //                        },
    //                        onReset: { dateID in
    //                            viewModel.resetCoordinate(for: dateID)
    //                        }
    //                    )
    //                    .padding(.horizontal, -24)

                        TomorrowPlannerView()
                            .padding(.horizontal, -24)
                    }

                    // コーデの分析
                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            PartnerIconImage(size: 50)
                                .redacted(reason: viewModel.isLoadingAnalysis ? .placeholder : [])

                            SpeechBubbleView(text: "これまでのコーデを分析しました")
                                .redacted(reason: viewModel.isLoadingAnalysis ? .placeholder : [])
                        }
                        if !viewModel.recentCoordinateAnalysis.isEmpty {
                            Text(.init(viewModel.recentCoordinateAnalysis))
                                .font(.system(size: 16, weight: .regular))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .redacted(reason: viewModel.isLoadingAnalysis ? .placeholder : [])
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // これまでのタグ
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Text("これまでのタグ")
                                .font(.system(size: 20, weight: .bold))
                                .redacted(reason: viewModel.isLoadingHome ? .placeholder : [])
                            if let tags = viewModel.homeResponse.tags, tags.count > 8 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAllTags.toggle()
                                    }
                                }) {
                                    Text(showAllTags ? "閉じる" : "すべて見る")
                                        .font(.system(size: 14, weight: .regular))
                                }
                                .redacted(reason: viewModel.isLoadingHome ? .placeholder : [])
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let tags = viewModel.homeResponse.tags {
                            let displayedTags = showAllTags ? tags : Array(tags.prefix(8))
                            TagsView(tags: displayedTags, tagTextColor: .black, borderColor: .gray, tagFont: .system(size: 14, weight: .regular))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .redacted(reason: viewModel.isLoadingHome ? .placeholder : [])
                        } else {
                            Text("タグが存在しません")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .redacted(reason: viewModel.isLoadingHome ? .placeholder : [])
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
            .refreshable {
                await viewModel.onAppear()
            }
        }
        .onAppear {
            Task {
                // 既にデータがある場合は読み込まない
                if viewModel.homeResponse.recent_coordinates.isEmpty {
                    await viewModel.onAppear()
                }
            }
        }
        .onChange(of: viewModel.isLoadingHome) { oldValue, newValue in
            // データロード完了時に、直近のコーデが0件の場合、FirstTakePhotoViewを表示
            // ただし、最後に「1時間表示しない」を押してから1時間以内は表示しない
            if oldValue == true && newValue == false {
                if viewModel.homeResponse.recent_coordinates.isEmpty {
                    // 最後に非表示にした日時を取得
                    if let lastDismissedDate = UserDefaults.standard.object(forKey: UserDefaultsKey.lastDismissedFirstTakePhotoDate.rawValue) as? Date {
                        // 1時間（3600秒）経過しているかチェック
                        let oneHour: TimeInterval = 3600
                        if Date().timeIntervalSince(lastDismissedDate) >= oneHour {
                            showFirstTakePhotoSheet = true
                        }
                    } else {
                        // 初回は表示
                        showFirstTakePhotoSheet = true
                    }
                }
            }
        }
        .onChange(of: tabViewModel.shouldShowFirstTakePhotoOnHome) { _, newValue in
            // カレンダー画面から「コーデを登録する」ボタンでホームに戻ってきた場合
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
                    Task {
                        await viewModel.selectAndRecommend(closetItem: closetItem)
                    }
                }
            )
        }
        .sheet(isPresented: $showFirstTakePhotoSheet) {
            FirstTakePhotoView(
                path: $path,
                viewModel: .init(fashionReviewClient: FashionReviewClient()),
                showCloseButton: true,
                onClose: {
                    showFirstTakePhotoSheet = false
                },
                okButtonTapped: {
                    showFirstTakePhotoSheet = false
                },
                onDontShowAgain: {
                    // 「1時間表示しない」を押した日時をUserDefaultsに保存
                    UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.lastDismissedFirstTakePhotoDate.rawValue)
                    showFirstTakePhotoSheet = false
                },
                onCameraButtonTapped: {
                    // 1. sheetを閉じる
                    showFirstTakePhotoSheet = false

                    // 2. sheetのdismissアニメーション完了を待つ（0.3秒）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 3. CameraViewへNavigationStack経由で遷移
                        path.append(.camera)
                    }
                }
            )
        }
        .sheet(isPresented: $showTutorialSheet) {
            OnboardingView(closeButtonTapped: {
                showTutorialSheet = false
            })
        }
        .background(.gray.opacity(0.08))
//        .overlay(alignment: .bottom) {
//            HStack(spacing: 12) {
//                Button(action: {
//                    // action
//                }, label: {
//                    Text("写真選択")
//                        .font(.system(size: 18, weight: .regular))
//                        .foregroundStyle(.white)
//                        .frame(maxWidth: 200)
//                        .frame(height: 50)
//                        .background(.black)
//                        .clipShape(RoundedRectangle(cornerRadius: 20))
//                })
//
//                Button(action: {
//                    // action
//                }, label: {
//                    Text("カメラ")
//                        .font(.system(size: 18, weight: .regular))
//                        .foregroundStyle(.white)
//                        .frame(maxWidth: 200)
//                        .frame(height: 50)
//                        .background(.black)
//                        .clipShape(RoundedRectangle(cornerRadius: 20))
//                })
//            }
//            .padding(.top, 24)
//            .padding(.horizontal, 24)
//            .padding(.bottom, 90)  // TabBar の高さ分のパディング
//            .background(.white)
//        }
        .alert("コーディネートを削除", isPresented: $viewModel.showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {
                viewModel.coordinateToDelete = nil
            }
            Button("削除", role: .destructive) {
                Task {
                    await viewModel.deleteCoordinate()
                }
            }
        } message: {
            Text("このコーディネートを削除してもよろしいですか？")
        }
        .overlay {
            if viewModel.isDeletingCoordinate {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

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

    private func Header() -> some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
            HStack(spacing: 24) {
                Button(action: {
                    path.append(.calendar)
                }) {
                    Image(systemName: "calendar")
                }

                Button(action: {
                    showTutorialSheet = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView(path: .constant([]))
}
