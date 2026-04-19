//
//  CalendarView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation
import SwiftUI
import Kingfisher

struct CalendarView: View {
    @State var viewModel: CalendarViewModel
    @Binding var path: [ViewType]
    @Environment(MainTabViewModel.self) private var tabViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns7 = [
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center)
    ]
    private let columns3 = [
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasAnyCoordinates {
                // コーデが0件の場合の表示
                EmptyStateView(path: $path)
            } else {
                ScrollView(showsIndicators: false) {
                    ForEach(0..<viewModel.coordinateListResponses.count, id: \.self) { i in
                        Text("\(viewModel.months[i].title)  \(String(viewModel.months[i].year))")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top)

                        LazyVGrid(columns: columns3, alignment: .center, pinnedViews: .sectionHeaders) {
                            // Days in a month
                            ForEach(1..<viewModel.months[i].amountOfDays + 1, id: \.self) { day in
                                if !viewModel.coordinateListResponses.isEmpty {
                                    if let coordinateImageURL = viewModel.coordinateListResponses[i][day - 1].coodinate_image_path {
                                        Button(action: {
                                            let year = viewModel.months[i].year
                                            let month = viewModel.months[i].monthOfTheYear
                                            let targetDateString = String(format: "%04d-%02d-%02d", year, month, day)

                                            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                                                "date": targetDateString,
                                                "has_coordinate": true
                                            ])

                                            let params: ViewType.CoordinateDetailParams = .init(uid: viewModel.uid, targetDateString: targetDateString, coordinateImageURL: coordinateImageURL, showHeader: false)
                                            path.append(.coordinateDetail(params))
                                        }) {
                                            Card(coordinateImageURL: coordinateImageURL, month: viewModel.months[i].monthOfTheYear, day: day)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            AnalyticsLogger.shared.log(screen: .memoryCalendarScreenView)
            await viewModel.onAppear()
        }
        .onDisappear {
            // 画面を離れる際にアナリティクスを記録
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "action": GAEventAction.backToCamera.rawValue
            ])
        }
        .onChange(of: path) { oldPath, newPath in
            // CoordinateReviewViewから「ホームへ」ボタンでpathが空になったらカレンダーをリロード
            if !oldPath.isEmpty && newPath.isEmpty {
                Task {
                    // リロードフラグをリセットして再読み込み
                    viewModel.hasLoaded = false
                    await viewModel.onAppear()
                }
            }
        }
    }

    private func EmptyStateView(path: Binding<[ViewType]>) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray.opacity(0.5))

                VStack(spacing: 8) {
                    Text("コーデが登録されていません")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text("コーデを登録すると、\nカレンダーで振り返ることができます")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: {
                // ホームタブに切り替えて、FirstTakePhotoViewを表示
                tabViewModel.shouldShowFirstTakePhotoOnHome = true
                tabViewModel.selectedTab = .home
                dismiss()  // カレンダー画面を閉じる
            }) {
                Text("コーデを登録する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // 標準ナビゲーションバーを使用するため、カスタムHeaderは不要
//    private func Header() -> some View {
//        ZStack {
//            Text("カレンダー")
//                .font(.headline)
//                .padding(.top, 7)
//
//            Button {
//                AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
//                    "action": GAEventAction.backToCamera.rawValue
//                ])
//                mode.wrappedValue.dismiss()
//            } label: {
//                Image(systemName: "arrow.backward")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                    .frame(maxWidth: 30, maxHeight: 30)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//    }

    private func Card(coordinateImageURL: String, month: Int, day: Int) -> some View {
        ZStack(alignment: .topLeading) {
            CachedAsyncImage(url: URL(string: coordinateImageURL)!) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        ProgressView()
                    }
                }
            }
            .scaledToFill()
            .aspectRatio(3/4, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("\(month)/\(day)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 12)
                .padding(.leading, 12)
        }
    }
}

#Preview {
    CalendarView(viewModel: .init(apiClient: CoordinateListClient()), path: .constant([]))
}
