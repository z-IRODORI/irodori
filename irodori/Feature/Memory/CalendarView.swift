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
            if viewModel.months.isEmpty || viewModel.isInitiallyLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allLoaded && !viewModel.hasAnyCoordinates {
                EmptyStateView(path: $path)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        ForEach(Array(zip(viewModel.months, viewModel.monthStates).enumerated()), id: \.offset) { i, pair in
                            let (month, state) = pair
                            switch state {
                            case .loading:
                                monthSkeletonSection(month: month)
                            case .loaded(let responses):
                                let hasPhotos = responses.contains { $0.coodinate_image_path != nil }
                                if hasPhotos {
                                    monthSection(month: month, responses: responses)
                                } else {
                                    monthEmptySection(month: month)
                                }
                            case .failed:
                                monthEmptySection(month: month)
                            }
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

    // MARK: - Month Section（写真あり）

    private func monthSection(month: Month, responses: [CoordinateListResponse]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(month.year)年\(month.monthOfTheYear)月")
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
                    dayCell(month: month, day: day, responses: responses)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.easeOut(duration: 0.25), value: UUID())
    }

    // MARK: - Month Section（0件）

    private func monthEmptySection(month: Month) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(month.year)年\(month.monthOfTheYear)月")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)

            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gray.opacity(0.35))
                Text("この月の記録はありません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gray.opacity(0.45))
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                Color.gray.opacity(0.15),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    )
            )
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.2), value: UUID())
    }

    // MARK: - Month Skeleton（ロード中）

    private func monthSkeletonSection(month: Month) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 90, height: 18)
                .padding(.bottom, 2)

            LazyVGrid(columns: columns7, spacing: 4) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.10))
                        .frame(height: 10)
                }
                ForEach(0..<28, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.09))
                        .aspectRatio(3/4, contentMode: .fill)
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(month: Month, day: Int, responses: [CoordinateListResponse]) -> some View {
        let coord = responses[safe: day - 1]
        let imageURL = coord?.coodinate_image_path
        let coordinateId = coord?.id
        let isToday = checkIsToday(year: month.year, month: month.monthOfTheYear, day: day)

        return Button(action: {
            guard let imageURL, let coordinateId, !coordinateId.isEmpty else { return }
            let targetDateString = String(format: "%04d-%02d-%02d", month.year, month.monthOfTheYear, day)
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "date": targetDateString,
                "has_coordinate": true
            ])
            let params = ViewType.CoordinateDetailParams(
                coordinateId: coordinateId,
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

    // MARK: - Empty State（全コーデ0件）

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
