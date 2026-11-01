//
//  RenewalGridLayout.swift
//  irodori
//
//  ホームの案を 2 列 × 2 段で並べる (最初の画面で 4 案をくらべられるように)。
//  カードはコーデの画像を主役にし、文字は見出しとボタンだけにする。
//  説明・色の並び・大きなボードは、カードを押した詳細の画面で見る。
//    画像の上: イチオシ (1 枚目) / いいね (右上) / コーデモデル (左下・押すと拡大) / 手持ちの状態 (右下)
//    画像の下: 見出し (2 行まで) / 決定ボタン / 「違う」(押すと理由を聞く)
//

import SwiftUI
import Kingfisher

struct RenewalGridLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions
    /// 入場演出の開始秒 (nil = 演出なし)
    var introDelay: Double? = nil
    var introToken: Int = 0

    /// コーデの画像の高さ。2 段が最初の画面に収まる高さにする
    static let imageHeight: CGFloat = 152
    /// 見出しを写真に重ねる見せ方では、見出しの分だけ写真を縦に大きくする
    static let coverHeight: CGFloat = 196

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                let start = introDelay.map { $0 + Double(index) * 0.06 }
                RenewalGridCard(recipe: recipe, index: index, actions: actions)
                    .coachFrame(.recipes, active: index == 0)
                    .modifier(RenewalIntroRise(delay: start, token: "\(introToken)-\(recipe.recipe_id)"))
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct RenewalGridCard: View {
    let recipe: OwnedFirstRecipe
    let index: Int
    let actions: RenewalRecipeActions

    @State private var askingReason = false
    /// コーデの画像の見せ方 (くらべて決めるまで DEBUG で切り替える)
    @AppStorage(RenewalGridVisualStyle.storageKey) private var visualRaw = RenewalGridVisualStyle.stack.rawValue
    private var visualStyle: RenewalGridVisualStyle { RenewalGridVisualStyle(rawValue: visualRaw) ?? .stack }
    @State private var askingColor = false

    private var reaction: RenewalRecipeReaction? { actions.reaction(recipe) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { actions.onDetail(recipe) } label: {
                RenewalGridVisual(recipe: recipe, actions: actions, style: visualStyle,
                                  height: visualStyle == .cover ? RenewalGridLayout.coverHeight : RenewalGridLayout.imageHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("案\(index + 1) \(recipe.displayTitle)。タップで詳細")
            .overlay(alignment: .topLeading) { if index == 0 { pickBadge.padding(6) } }
            .overlay(alignment: .topTrailing) { likeButton.padding(4) }
            // 写真を出す見せ方では、写真そのものがコーデモデルなので小さな写真は出さない
            .overlay(alignment: .bottomLeading) { if visualStyle == .stack || visualStyle == .board { modelThumb.padding(6) } }
            // 相棒の返事が出ている間は、手持ちの状態を隠す (重ならないように)
            .overlay(alignment: .bottomTrailing) { if ackText == nil && !recipe.owned_items.isEmpty { statusBadge.padding(6) } }
            .overlay(alignment: .bottom) { ackBubble }

            // 見出しを写真に重ねる見せ方では、ここには出さない
            if visualStyle != .cover || recipe.example?.image_url?.isEmpty != false {
                Text(recipe.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(spacing: 6) {
                decideButton
                dislikeButton
            }
        }
        .padding(8)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(RenewalTokens.border.opacity(0.7), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        // 見送った案は薄くして、相棒の返事だけをはっきり見せる (すぐ代わりの案に入れ替わる)
        .opacity(reaction?.isDisliked == true ? 0.45 : 1)
        .confirmationDialog("どこが違った？", isPresented: $askingReason, titleVisibility: .visible) {
            ForEach(RenewalDislikeReason.allCases) { reason in
                Button(reason.label) {
                    if reason == .color {
                        // 色はどこの色かを続けて聞く (ダイアログを閉じてから開き直す)
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.35))
                            askingColor = true
                        }
                    } else {
                        actions.onDislike?(recipe, reason, nil)
                    }
                }
            }
            Button("やめる", role: .cancel) {}
        }
        .confirmationDialog("どこの色が違った？", isPresented: $askingColor, titleVisibility: .visible) {
            ForEach(RenewalColorTarget.allCases) { target in
                Button("\(target.label)（\(target.hint)）") { actions.onDislike?(recipe, .color, target) }
            }
            Button("やめる", role: .cancel) {}
        }
    }

    // MARK: 画像の上

    private var pickBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkle").font(.system(size: 9, weight: .semibold))
            Text("イチオシ").font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(RenewalTokens.accentPink)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(RenewalTokens.accentPink.opacity(0.35), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(liked ? RenewalTokens.accentPink : RenewalTokens.ink)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.92), in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(reaction == .sending)
            .accessibilityLabel(liked ? "いいね済み" : "いいね")
        }
    }

    /// コーデモデル (近い着こなしの写真)。押すと大きく見られる
    @ViewBuilder
    private var modelThumb: some View {
        if let s = recipe.example?.image_url, !s.isEmpty, let url = URL(string: s) {
            KFImage(url)
                .placeholder { RenewalTokens.raised }
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .photoZoomOnTap(url: s)
                .accessibilityLabel("コーデモデルの写真を大きく見る")
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(RenewalTokens.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.white.opacity(0.92), in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    /// 「手持ちで完成」「あと1点」(手持ちにない服の数)
    private var statusText: String {
        let missing: Int
        if actions.visualMode == .exampleItems {
            let pieces = RenewalFlatLayBuilder.exampleItems(recipe, extraction: actions.extraction(recipe))
            missing = pieces.isEmpty ? recipe.missing_items.count : pieces.filter { !$0.ownedMatch }.count
        } else {
            missing = recipe.missing_items.count
        }
        if recipe.owned_items.isEmpty { return "定番で組んだ案" }
        return missing == 0 ? "手持ちで完成" : "あと\(missing)点"
    }

    /// 相棒の返事 (いいね・違う・組み直した)
    private var ackText: String? {
        switch reaction {
        case .liked(let ack): return ack
        case .disliked(_, let ack): return ack
        case .replaced(let ack): return "\(ack) 代わりに組み直したよ"
        case .failed: return "うまく届かなかったみたい"
        default: return nil
        }
    }

    @ViewBuilder
    private var ackBubble: some View {
        if let text = ackText {
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
                .padding(6)
                .transition(.opacity)
                .accessibilityLabel("相棒: \(text)")
        }
    }

    // MARK: 画像の下

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
            .contentShape(Rectangle().inset(by: -5))
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
                    .frame(width: 40, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2)
                        .stroke(RenewalTokens.controlBorder, lineWidth: 1))
                    .contentShape(Rectangle().inset(by: -5))
            }
            .buttonStyle(.plain)
            .disabled(reaction == .sending || reaction?.isDisliked == true)
            .accessibilityLabel("ちょっと違う")
        }
    }
}
