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

    private let columns7 = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasAnyCoordinates {
                EmptyStateView(path: $path)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        ForEach(0..<viewModel.coordinateListResponses.count, id: \.self) { i in
                            monthSection(index: i)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(.white)
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            AnalyticsLogger.shared.log(screen: .memoryCalendarScreenView)
            await viewModel.onAppear()
        }
        .onDisappear {
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "action": GAEventAction.backToCamera.rawValue
            ])
        }
        .onChange(of: path) { oldPath, newPath in
            if !oldPath.isEmpty && newPath.isEmpty {
                Task {
                    viewModel.hasLoaded = false
                    await viewModel.onAppear()
                }
            }
        }
    }

    // MARK: - Month Section

    private func monthSection(index i: Int) -> some View {
        let month = viewModel.months[i]
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(month.year)年\(month.monthOfTheYear)月")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .padding(.bottom, 2)

            LazyVGrid(columns: columns7, spacing: 4) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }

                ForEach(0..<(month.spacesBeforeFirst - 1), id: \.self) { _ in
                    Color.clear.aspectRatio(3/4, contentMode: .fill)
                }

                ForEach(1...month.amountOfDays, id: \.self) { day in
                    if !viewModel.coordinateListResponses.isEmpty {
                        dayCell(month: month, day: day, index: i)
                    }
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(month: Month, day: Int, index i: Int) -> some View {
        let imageURL = viewModel.coordinateListResponses[i][day - 1].coodinate_image_path
        let isToday = checkIsToday(year: month.year, month: month.monthOfTheYear, day: day)

        return Button(action: {
            guard let imageURL else { return }
            let targetDateString = String(format: "%04d-%02d-%02d", month.year, month.monthOfTheYear, day)
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "date": targetDateString,
                "has_coordinate": true
            ])
            let params = ViewType.CoordinateDetailParams(
                uid: viewModel.uid,
                targetDateString: targetDateString,
                coordinateImageURL: imageURL,
                showHeader: false
            )
            path.append(.coordinateDetail(params))
        }) {
            ZStack {
                if let imageURL {
                    coordinateImage(from: imageURL)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity,
                               minHeight: 0, maxHeight: .infinity)
                        .aspectRatio(3/4, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("\(day)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                } else {
                    Color.clear.aspectRatio(3/4, contentMode: .fill)

                    if isToday {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 28, height: 28)
                        Text("\(day)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(day)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
            }
            .aspectRatio(3/4, contentMode: .fill)
        }
        .buttonStyle(.plain)
        .disabled(imageURL == nil)
    }

    // MARK: - Helpers

    /// httpURLはKFImageで読み込み、アセット名（Preview用）はImage()にフォールバック
    @ViewBuilder
    private func coordinateImage(from path: String) -> some View {
        if path.hasPrefix("http"), let url = URL(string: path) {
            KFImage(url)
                .resizable()
        } else {
            Image(path)
                .resizable()
        }
    }

    private func checkIsToday(year: Int, month: Int, day: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return today.year == year && today.month == month && today.day == day
    }

    // MARK: - Empty State

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
                tabViewModel.shouldShowFirstTakePhotoOnHome = true
                tabViewModel.selectedTab = .home
                dismiss()
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
}

#Preview {
    CalendarView(viewModel: .init(apiClient: MockCoordinateListClient()), path: .constant([]))
        .environment(MainTabViewModel())
}
