//
//  RenewalComponents.swift
//  irodori - Sandbox
//
//  リニューアル体験 Sandbox の共通部品。
//  見た目は「白カード + 1px 境界線、影なし、絵文字なし」(app_ecosystem_and_improvement_design.md §5④) に統一。
//  文字は 11pt 以上、補足文は #5F6368 (白地で AA)、タップ領域は 44pt 以上を守る。
//

import SwiftUI

// MARK: - 相棒アバター (16タイプの画像を type_name で引く。本番の UserDefaults は読まない)

struct RenewalPartnerAvatar: View {
    let typeName: String
    var size: CGFloat = 44
    /// 誕生前の「無色の相棒」
    var colorless: Bool = false

    var body: some View {
        Group {
            if UIImage(named: "\(typeName)_icon") != nil {
                Image("\(typeName)_icon").resizable().scaledToFill()
            } else if UIImage(named: typeName) != nil {
                Image(typeName).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(RenewalTokens.border, lineWidth: 1))
        .saturation(colorless ? 0 : 1)
        .opacity(colorless ? 0.35 : 1)
        .accessibilityHidden(true)
    }
}

/// 相棒の全身イラスト (誕生画面用)
struct RenewalPartnerIllustration: View {
    let typeName: String
    var height: CGFloat = 200
    var colorless: Bool = false

    var body: some View {
        Group {
            if UIImage(named: typeName) != nil {
                Image(typeName).resizable().scaledToFit()
            } else {
                RenewalPartnerAvatar(typeName: typeName, size: height * 0.6)
            }
        }
        .frame(height: height)
        .saturation(colorless ? 0 : 1)
        .opacity(colorless ? 0.25 : 1)
        .accessibilityHidden(true)
    }
}

// MARK: - アイテムのシルエット (写真の代わり。商品画像は使わない)

struct RenewalPantsShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.18, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.3))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.06, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct RenewalCoatShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * 0.14, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.22))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.14, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.06))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.7))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.72))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.18, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.72))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.7))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.06))
        p.closeSubpath()
        return p
    }
}

struct RenewalShoeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.15))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.15))
        p.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.78),
            control: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.55)
        )
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.3))
        p.closeSubpath()
        return p
    }
}

struct RenewalGarmentGlyph: View {
    let staple: RenewalStaple
    var size: CGFloat

