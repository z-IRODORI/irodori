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

    let months: [Month] = [
        .init(month: "12月", monthOfTheYear: 12, year: 2022),
        .init(month: "1月", monthOfTheYear: 1, year: 2023),
        .init(month: "2月", monthOfTheYear: 2, year: 2023),
        .init(month: "3月", monthOfTheYear: 3, year: 2023),
        .init(month: "4月", monthOfTheYear: 4, year: 2023),
        .init(month: "5月", monthOfTheYear: 5, year: 2023),
        .init(month: "6月", monthOfTheYear: 6, year: 2023),
        .init(month: "7月", monthOfTheYear: 7, year: 2023),
        .init(month: "8月", monthOfTheYear: 8, year: 2023),
    ]

    private var daysOfTheWeek: [Week] = Week.allCases
    private var columns = [
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center)
    ]

    var body: some View {

        ScrollView(showsIndicators: false) {

            // Amount of months since December 2022
            ForEach(months) { month in
                Text("\(month.month). \(month.year)")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                HStack(spacing: 0) {
                    Spacer()
                    ForEach(daysOfTheWeek, id: \.self) { day in
                        Text(day.rawValue)
                        Spacer()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)

                LazyVGrid(columns: columns, alignment: .center, pinnedViews: .sectionHeaders) {
                    ForEach(1..<month.spacesBeforeFirst) { _ in
                        Text("")
                    }

                    // Days in a month
                    ForEach(1..<month.amountOfDays + 1) { i in
                        CalendarCell(
                            beforeImageURL: "",
                            afterImageURL: "",
                            date: "",
                            height: UIScreen.main.bounds.width/6.5,
                            dayOfMonth: i
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 75)

        }
        .navigationBarHidden(true)
        .overlay(
            VStack(spacing: 15) {
                Text("Progress")
                    .font(.headline)
                    .padding(.top, 7)
            }
            , alignment: .top
        )
        .overlay(
            Button {
                mode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "arrow.backward")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(10)
            }
            .buttonStyle(.automatic)
            .padding(.leading)

            , alignment: .topLeading
        )
        .overlay(
            VStack {
                LinearGradient(colors: [.clear, .black.opacity(0.3), .black.opacity(0.7)], startPoint: .bottom, endPoint: .top)
                    .frame(height: UIScreen.main.bounds.height/12)
                Spacer()
            }
            .ignoresSafeArea()
        )
        .onAppear {
//            viewModel.fetchPosts()
        }
    }
}

#Preview {
    CalendarView()
}
