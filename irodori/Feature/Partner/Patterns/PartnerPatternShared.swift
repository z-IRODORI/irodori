//
//  PartnerPatternShared.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  相棒画面 5パターンの共有コンポーネント。
//

import SwiftUI

// MARK: - パターン切替

enum PartnerPatternVariant: Int, CaseIterable, Identifiable {
    case dailyTalk = 1     // ① 朝の相棒（デイリー対話）
    case insightCards = 2  // ② 相棒の気づき（インサイトカード）
    case growth = 3        // ③ 育つ相棒（育成）
    case tasteVote = 4     // ④ 好みスワイプ（2択投票）
    case notebook = 5      // ⑤ あなた研究ノート（仮説と検証）
    case classic = 0       // 現行デザイン

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .classic: return "現行デザイン"
        case .dailyTalk: return "① 朝の相棒"
        case .insightCards: return "② 相棒の気づき"
        case .growth: return "③ 育つ相棒"
        case .tasteVote: return "④ 好みスワイプ"
        case .notebook: return "⑤ 研究ノート"
        }
    }
}

// MARK: - 相棒の吹き出し

/// 相棒アイコン + 吹き出しの横並び。行数制限なしで長文も表示できる。
struct PartnerTalkBubble: View {
    let text: String
    var subText: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PartnerIconImage(size: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let subText {
                    Text(subText)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
            }
        }
    }
}

// MARK: - 理解度チップ

/// 「Lv.2 かおみしり ・ 理解度 24%」のコンパクト表示
struct PartnerUnderstandingChip: View {
    let state: PartnerState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundColor(.pink)

            Text("Lv.\(state.level) \(state.level_name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black)

            Text("理解度 \(state.understanding_pct)%")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - 理解度バー

/// 理解度のプログレスバー（次のレベルまでの残り表示つき）
struct PartnerUnderstandingBar: View {
    let state: PartnerState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("あなたへの理解度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                Text("\(state.understanding_pct)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.pink)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.7), .pink],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(state.understanding_pct) / 100)
                        .animation(.easeInOut(duration: 0.6), value: state.understanding_pct)
                }
            }
            .frame(height: 8)

            if state.exp_to_next > 0 {
                Text("Lv.\(state.level + 1) まで あと \(state.exp_to_next)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - 経験値トースト

/// 「+10 また少し仲良くなれた」の小さなバナー
struct PartnerExpToast: View {
    let exp: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))

            Text("+\(exp) また少し仲良くなれた")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.pink)
        .clipShape(Capsule())
        .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 経験値トースト表示モディファイア

extension View {
    /// expGained が設定されたら上部にトーストを表示し、自動で消す
    func partnerExpToast(_ expGained: Binding<Int?>) -> some View {
        overlay(alignment: .top) {
            if let exp = expGained.wrappedValue {
                PartnerExpToast(exp: exp)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation(.easeIn(duration: 0.25)) {
                            expGained.wrappedValue = nil
                        }
                    }
            }
        }
    }
}

// MARK: - 共通ユーティリティ

enum PartnerPatternUtility {
    static var userId: String {
        UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
    }

    /// UserDefaults の性別を API 値（men / women）へ正規化
    static var apiGender: String {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        if let gender = Gender.fromApiValue(raw) {
            return gender.apiValue
        }
        if let raw, let gender = Gender(rawValue: raw) {
            return gender.apiValue
        }
        return "women"
    }
}
