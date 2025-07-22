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

    @Binding var path: [ViewType]
    @State var viewModel: CalendarViewModel = .init()

    var body: some View {

        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {

                // Amount of months since December 2022
                ForEach(viewModel.months) { month in
                    Text("\(month.title)  \(String(month.year))")
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
                        ForEach(1..<month.spacesBeforeFirst, id: \.self) { _ in
                            Text("")
                        }

                        // Days in a month
                        ForEach(1..<month.amountOfDays + 1, id: \.self) { i in
                            CalendarCell(
                                thumbnailImageURL: "https://images.wear2.jp/coordinate/bBildLXx/oztkGRxb/1749994312_1000.jpg",
                                height: UIScreen.main.bounds.width/6.5,
                                dayOfMonth: i
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 75)
            }

//            Header()
//                .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .overlay(
            VStack(spacing: 15) {
                Text("カレンダー")
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 30)
    }
}

#Preview {
    CalendarView(path: .constant([]))
}
