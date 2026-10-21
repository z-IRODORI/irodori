//
//  RenewalRecipeFeedback.swift
//  irodori
//
//  コーデ提案のカードごとに、相棒へ感想を返す行。
//  相棒が「この案どう？」と聞き、ユーザーは「いいね」か「ちょっと違う」で返す。
//  「ちょっと違う」はその場で相棒が理由を聞き (シートを出さない)、選ぶと相棒が返事をして
//  その案だけ見送り済みになる。返事はカードの中に相棒の吹き出しとして残る。
//

import SwiftUI

enum RenewalRecipeReaction: Equatable {
    case sending
    case liked(String)                              // 相棒の返事
    case disliked(RenewalDislikeReason, String)     // 理由と相棒の返事
    case failed

    var isDisliked: Bool {
        if case .disliked = self { return true }
        return false
    }
}

struct RenewalRecipeFeedbackRow: View {
    let typeName: String
    let reaction: RenewalRecipeReaction?
    var onLike: () -> Void
    var onDislike: (RenewalDislikeReason) -> Void

    @State private var asking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                RenewalPartnerAvatar(typeName: typeName, size: 22)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if asking && reaction == nil {
                reasonGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: asking)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: reaction)
    }

    @ViewBuilder
    private var content: some View {
        switch reaction {
        case .none:
            HStack(spacing: 6) {
                Text(asking ? "どこが違った？" : "この案どう？")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(asking ? RenewalTokens.ink : RenewalTokens.muted)
                Spacer(minLength: 4)
                if asking {
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
                    asking = false
                    onDislike(reason)
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
