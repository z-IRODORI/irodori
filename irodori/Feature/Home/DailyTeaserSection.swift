//
//  DailyTeaserSection.swift
//  irodori
//
//  20時以降にホーム下部へ出す「明日の先取り」ティザー。
//  明日タブの1枚目をぼかし + スタイル名だけ見せて、翌朝の開封理由を作る。
//  「これにする」した日はぼかしを解放する (投資 → 報酬の連結)。
//

import SwiftUI
import Kingfisher

struct DailyTeaserSection: View {
    let viewModel: HomeViewModel
    /// タップでヒーローの明日タブへ誘導する (スクロールは HomeView 側が管理)
    let onOpenTomorrow: () -> Void

    private var teaserCard: DailyRecommendationItem? {
        viewModel.teaserResponse?.recommendations.first
    }

    /// 「これにする」した日はぼかしを解放 (チラ見せ解放)
    private var isRevealed: Bool { viewModel.hasDecidedToday }

    var body: some View {
        // 20時前・明日タブ未取得 (バッチ未完了含む) は何も出さないフォールバック
        if viewModel.isEveningTeaserTime, let card = teaserCard {
            Button {
                Haptic.impact(.soft)
                onOpenTomorrow()
            } label: {
                HStack(spacing: 14) {
                    KFImage(URL(string: card.image_url))
                        .resizable()
                        .placeholder { Color.gray.opacity(0.15) }
                        .scaledToFill()
                        .frame(width: 76, height: 96)
                        .clipped()
                        .blur(radius: isRevealed ? 0 : 7, opaque: true)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .center) {
                            if !isRevealed {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("明日の先取り")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.3)
                        }
                        .foregroundStyle(Color.indigo)
                        Text(styleName(card))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text(isRevealed
                             ? "決定ずみのあなたには、もう見せちゃう。明日の1枚目だよ"
                             : "明日の3コーデ、支度できたよ。全部は明日のおたのしみ")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.5))
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func styleName(_ card: DailyRecommendationItem) -> String {
        if !card.style.isEmpty { return card.style }
        if !card.vibe.isEmpty { return card.vibe }
        return "おすすめコーデ"
    }
}
