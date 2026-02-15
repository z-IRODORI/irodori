//
//  HomeView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct HomeView: View {
//    @State var viewModel: HomeViewModel = .init(apiClient: MockHomeClient())
    @State var viewModel: HomeViewModel = .init(apiClient: HomeClient())
    @State private var plannerViewModel: PlannerViewModel = .init()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 40) {
                Header()
                // TODO: 直近のコーデが存在しない場合のUIを考える
                // 直近のコーデが存在しない場合、コーデだけではなく分析やタグを表示できないので、それも踏まえてUIを考える
                RecentCoordinates(recentCoordinates: viewModel.homeResponse.recent_coordinates)
                    .padding(.horizontal, -24)

                VStack(spacing: 12) {
                    Text("コーデ提案")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
//                    WeeklyPlannerContent(
//                        calendarList: plannerViewModel.calendarList,
//                        selectedDateID: $plannerViewModel.selectedDateID,
//                        relativeDateText: plannerViewModel.relativeDateText,
//                        onSelectDate: { id in plannerViewModel.selectDate(id: id) },
//                        isCurrentMonth: { date in plannerViewModel.isCurrentMonth(date: date) }
//                    )
//                    .padding(.horizontal, -24)
                    
                    ThreeDaysPlanner(
                        calendarList: plannerViewModel.calendarList,
                        selectedDateID: $plannerViewModel.selectedDateID,
                        relativeDateText: plannerViewModel.relativeDateText,
                        onSelectDate: { id in plannerViewModel.selectDate(id: id) },
                        isCurrentMonth: { date in plannerViewModel.isCurrentMonth(date: date) },
                        coordinateForDate: { dateID in viewModel.coordinate(for: dateID) },
                        isLoadingForDate: { dateID in viewModel.isLoading(for: dateID) },
                        onAddCoordinateRandom: { dateID in
                            Task {
                                await viewModel.addCoordinateRandom(for: dateID)
                            }
                        },
                        onAddCoordinateByItem: { dateID in
                            Task {
                                await viewModel.addCoordinateByItem(for: dateID)
                            }
                        }
                    )
                    .padding(.horizontal, -24)
                }

                // コーデの分析
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(.wolf)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        SpeechBubbleView(text: "これまでのコーデを分析しました")
                    }
                    if !viewModel.recentCoordinateAnalysis.isEmpty {
                        Text(.init(viewModel.recentCoordinateAnalysis))
                            .font(.system(size: 16, weight: .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // これまでのタグ
                VStack(spacing: 12) {
                    Text("これまでのタグ")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let tags = viewModel.homeResponse.tags {
                        TagsView(tags: tags, tagTextColor: .black, borderColor: .gray, tagFont: .system(size: 14, weight: .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("タグが存在しません")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            Task {
                await viewModel.onAppear()
            }
        }
        .background(.gray.opacity(0.08))
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                Button(action: {
                    // action
                }, label: {
                    Text("写真選択")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .frame(height: 50)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                })

                Button(action: {
                    // action
                }, label: {
                    Text("カメラ")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .frame(height: 50)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                })
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .background(.white)
        }
    }

    private func Header() -> some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)
            HStack(spacing: 24) {
                Button(action: {
                    // ログ送信
                    // 画面遷移
                }) {
                    Image(systemName: "calendar")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.black)
                }

                Button(action: {
                    // ログ送信
                    // オンボーディング画面表示
                }) {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
    }
}

#Preview {
    HomeView()
}
