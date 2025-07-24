//
//  CalendarView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation
import SwiftUI

struct CalendarView: View {
    @Environment(\.presentationMode) var mode
    
    private let columns = [
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center)
    ]

    @State var viewModel: CalendarViewModel = .init(apiClient: CoordinateListClient())

    var body: some View {

        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {

                // Amount of months since December 2022
//                ForEach(viewModel.months) { month in
                ForEach(0..<viewModel.coordinateListResponses.count, id: \.self) { i in
                    Text("\(viewModel.months[i].title)  \(String(viewModel.months[i].year))")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(viewModel.daysOfTheWeek, id: \.self) { day in
                            Text(day.rawValue)
                            Spacer()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)

                    LazyVGrid(columns: columns, alignment: .center, pinnedViews: .sectionHeaders) {
                        ForEach(1..<viewModel.months[i].spacesBeforeFirst, id: \.self) { _ in
                            Text("")
                        }

                        // Days in a month
                        ForEach(1..<viewModel.months[i].amountOfDays + 1, id: \.self) { day in
                            CalendarCell(
                                thumbnailImageURL: viewModel.coordinateListResponses[i][day - 1].coodinate_image_path,
                                height: UIScreen.main.bounds.width/6.5,
                                dayOfMonth: day
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 75)
            }

            Header()
                .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await viewModel.onAppear()
            }
        }
    }

    private func Header() -> some View {
        ZStack {
            Text("カレンダー")
                .font(.headline)
                .padding(.top, 7)

            Button {
                mode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "arrow.backward")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: 30, maxHeight: 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    CalendarView()
}
