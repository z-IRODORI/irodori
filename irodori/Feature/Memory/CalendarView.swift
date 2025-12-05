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

    @Environment(\.presentationMode) var mode
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
        ZStack(alignment: .top) {
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

                                        let params: ViewType.CoordinateDetailParams = .init(uid: viewModel.uid, targetDateString: targetDateString, coordinateImageURL: coordinateImageURL)
                                        path.append(.coordinateDetail(params))
                                    }) {
                                        Card(coordinateImageURL: coordinateImageURL)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 75)
            }

            Header()
                .padding(.horizontal, 12)
        }
        .navigationBarHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            AnalyticsLogger.shared.log(screen: .memoryCalendarScreenView)
            await viewModel.onAppear()
        }
    }

    private func Header() -> some View {
        ZStack {
            Text("カレンダー")
                .font(.headline)
                .padding(.top, 7)

            Button {
                AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                    "action": GAEventAction.backToCamera.rawValue
                ])
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

    private func Card(coordinateImageURL: String) -> some View {
        CachedAsyncImage(url: URL(string: coordinateImageURL)!) { phase in
            if let image = phase.image {
                image.resizable()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.5))
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
    }
}

#Preview {
    CalendarView(viewModel: .init(apiClient: CoordinateListClient()), path: .constant([]))
}
