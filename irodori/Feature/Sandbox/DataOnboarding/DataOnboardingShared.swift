//
//  DataOnboardingShared.swift
//  irodori - Sandbox
//
//  初回の4問 → 相棒誕生のあとに挟む「相棒に服やコーデを教える」オンボーディングの共通部品。
//  伝えること: ①服やコーデを教えると提案が自分の服になる ②教え方 ③教えると記録 (実績) が増える (やんわり)
//

import SwiftUI

// MARK: - 教え方 (本番の導線と1対1)

enum DataOnbChannel: String, CaseIterable, Identifiable {
    /// FullBodyPickerView (AIで写真を探す)。いちばん多く覚えられる
    case fullBody
    /// StandardItemPicker (定番アイテムを選ぶ)。写真なし
    case standard
    /// CameraView (コーデを記録)。今日着ている服
    case camera

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullBody: return "photo.on.rectangle.angled"
        case .standard: return "tshirt"
        case .camera: return "camera"
        }
    }

    var title: String {
        switch self {
        case .fullBody: return "写真フォルダから探す"
        case .standard: return "持っている服を選ぶ"
        case .camera: return "今日のコーデを撮る"
        }
    }

    var detail: String {
        switch self {
        case .fullBody: return "全身が写った写真をAIが探して、服とコーデをまとめて覚えるよ"
        case .standard: return "白T・デニムなど定番から選ぶだけ。写真はいらないよ"
        case .camera: return "いま着ている服を1枚。着た日の記録にもなるよ"
        }
    }

    /// 手間の目安
    var effort: String {
        switch self {
        case .fullBody: return "約1分"
        case .standard: return "約30秒"
        case .camera: return "約10秒"
        }
    }

    /// 相棒が覚えること
    var teaches: String {
        switch self {
        case .fullBody: return "服とコーデ"
        case .standard: return "持っている服"
        case .camera: return "今日のコーデ"
        }
    }

    var hue: PartnerHue {
        switch self {
        case .fullBody: return .lilac
        case .standard: return .mint
        case .camera: return .peach
        }
    }

    /// 教えると残る記録 (= 実績。相棒画面のミッションと対応: closet_5 / photo_1)
    var stampTitle: String {
        switch self {
        case .fullBody: return "はじめて写真を見せた"
        case .standard: return "クローゼットをひらいた"
        case .camera: return "はじめての1枚"
        }
    }

    /// 本番で開く画面 (Sandbox のトーストで表示)
    var destination: String {
        switch self {
        case .fullBody: return "AIで写真を探す (FullBodyPickerView)"
        case .standard: return "定番アイテムを選ぶ (StandardItemPicker)"
        case .camera: return "コーデを記録 (CameraView)"
        }
    }
}

// MARK: - 共有の状態 (案を切り替えても「教えた」状態は残す)

@Observable
final class DataOnbSandboxState {
    var picked: [DataOnbChannel] = []
    var lastPicked: DataOnbChannel?
    var finished = false

    func pick(_ c: DataOnbChannel) {
        Haptic.notify(.success)
        if !picked.contains(c) { picked.append(c) }
        lastPicked = c
    }

    func reset() {
        picked = []
        lastPicked = nil
        finished = false
    }
}

// MARK: - 相棒の吹き出し

struct DataOnbBubble: View {
    let text: String
    var iconSize: CGFloat = 32
    var showsIcon = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if showsIcon {
                PartnerIconImage(size: iconSize)
            } else {
                Color.clear.frame(width: iconSize, height: 1)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(RenewalTokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RenewalTokens.surface, in: UnevenRoundedRectangle(
                    topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18,
                    style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            Spacer(minLength: 32)
        }
    }
}

// MARK: - 提案の見えかた (知っていることの量で3段階)

/// 3案の見本。色ブロックでトップス・ボトムス・靴を表す (実在の商品は出さない)
struct DataOnbOutfitPreview: View {
    /// 0: 4つの答えだけ / 1: 服を何点か / 2: 服とコーデ
    let level: Int
    var compact = false