    var body: some View {
        let stroke = staple.isLight ? RenewalTokens.controlBorder : Color.clear
        Group {
            switch staple.category {
            case .top:
                Image(systemName: "tshirt.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(staple.color)
                    .overlay(
                        Image(systemName: "tshirt")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(stroke)
                    )
            case .bottom:
                RenewalPantsShape().fill(staple.color)
                    .overlay(RenewalPantsShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(0.72, contentMode: .fit)
            case .outer:
                RenewalCoatShape().fill(staple.color)
                    .overlay(RenewalCoatShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(0.85, contentMode: .fit)
            case .shoes:
                RenewalShoeShape().fill(staple.color)
                    .overlay(RenewalShoeShape().stroke(stroke, lineWidth: 1))
                    .aspectRatio(1.8, contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
    }
}

/// アイテム1点のサムネイル (シルエット + 名前)
struct RenewalItemTile: View {
    let staple: RenewalStaple
    var size: CGFloat = 64
    var owned: Bool = true
    var showName: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            RenewalGarmentGlyph(staple: staple, size: size * 0.62)
                .frame(width: size, height: size)
                .background(RenewalTokens.raised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(owned ? RenewalTokens.border : RenewalTokens.controlBorder,
                                style: StrokeStyle(lineWidth: 1, dash: owned ? [] : [3, 2.5]))
                )
            if showName {
                Text(staple.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(owned ? RenewalTokens.ink : RenewalTokens.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: size + 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(owned ? "手持ち: \(staple.name)" : "未所持: \(staple.name)")
    }
}

// MARK: - 着こなしイメージ (Pinterest お手本の代わりのプレースホルダー)

/// 本番では「手持ちの組み合わせに最も近い Pinterest 画像」が入る枠。
/// Sandbox では実画像を使わず、色だけで構成したシルエット + SAMPLE 透かしで明示する。
struct RenewalExampleImage: View {
    let recipe: RenewalRecipe
    var height: CGFloat = 220
    /// 左上のラベル。写真発掘では「全身写真」、カレンダーでは nil (ラベルなし)
    var badge: String? = "着こなしイメージ"

    private func staple(_ c: RenewalCategory) -> RenewalStaple? {
        recipe.allStaples.first { $0.category == c }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [RenewalTokens.raised, (staple(.bottom)?.color ?? .gray).opacity(0.12)],
                startPoint: .top, endPoint: .bottom
            )
            mannequin
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 14)

            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
                    .padding(8)
            }

            Text("SAMPLE")
                .font(.system(size: 26, weight: .heavy))
                .tracking(4)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(RenewalTokens.ink.opacity(0.07))
                .rotationEffect(.degrees(-24))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge ?? "コーデ") (サンプル): \(recipe.mainFamily.vibe)")
    }

    private var mannequin: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = h * 0.42
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(red: 0.86, green: 0.83, blue: 0.80))
                    .frame(width: w * 0.28, height: w * 0.28)
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.12)
                        .fill(staple(.top)?.color ?? Color.white)
                        .overlay(RoundedRectangle(cornerRadius: w * 0.12).stroke(RenewalTokens.controlBorder, lineWidth: (staple(.top)?.isLight ?? true) ? 1 : 0))
                        .frame(width: w * 0.62, height: h * 0.32)
                    if let outer = staple(.outer) {
                        HStack(spacing: w * 0.16) {
                            RoundedRectangle(cornerRadius: w * 0.08).fill(outer.color).frame(width: w * 0.24)
                            RoundedRectangle(cornerRadius: w * 0.08).fill(outer.color).frame(width: w * 0.24)
                        }
                        .frame(height: h * 0.36)
                    }
                }
                RenewalPantsShape()
                    .fill(staple(.bottom)?.color ?? Color.gray)
                    .overlay(RenewalPantsShape().stroke(RenewalTokens.controlBorder, lineWidth: (staple(.bottom)?.isLight ?? false) ? 1 : 0))
                    .frame(width: w * 0.56, height: h * 0.40)
                HStack(spacing: w * 0.06) {
                    Capsule().fill(staple(.shoes)?.color ?? RenewalTokens.ink)
                    Capsule().fill(staple(.shoes)?.color ?? RenewalTokens.ink)
                }
                .frame(width: w * 0.6, height: h * 0.05)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 文字数バッジ (黄金律 45〜65字の確認)

struct RenewalCharCountBadge: View {
    let text: String

    var body: some View {
        let n = text.count
        let ok = RenewalCopy.idealRange.contains(n)
        Text("\(n)字")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(ok ? RenewalTokens.learned : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius).stroke(ok ? RenewalTokens.learned.opacity(0.4) : .orange.opacity(0.5), lineWidth: 1))
            .accessibilityLabel("\(n)文字\(ok ? "、基準内" : "、基準外")")
    }
}

// MARK: - 「行動から学習」タグ

struct RenewalLearnedTag: View {
    var body: some View {
        Text("行動から学習")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(RenewalTokens.learned)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RenewalTokens.learned.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
    }
}

// MARK: - カード枠

struct RenewalCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius).stroke(RenewalTokens.border, lineWidth: 1))
    }
}

extension View {
    func renewalCard() -> some View { modifier(RenewalCardBackground()) }
}

// MARK: - ボタン

struct RenewalPrimaryButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(filled ? .white : RenewalTokens.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(filled ? RenewalTokens.primaryFill : RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius).stroke(filled ? Color.clear : RenewalTokens.controlBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - 相棒からのトースト (上部)

struct RenewalToastView: View {
    let toast: RenewalStore.Toast
    let typeName: String
    var showCount: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if toast.isProgress {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                RenewalPartnerAvatar(typeName: typeName, size: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if showCount && !toast.isProgress {
                    RenewalCharCountBadge(text: toast.message)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .renewalCard()
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - セクション見出し

struct RenewalSectionTitle: View {
    let title: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .accessibilityAddTraits(.isHeader)
            if let caption {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
