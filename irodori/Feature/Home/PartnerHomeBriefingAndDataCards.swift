//
//  PartnerHomeBriefingAndDataCards.swift
//  irodori
//
//  UI/UXリニューアル：
//  1) Layer 1: 相棒のデイリーブリーフィングカード（相棒アイコン・タイプ・反映ステータス・話し方に合わせた今日の理由）
//  2) Layer 3: 相棒からのデータ獲得提案カード（「相棒にもっとあなたのことを教える」：カメラロール自動検出・定番/検索追加・2択好み比較）
//

import SwiftUI

// MARK: - Layer 1: 相棒デイリーブリーフィングカード

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
        return "あなたの相棒"
    }

    private var subtitle: String {
        if let sub = partnerHome?.partner_subtitle, !sub.isEmpty { return sub }
        if let sub = persistedOnboarding?.partner_subtitle, !sub.isEmpty { return sub }
        return "4つの好みを反映中"
    }

    private var statusBadgeText: String {
        if closetCount > 0 {
            return "手持ち服 \(closetCount)点を反映中"
        }
        return "4つの好みを反映中"
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

    private var traits: [PartnerOnboardingTrait] {
        partnerHome?.traits ?? persistedOnboarding?.traits ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 上段: 相棒アイコン + 名前・サブタイトル + 反映ステータスバッジ
            HStack(alignment: .center, spacing: 12) {
                Button(action: onTapPartnerProfile) {
                    PartnerIconImage(size: 46)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(typeName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Text(statusBadgeText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        onTapPartnerProfile()
                    } label: {
                        Label("相棒タブを見る", systemImage: "person.crop.circle")
                    }
                    Button {
                        onTapRetakeOnboarding()
                    } label: {
                        Label("4つの質問に答え直す", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            // 中段: 相棒からの今日のブリーフィング
            Text(briefingText)
                .font(.system(size: 13))
                .foregroundStyle(.black)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // 下段: 反映中の特徴チップ（横スクロール）
            if !traits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(traits) { trait in
                            HStack(spacing: 4) {
                                Text(trait.axis_label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("・")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(trait.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.black)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Layer 3: 相棒からのデータ獲得提案カード

struct PartnerDataAcquisitionCard: View {
    let closetCount: Int
    let onTapPhotoAutoPick: () -> Void
    let onTapSelectStandardItems: () -> Void
    let onTapKeywordSearch: () -> Void
    let onTapTasteVote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー: 相棒からの自然な提案
            HStack(alignment: .top, spacing: 12) {
                PartnerIconImage(size: 38)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("相棒にもっとあなたのことを教える")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }

                    Text(
                        closetCount == 0
                        ? "普段着ている服や好みを教えると、手持ちの服を使ったコーデを提案できるようになります。"
                        : "現在 \(closetCount)点のアイテムを反映しています。手持ちの服や好みを追加するほど、毎日の提案があなたらしくなります。"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                // 提案1: 写真フォルダから自動で見つける (FullBodyPickerView)
                actionRow(
                    icon: "photo.on.rectangle.angled",
                    title: "写真フォルダから自動で見つける",
                    subtitle: "過去の全身写真をAIが見つけて、手持ち服をまとめて登録",
                    badgeText: "おすすめ",
                    isPrimary: true,
                    action: onTapPhotoAutoPick
                )

                // 提案2: 定番アイテムから選ぶ・検索する
                actionRow(
                    icon: "magnifyingglass",
                    title: "定番アイテムから選ぶ・検索する",
                    subtitle: "よく着るベーシックな服をタップしてクローゼットに追加",
                    badgeText: nil,
                    isPrimary: false,
                    action: onTapSelectStandardItems
                )

                // 提案3: 2つのコーデを見比べて好みを教える (PartnerPattern4TasteVoteView)
                actionRow(
                    icon: "heart.text.square",
                    title: "2つのコーデを見比べて好みを教える",
                    subtitle: "写真がない日でも、直感で選ぶだけで相棒が好みを学習",
                    badgeText: nil,
                    isPrimary: false,
                    action: onTapTasteVote
                )
            }

            // 補足リンク: キーワードで細かく探したい人向け
            HStack {
                Spacer()
                Button(action: onTapKeywordSearch) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                        Text("ブランドや商品名で検索して追加する")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        badgeText: String?,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptic.impact(.soft)
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isPrimary ? Color.black : Color.gray.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isPrimary ? .white : .black)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            .padding(14)
            .background(Color.gray.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? Color.black.opacity(0.25) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
