//
//  PartnerHomeBriefingAndDataCards.swift
//  irodori
//
//  UI/UXリニューアル：
//  1) Layer 1: 相棒のデイリーブリーフィングカード（相棒アイコン＋名前＋今日の一言を統合し、カード全体タップで相棒画面へ遷移）
//  2) Layer 3: 相棒からのデータ獲得提案カード（コンパクトな3タイル構成）
//

import SwiftUI

// MARK: - Layer 1: 相棒デイリーブリーフィングカード（タップで相棒画面へ）

struct PartnerHomeBriefingCard: View {
    let partnerHome: PartnerHomeResponse?
    let persistedOnboarding: PartnerOnboardingResponse?
    let closetCount: Int
    let partnerCommentFromDaily: String?
    let onTapPartnerProfile: () -> Void
    let onTapRetakeOnboarding: () -> Void

    private var typeName: String {
        if let name = partnerHome?.type_name, !name.isEmpty { return name }
        if let name = persistedOnboarding?.type_name, !name.isEmpty { return name }
        if let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerImage.rawValue), !saved.isEmpty {
            return saved
        }
        return "ナチュラル・パートナー"
    }

    private var subtitle: String {
        if let sub = partnerHome?.partner_subtitle, !sub.isEmpty { return sub }
        if let sub = persistedOnboarding?.partner_subtitle, !sub.isEmpty { return sub }
        return closetCount > 0 ? "手持ち服 \(closetCount)点と好みを反映中" : "4つの好みを反映中"
    }

    private var briefingText: String {
        if let comment = partnerCommentFromDaily, !comment.isEmpty {
            return comment
        }
        if let text = partnerHome?.home_briefing, !text.isEmpty {
            return text
        }
        if let text = persistedOnboarding?.home_briefing, !text.isEmpty {
            return text
        }
        if let greeting = partnerHome?.greeting, !greeting.isEmpty {
            return greeting
        }
        return "おはようございます。今日の気温とあなたの好みに合わせて、無理なく着られる3案を選びました。"
    }

    var body: some View {
        Button(action: onTapPartnerProfile) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        PartnerIconImage(size: 50)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(Color.black)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(typeName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)

                            Text("相棒画面へ ›")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.65))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }

                // 相棒からの今日の一言（吹き出しボックス）
                Text(briefingText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layer 3: 相棒からのデータ獲得提案カード（コンパクト3タイル）

struct PartnerDataAcquisitionCard: View {
    let closetCount: Int
    let onTapPhotoAutoPick: () -> Void
    let onTapSelectStandardItems: () -> Void
    let onTapKeywordSearch: () -> Void
    let onTapTasteVote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("相棒に手持ち服・好みを教える")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Text(closetCount > 0 ? "手持ち \(closetCount)点" : "未登録")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                actionTile(
                    icon: "photo.on.rectangle.angled",
                    title: "写真から検出",
                    subtitle: "全身写真をAI選択",
                    isPrimary: true,
                    action: onTapPhotoAutoPick
                )

                actionTile(
                    icon: "tshirt",
                    title: "定番・検索",
                    subtitle: "写真なしで追加",
                    isPrimary: false,
                    action: onTapSelectStandardItems
                )

                actionTile(
                    icon: "heart.text.square",
                    title: "2択で好み",
                    subtitle: "直感で選ぶだけ",
                    isPrimary: false,
                    action: onTapTasteVote
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func actionTile(
        icon: String,
        title: String,
        subtitle: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptic.impact(.soft)
            action()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : .black)
                    .frame(width: 34, height: 34)
                    .background(isPrimary ? Color.black : Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
