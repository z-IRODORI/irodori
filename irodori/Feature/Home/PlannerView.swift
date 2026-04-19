import SwiftUI

struct PlannerView: View {
    @State private var viewModel = PlannerViewModel()
    @State private var homeViewModel: HomeViewModel = .init(apiClient: MockHomeClient())

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                WeeklyPlannerContent(
                    calendarList: viewModel.calendarList,
                    selectedDateID: $viewModel.selectedDateID,
                    relativeDateText: viewModel.relativeDateText,
                    onSelectDate: { id in viewModel.selectDate(id: id) },
                    isCurrentMonth: { date in viewModel.isCurrentMonth(date: date) },
                    coordinateForDate: { dateID in homeViewModel.coordinates(for: dateID).first },
                    isLoadingForDate: { dateID in homeViewModel.isLoading(for: dateID) },
                    onAddCoordinate: { dateID in
                        Task {
                            await homeViewModel.addCoordinateByItem(for: dateID)
                        }
                    }
                )
            }
        }
        .background(Color.white)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
            Spacer()
            Text("プランナー").font(.system(size: 18, weight: .bold))
            Spacer()
            Button("今日") { viewModel.scrollToToday() }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color.gray.opacity(0.1)).clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12).foregroundStyle(.black)
    }
}
