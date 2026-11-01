//
//  RenewalCompactListLayout.swift
//  irodori
//
//  ホームの案を 1 列の低い行で並べる (最初の画面で 4 案すべてが見えるように)。
//    左: 服のボード (小さめ・札なし)
//    中: 見出し (1 行) / 手持ちの状態 / 決定・「違う」
//    右: コーデモデルの写真 (無ければ相棒) / いいね
//  説明・色の並び・大きなボードは、行を押した詳細の画面で見る。
//

import SwiftUI

struct RenewalCompactListLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions
    /// 入場演出の開始秒 (nil = 演出なし)
    var introDelay: Double? = nil
    var introToken: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                let start = introDelay.map { $0 + Double(index) * 0.06 }
                RenewalCompactRow(recipe: recipe, index: index, actions: actions)
                    .coachFrame(.recipes, active: index == 0)
                    .modifier(RenewalIntroRise(delay: start, token: "\(introToken)-\(recipe.recipe_id)"))
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct RenewalCompactRow: View {
    let recipe: OwnedFirstRecipe
    let index: Int
    let actions: RenewalRecipeActions

    @State private var askingReason = false

    /// 服のボードの大きさ。4 行が最初の画面に収まる高さにする
    private static let boardSize: CGFloat = 96

    private var reaction: RenewalRecipeReaction? { actions.reaction(recipe) }
    private var ackText: String? { RenewalRecipeStatus.ack(reaction) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRecipeVisual(recipe: recipe, actions: actions, height: Self.boardSize)
                    .environment(\.renewalCompactBoard, true)
                    .frame(width: Self.boardSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("案\(index + 1) \(recipe.displayTitle)。タップで詳細")

            VStack(alignment: .leading, spacing: 4) {
                if index == 0 { pickBadge }
                Text(recipe.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
                // 相棒の返事が出ている間は、状態の代わりに返事を出す
                Text(ackText ?? RenewalRecipeStatus.text(recipe, actions))
                    .font(.system(size: 11, weight: ackText == nil ? .medium : .regular))
                    .foregroundStyle(ackText == nil ? RenewalTokens.muted : RenewalTokens.ink)
                    .lineLimit(ackText == nil ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    decideButton
                    dislikeButton
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.boardSize, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { actions.onDetail(recipe) }

            VStack(spacing: 2) {
                RenewalRecipeGuideTile(recipe: recipe, typeName: actions.partnerTypeName)
                likeButton
            }
        }
        .padding(10)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(RenewalTokens.border.opacity(0.7), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .opacity(reaction?.isDisliked == true ? 0.45 : 1)
        .modifier(RenewalDislikeDialogs(isPresented: $askingReason) { actions.onDislike?(recipe, $0, $1) })
    }

    private var pickBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkle").font(.system(size: 8, weight: .semibold))
            Text("イチオシ").font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(RenewalTokens.accentPink)
    }

    @ViewBuilder
    private var likeButton: some View {
        if let onLike = actions.onLike {
            let liked: Bool = { if case .liked = reaction { return true } else { return false } }()
            Button {
                guard !liked else { return }
                Haptic.selection()
                onLike(recipe)
            } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(liked ? RenewalTokens.accentPink : RenewalTokens.ink)
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(reaction == .sending)
            .accessibilityLabel(liked ? "いいね済み" : "いいね")
        }
    }

    private var decideButton: some View {
        let decided = actions.isDecided(recipe)
        return Button {
            if !decided { actions.onDecide(recipe) }
        } label: {
            HStack(spacing: 3) {
                if decided { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                Text(decided ? "決定済み" : actions.actionLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(decided ? RenewalTokens.ink : .white)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(decided ? RenewalTokens.surface : RenewalTokens.primaryFill,
                        in: RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2)
                .stroke(decided ? RenewalTokens.controlBorder : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(actions.isSending)
    }

    @ViewBuilder
    private var dislikeButton: some View {
        if actions.onDislike != nil {
            Button {
                Haptic.selection()
                askingReason = true
            } label: {
                Text("違う")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(width: 44, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2)
                        .stroke(RenewalTokens.controlBorder, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(reaction == .sending || reaction?.isDisliked == true)
            .accessibilityLabel("ちょっと違う")
        }
    }
}
