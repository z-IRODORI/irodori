//
//  PartnerHomeBriefingAndDataCards.swift
//  irodori
//
//  taste-skill (references/app-screens.md) 準拠:
//  - 影やグラデーション、アイコン入り色付きボックス、二重トレイ（白カード内のグレー箱）を排除
//  - Ground (#F9FAFB) 上に Flat Surface (#FFFFFF) + 1px Border (#E8E8E8) のみで階層を表現
//  - 複数項目は個別の箱に分けず、1つのコンテナを 1px Hairline (#EFEFEF) で分割 ("Group, don't box")
//  - 数値はすべて tabular-nums (.monospacedDigit()) で右揃え
//

import SwiftUI

// MARK: - taste-skill Design Tokens (Light)

enum TasteTokens {
    static let ground = Color(red: 0.976, green: 0.980, blue: 0.984)      // #F9FAFB
    static let surface = Color.white                                       // #FFFFFF
    static let raised = Color(red: 0.965, green: 0.965, blue: 0.969)       // #F6F6F7
    static let warmGround = Color(red: 0.969, green: 0.965, blue: 0.949)   // #F7F6F2 (framed-sheet chrome)
    static let border = Color(red: 0.910, green: 0.910, blue: 0.910)       // #E8E8E8 (1px card edge)
    static let rule = Color(red: 0.937, green: 0.937, blue: 0.937)         // #EFEFEF (1px row divider)
    static let controlBorder = Color(red: 0.820, green: 0.835, blue: 0.859)// #D1D5DB (1px button border)
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.067)          // #111111 (primary text)
    static let muted = Color(red: 0.373, green: 0.388, blue: 0.408)        // #5F6368 (secondary text >= 4.5:1)
    static let faint = Color(red: 0.420, green: 0.420, blue: 0.420)        // #6B6B6B (meta text >= 4.5:1)
    static let primaryFill = Color(red: 0.114, green: 0.122, blue: 0.125)  // #1D1F20 (near-black primary)
    static let dataHue = Color(red: 0.114, green: 0.373, blue: 0.749)      // #1D5FBF (achromatic-ledger signal)

    static let cardRadius: CGFloat = 10
    static let controlRadius: CGFloat = 6
    static let chipRadius: CGFloat = 4
}

// MARK: - Layer 1: 相棒ヘッダー（タップで相棒画面へ）

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
        return "クリーン・スタンダード"
    }

    private var subtitle: String {
        if let sub = partnerHome?.partner_subtitle, !sub.isEmpty { return sub }
        if let sub = persistedOnboarding?.partner_subtitle, !sub.isEmpty { return sub }
        return closetCount > 0 ? "手持ち \(closetCount)点を反映" : "4つの好みを反映"
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
        return "今日の気温と手持ちの服から、無理なく着られる3案を選んでいます。"
    }

    var body: some View {
        Button(action: onTapPartnerProfile) {
            VStack(alignment: .leading, spacing: 0) {
                // 上段: 相棒アイデンティティ行 (52pt pitch, 装飾バッジなし)
                HStack(alignment: .center, spacing: 12) {
                    PartnerIconImage(size: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(TasteTokens.border, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(typeName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TasteTokens.ink)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(TasteTokens.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Text("相棒・相談")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TasteTokens.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TasteTokens.faint)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 1px hairline rule (カード内カードを作らず、1px線で区切る)
                Rectangle()
                    .fill(TasteTokens.rule)
                    .frame(height: 1)

                // 下段: 今日の一言（フラットな白面の上にそのまま組む）
                Text(briefingText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TasteTokens.ink)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(TasteTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: TasteTokens.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: TasteTokens.cardRadius)
                    .stroke(TasteTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layer 3: データ獲得セクション ("Group, don't box" — 1px罫線リスト)

struct PartnerDataAcquisitionCard: View {
    let closetCount: Int
    let onTapPhotoAutoPick: () -> Void
    let onTapSelectStandardItems: () -> Void
    let onTapKeywordSearch: () -> Void
    let onTapTasteVote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // セクション見出しはカードの外側上部に置く (taste-skill §3.4 / §7.2)
            HStack(alignment: .firstTextBaseline) {
                Text("クローゼットと好み")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TasteTokens.ink)

                Spacer()

                Text("登録 \(closetCount)点")
                    .font(.system(size: 12, weight: .regular).monospacedDigit())
                    .foregroundStyle(TasteTokens.muted)
            }

            // 1つのフラットな白コンテナを 1px hairline で3行に分割 (アイコン箱・背景色箱は使わない)
            VStack(spacing: 0) {
                ledgerRow(
                    title: "写真フォルダから全身写真を検出",
                    meta: "AI自動選択",
                    action: onTapPhotoAutoPick
                )

                Rectangle()
                    .fill(TasteTokens.rule)
                    .frame(height: 1)
                    .padding(.leading, 16)

                ledgerRow(
                    title: "定番アイテム・キーワードから追加",
                    meta: "写真なし",
                    action: onTapSelectStandardItems
                )

                Rectangle()
                    .fill(TasteTokens.rule)
                    .frame(height: 1)
                    .padding(.leading, 16)

                ledgerRow(
                    title: "2つのコーデを見比べて好みを登録",
                    meta: "2択比較",
                    action: onTapTasteVote
                )
            }
            .background(TasteTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: TasteTokens.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: TasteTokens.cardRadius)
                    .stroke(TasteTokens.border, lineWidth: 1)
            )
        }
    }

    private func ledgerRow(
        title: String,
        meta: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptic.impact(.soft)
            action()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TasteTokens.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(meta)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(TasteTokens.muted)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TasteTokens.faint)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
