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
    
    private var columns = [
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center),
        GridItem.init(.flexible(), alignment: .center)
    ]

    @State var viewModel: CalendarViewModel = .init()

    var body: some View {

        ScrollView(showsIndicators: false) {

            // Amount of months since December 2022
            ForEach(viewModel.months) { month in
                Text("\(month.title). \(month.year, specifier: "%d")")
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
                            beforeImageURL: "",
                            afterImageURL: "https://images.wear2.jp/coordinate/bBildLXx/oztkGRxb/1749994312_1000.jpg",
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
