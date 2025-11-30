//
//  HomeView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct HomeView: View {
    let client: FashionReviewClientProtocol = MockFashionReviewClient()   // TODO: 消す
    @State private var recentCoordinates: [FashionReviewResponse.RecentCoordinate] = []
    @State private var tags: [String] = [
        "カジュアル",
        "着回し力抜群",
        "高見え",
        "トレンド",
        "購入品紹介",
        "イエベ春",
        "きれいめ",
        "秋コーデ",
        "身長160cm"
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 40) {
                Header()
                RecentCoordinates(recentCoordinates: recentCoordinates)
                    .padding(.horizontal, -24)

                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(.wolf)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        SpeechBubbleView(text: "これまでのコーデを分析するよ")
                    }
                    Text("hogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehogehoge")
                }

                VStack(spacing: 12) {
                    Text("これまでのタグ")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TagsView(tags: tags, tagTextColor: .black, borderColor: .gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            Task {
                let result = try await client.post(uid: "", image: .init(), purposeNum: nil)
                switch result {
                case .success(let value):
                    self.recentCoordinates = value.recent_coordinates
                case .failure:
                    break
                }
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
            .padding(.horizontal, 24)
        }
    }

    private func Header() -> some View {
        ZStack {
            Text("IRODORI")
                .font(.system(size: 24, weight: .bold))
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
