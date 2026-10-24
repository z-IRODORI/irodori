//
//  RenewalRecipeFeedback.swift
//  irodori
//
//  コーデ提案のカードごとに、相棒へ感想を返す行。
//  相棒が「この案どう？」と聞き、ユーザーは「いいね」か「ちょっと違う」で返す。
//  「ちょっと違う」はその場で相棒が理由を聞き (シートを出さない)、選ぶと相棒が返事をして
//  その案だけ代わりの案に入れ替わる。返事は新しいカードの中に相棒の吹き出しとして残る。
//

import SwiftUI

enum RenewalRecipeReaction: Equatable {
    case sending
    case liked(String)                              // 相棒の返事
    case disliked(RenewalDislikeReason, String)     // 理由と相棒の返事
    /// 見送った案の代わりに組み直した案 (相棒の返事を残したまま、もう一度感想を聞く)
    case replaced(String)
    case failed

    var isReplaced: Bool {
        if case .replaced = self { return true }
        return false
    }

    var isDisliked: Bool {
        if case .disliked = self { return true }
        return false
    }
}

struct RenewalRecipeFeedbackRow: View {
    let typeName: String
    let reaction: RenewalRecipeReaction?
    var onLike: () -> Void
    /// 理由と、「色が好みじゃない」のときはどこの色か
    var onDislike: (RenewalDislikeReason, RenewalColorTarget?) -> Void

    @State private var asking = false
    /// 「色が好みじゃない」を選んで、どこの色かを聞いている
    @State private var pickingColor = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                RenewalPartnerAvatarButton(typeName: typeName, size: 22)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if asking && (reaction == nil || reaction?.isReplaced == true) {
                Group {
                    if pickingColor { colorTargetGrid } else { reasonGrid }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: asking)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: pickingColor)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: reaction)
    }

    @ViewBuilder
    private var content: some View {
        switch reaction {
        case .none:
            askRow
        case .replaced(let ack):
            VStack(alignment: .leading, spacing: 6) {
                reply("\(ack) 代わりに組み直したよ", mark: Image(systemName: "arrow.triangle.2.circlepath"), markColor: RenewalTokens.muted)
                askRow
            }
        case .sending:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("相棒に伝えています…")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .frame(minHeight: 28)
        case .liked(let ack):
            reply(ack, mark: Image(systemName: "heart.fill"), markColor: RenewalTokens.accentPink)
        case .disliked(_, let ack):
            reply(ack, mark: Image(systemName: "hand.raised"), markColor: RenewalTokens.muted)
        case .failed:
            HStack(spacing: 6) {
                Text("うまく届かなかったみたい")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                Spacer(minLength: 4)
                chip("いいね", systemImage: "heart", action: onLike)
                chip("ちょっと違う", systemImage: nil) { asking = true }
            }
        }
    }

    /// 「この案どう？」+ いいね / ちょっと違う (選ぶと理由を聞く)
    private var askRow: some View {
        HStack(spacing: 6) {
            Text(pickingColor ? "どこの色が違った？" : asking ? "どこが違った？" : "この案どう？")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(asking ? RenewalTokens.ink : RenewalTokens.muted)
            Spacer(minLength: 4)
            if pickingColor {
                Button("戻る") { pickingColor = false }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .contentShape(Rectangle().inset(by: -12))
            } else if asking {
                Button("やめる") { asking = false }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .contentShape(Rectangle().inset(by: -12))
            } else {
                chip("いいね", systemImage: "heart", action: onLike)
                chip("ちょっと違う", systemImage: nil) {
                    Haptic.selection()
                    asking = true
                }
            }
        }
    }

    /// 相棒の返事 (しっぽ付きの小さな吹き出し)
    private func reply(_ text: String, mark: Image?, markColor: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let mark {
                mark.font(.system(size: 11)).foregroundStyle(markColor).padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .background(RenewalSpeechBubble(radius: 12, tailWidth: 7, tailTop: 8).fill(RenewalTokens.raised))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("相棒: \(text)")
    }

    private var reasonGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(RenewalDislikeReason.allCases) { reason in
                Button {
                    if reason == .color {
                        Haptic.selection()
                        pickingColor = true   // 色はどこの色かを続けて聞く
                    } else {
                        asking = false
                        onDislike(reason, nil)
                    }
                } label: {
                    Text(reason.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RenewalTokens.surface, in: Capsule())
                        .overlay(Capsule().stroke(RenewalTokens.controlBorder, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 30)
    }

    /// 「色が好みじゃない」の続き: トップス / ボトムス / それ以外
    private var colorTargetGrid: some View {
        HStack(spacing: 8) {
            ForEach(RenewalColorTarget.allCases) { target in
                Button {
                    asking = false
                    pickingColor = false
                    onDislike(.color, target)
                } label: {
                    VStack(spacing: 1) {
                        Text(target.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                        Text(target.hint)
                            .font(.system(size: 9))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RenewalTokens.controlBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(target.label)が好みじゃない")
            }
        }
        .padding(.leading, 30)
    }

    private func chip(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(RenewalTokens.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 28)
            .overlay(Capsule().stroke(RenewalTokens.controlBorder, lineWidth: 1))
            // 見た目は小さく、押せる範囲は 44pt 相当に広げる
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
    }
}