    private static let palettes: [[Color]] = [
        [Color(white: 0.96), Color(red: 0.20, green: 0.27, blue: 0.40), Color(white: 0.15)],
        [Color(red: 0.93, green: 0.90, blue: 0.84), Color(red: 0.38, green: 0.33, blue: 0.27), Color(white: 0.92)],
        [Color(red: 0.12, green: 0.12, blue: 0.13), Color(red: 0.62, green: 0.62, blue: 0.60), Color(white: 0.15)],
    ]

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ForEach(0..<3, id: \.self) { i in
                column(Self.palettes[i], index: i)
            }
        }
        .animation(.spring(duration: 0.5), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["相棒の想像で組んだ3案", "手持ちの服を少し使った3案", "手持ちの服とあなたのクセで組んだ3案"][min(level, 2)])
    }

    /// その段階で手持ち (塗り) になるパーツ数
    private func ownedCount(_ index: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return index == 0 ? 2 : 1
        default: return 3
        }
    }

    private func column(_ colors: [Color], index: Int) -> some View {
        let owned = ownedCount(index)
        let h: [CGFloat] = compact ? [30, 34, 12] : [44, 50, 16]
        return VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { p in
                DataOnbOutfitPart(color: colors[p], owned: p < owned, compact: compact)
                    .frame(height: h[p])
            }
            HStack(spacing: 3) {
                Image(systemName: owned == 3 ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 9, weight: .semibold))
                Text(owned == 3 ? "手持ち" : owned == 0 ? "想像" : "一部手持ち")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(owned == 3 ? RenewalTokens.ink : RenewalTokens.muted)
            .padding(.top, 2)
            .transaction { $0.animation = nil } // 文字の入れ替わりで二重に見えないように
        }
        .padding(compact ? 8 : 10)
        .frame(maxWidth: .infinity)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(RenewalTokens.border))
    }
}

/// 見本の1パーツ。手持ちなら色で塗り、まだなら点線と「?」
private struct DataOnbOutfitPart: View {
    let color: Color
    let owned: Bool
    let compact: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        if owned {
            shape.fill(color)
                .overlay(shape.strokeBorder(Color.black.opacity(0.08)))
        } else {
            shape.strokeBorder(RenewalTokens.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: compact ? 9 : 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.controlBorder)
                }
        }
    }
}

// MARK: - 教え方の行

struct DataOnbChannelRow: View {
    let channel: DataOnbChannel
    var recommended = false
    var done = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark" : channel.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(channel.hue.ink)
                    .frame(width: 44, height: 44)
                    .background(channel.hue.wash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(channel.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                        if recommended && !done {
                            Text("おすすめ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RenewalTokens.ink, in: Capsule())
                        }
                    }
                    Text(channel.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Text(done ? "済み" : channel.effort)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(done ? "教えた" : "\(channel.effort)。\(channel.teaches)を相棒に教える")
    }
}

// MARK: - 記録 (実績) のスタンプ

/// 教えるたびにひとつ色がつくスタンプ。押していないものは薄い輪郭だけ
struct DataOnbStamp: View {
    let channel: DataOnbChannel
    let unlocked: Bool
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked ? channel.hue.wash : Color.clear)
            Circle()
                .strokeBorder(unlocked ? channel.hue.ink.opacity(0.5) : RenewalTokens.controlBorder,
                              style: StrokeStyle(lineWidth: 1.2, dash: unlocked ? [] : [3, 3]))
            Image(systemName: unlocked ? channel.icon : "sparkle")
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(unlocked ? channel.hue.ink : RenewalTokens.controlBorder)
        }
        .frame(width: size, height: size)
        .scaleEffect(unlocked ? 1 : 0.92)
        .animation(.spring(duration: 0.45, bounce: 0.45), value: unlocked)
        .accessibilityLabel(unlocked ? "記録「\(channel.stampTitle)」" : "まだの記録")
    }
}

/// 3つのスタンプを並べた行
struct DataOnbStampRow: View {
    let picked: [DataOnbChannel]
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DataOnbChannel.allCases) { c in
                DataOnbStamp(channel: c, unlocked: picked.contains(c), size: size)
            }
        }
    }
}

// MARK: - 「教えた」トースト (Sandbox 専用: 本番ではここで各画面が開く)

struct DataOnbPickedToast: View {
    let channel: DataOnbChannel

    var body: some View {
        HStack(spacing: 12) {
            DataOnbStamp(channel: channel, unlocked: true, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("記録がひとつ増えたよ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Text("「\(channel.stampTitle)」")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                Text("Sandbox: 本番ではここで \(channel.destination) が開きます")
                    .font(.system(size: 10))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - 下部の主ボタン

struct DataOnbPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.medium)
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(RenewalTokens.primaryFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct DataOnbLaterButton: View {
    var title = "あとで教える"
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
