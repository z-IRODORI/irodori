//
//  RenewalFirstViewLayouts.swift
//  irodori - Sandbox
//
//  ホームのファーストビューで「3案を一度に見せる」レイアウト候補。
//  現行 (1枚ずつのカルーセル) は1案しか見えず、残り2案の存在に気づきにくい。
//  実データ (api/home/owned-first) のまま切り替えて比較できるようにする。
//
//   案A リスト型      : 横長のコンパクトカードを縦に3つ。スクロールなしで3案すべてを読める
//   案B イチオシ+2    : 1案目を大きく、残り2案を半幅で並べる。迷わせずに選択肢も見せる
//   案C 3列で比べる   : 3案を横に並べて見比べ、タップした案の理由と決定ボタンを下に出す
//   案D のぞき見カルーセル: 現行カルーセルを細くして次の案が半分見える (変更が最小)
//

import SwiftUI

enum RenewalFirstViewLayout: String, CaseIterable, Identifiable {
    case current, list, featured, columns, peek

    var id: String { rawValue }
    static let storageKey = "renewalSandbox.firstViewLayout"

    var shortLabel: String {
        switch self {
        case .current: return "現行"
        case .list: return "A リスト"
        case .featured: return "B イチオシ+2"
        case .columns: return "C 3列比較"
        case .peek: return "D のぞき見"
        }
    }

    var summary: String {
        switch self {
        case .current: return "1枚ずつ横スワイプ。お手本画像が大きいが、ファーストビューは1案のみ"
        case .list: return "横長カードを縦に3つ。スクロールなしで3案の服・理由・ボタンが見える"
        case .featured: return "イチオシを大きく、残り2案を半幅で。主役は明確なまま選択肢も見える"
        case .columns: return "3案を横に並べて見比べ、選んだ案の理由と決定ボタンを下に表示"
        case .peek: return "カードを細くして次の案が半分のぞく。現行からの変更が最小"
        }
    }
}

/// 3案の表示に必要な操作をまとめたもの (どのレイアウトでも共通)
struct RenewalRecipeActions {
    let scope: RenewalScope
    let decidedId: String?
    let isSending: Bool
    let showCharCount: Bool
    let onDetail: (OwnedFirstRecipe) -> Void
    let onDecide: (OwnedFirstRecipe) -> Void
    let onPivot: () -> Void

    func isDecided(_ r: OwnedFirstRecipe) -> Bool { decidedId == r.recipe_id }
}

// MARK: - レイアウト切替バー (Sandbox 用)

struct RenewalLayoutSwitcher: View {
    @Binding var layoutRaw: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("ファーストビュー案")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.muted)
                    ForEach(RenewalFirstViewLayout.allCases) { layout in
                        let on = layout.rawValue == layoutRaw
                        Button {
                            Haptic.selection()
                            layoutRaw = layout.rawValue
                        } label: {
                            Text(layout.shortLabel)
                                .font(.system(size: 12, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? .white : RenewalTokens.ink)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 30)
                                .background(on ? RenewalTokens.primaryFill : RenewalTokens.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(on ? Color.clear : RenewalTokens.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, RenewalTokens.edge)
            }
            Text((RenewalFirstViewLayout(rawValue: layoutRaw) ?? .current).summary)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
                .padding(.horizontal, RenewalTokens.edge)
        }
    }
}

// MARK: - 共通の小部品

private struct DiscoveryTag: View {
    var body: some View {
        Text("発見枠")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(RenewalTokens.discovery)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RenewalTokens.discovery.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
    }
}

private struct PickTag: View {
    var body: some View {
        Text("イチオシ")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RenewalTokens.primaryFill)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
    }
}

/// 小さめの決定ボタン (見た目 36pt、タップ領域 44pt)
private struct CompactDecideButton: View {
    let recipe: OwnedFirstRecipe
    let actions: RenewalRecipeActions
    var fullWidth = false

    var body: some View {
        let decided = actions.isDecided(recipe)
        Button {
            if !decided { actions.onDecide(recipe) }
        } label: {
            HStack(spacing: 4) {
                if decided { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(decided ? "決定済み" : actions.scope.actionLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(decided ? RenewalTokens.ink : .white)
            .padding(.horizontal, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
            .background(decided ? RenewalTokens.surface : RenewalTokens.primaryFill)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2)
                .stroke(decided ? RenewalTokens.controlBorder : Color.clear, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(actions.isSending)
    }
}

/// 手持ち (実線) + 未所持 (点線) の小さなアイテム列
private struct ItemStrip: View {
    let recipe: OwnedFirstRecipe
    var size: CGFloat
    var limit: Int = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(recipe.owned_items.prefix(limit)) { item in
                RenewalRemoteItemTile(label: item.label, imageURL: item.image_url, slot: item.slot, size: size, owned: true, showName: false)
            }
            ForEach(recipe.missing_items.prefix(max(0, limit - recipe.owned_items.count))) { m in
                RenewalRemoteItemTile(label: m.label, imageURL: nil, slot: m.slot, size: size, owned: false, showName: false)
            }
        }
    }
}

private func shortStatus(_ r: OwnedFirstRecipe) -> String {
    if r.missing_items.isEmpty { return "手持ち\(r.owned_items.count)点で完成" }
    if r.owned_items.isEmpty { return "定番で組んだ案" }
    return "手持ち\(r.owned_items.count) ＋\(r.missing_items.count)点"
}

// MARK: - 案A リスト型

struct RenewalListLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                row(recipe, index: index)
            }
            Button(action: actions.onPivot) {
                Text("使う服を変える")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    private func row(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRemoteExampleImage(example: recipe.example, height: 112, showBadge: false)
                    .frame(width: 84)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("案\(index + 1)の着こなしイメージ。タップで詳細")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if index == 0 { PickTag() }
                    if recipe.isDiscovery { DiscoveryTag() }
                    Text(shortStatus(recipe))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineLimit(1)
                }
                ItemStrip(recipe: recipe, size: 30)
                Text(recipe.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
                HStack(spacing: 0) {
                    Button("詳細") { actions.onDetail(recipe) }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(minWidth: 44, minHeight: 44)
                    Spacer(minLength: 0)
                    CompactDecideButton(recipe: recipe, actions: actions)
                }
            }
        }
        .padding(10)
        .renewalCard()
    }
}

// MARK: - 案B イチオシ + 2案

struct RenewalFeaturedLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions

    var body: some View {
        VStack(spacing: 10) {
            if let first = recipes.first {
                featured(first)
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(recipes.dropFirst().prefix(2))) { recipe in
                    mini(recipe)
                }
            }
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    private func featured(_ recipe: OwnedFirstRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { actions.onDetail(recipe) } label: {
                ZStack(alignment: .bottomLeading) {
                    RenewalRemoteExampleImage(example: recipe.example, height: 150)
                    ItemStrip(recipe: recipe, size: 34)
                        .padding(6)
                        .background(.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                PickTag()
                if recipe.isDiscovery { DiscoveryTag() }
                Text(recipe.status_label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
            }
            Text(recipe.reason)
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
            HStack {
                Button("使う服を変える", action: actions.onPivot)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(minHeight: 44)
                Spacer()
                CompactDecideButton(recipe: recipe, actions: actions)
            }
        }
        .padding(12)
        .renewalCard()
    }

    private func mini(_ recipe: OwnedFirstRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRemoteExampleImage(example: recipe.example, height: 92, showBadge: false)
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                if recipe.isDiscovery { DiscoveryTag() }
                Text(shortStatus(recipe))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            ItemStrip(recipe: recipe, size: 28)
            CompactDecideButton(recipe: recipe, actions: actions, fullWidth: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .renewalCard()
    }
}

// MARK: - 案C 3列で比べる

struct RenewalColumnsLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions
    @State private var selectedId: String?

    private var selected: OwnedFirstRecipe? {
        recipes.first { $0.recipe_id == selectedId } ?? recipes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    column(recipe, index: index)
                }
            }
            if let selected {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(selected.status_label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                        Spacer(minLength: 0)
                        Button("詳細") { actions.onDetail(selected) }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RenewalTokens.muted)
                            .frame(minWidth: 44, minHeight: 32)
                    }
                    Text(selected.reason)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if actions.showCharCount { RenewalCharCountBadge(text: selected.reason) }
                    CompactDecideButton(recipe: selected, actions: actions, fullWidth: true)
                    Button("使う服を変える", action: actions.onPivot)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .padding(12)
                .renewalCard()
            }
        }
        .padding(.horizontal, RenewalTokens.edge)
        .onChange(of: recipes.map(\.recipe_id)) { selectedId = nil }
    }

    private func column(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        let isOn = recipe.recipe_id == selected?.recipe_id
        return Button {
            Haptic.selection()
            selectedId = recipe.recipe_id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RenewalRemoteExampleImage(example: recipe.example, height: 132, showBadge: false)
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                    if index == 0 { PickTag() } else if recipe.isDiscovery { DiscoveryTag() }
                }
                .foregroundStyle(RenewalTokens.ink)
                Text(shortStatus(recipe))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ItemStrip(recipe: recipe, size: 24, limit: 3)
                if actions.isDecided(recipe) {
                    Label("決定済み", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius)
                .stroke(isOn ? RenewalTokens.ink : RenewalTokens.border, lineWidth: isOn ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("案\(index + 1): \(recipe.pair_text)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 案D のぞき見カルーセル

struct RenewalPeekLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    card(recipe, index: index)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.6 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, RenewalTokens.edge, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private func card(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRemoteExampleImage(example: recipe.example, height: 210, showBadge: false)
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                if index == 0 { PickTag() }
                if recipe.isDiscovery { DiscoveryTag() }
                Text("\(index + 1)/\(recipes.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(RenewalTokens.muted)
            }
            Text(shortStatus(recipe))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
            ItemStrip(recipe: recipe, size: 32)
            Text(recipe.reason)
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
            Spacer(minLength: 0)
            CompactDecideButton(recipe: recipe, actions: actions, fullWidth: true)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .renewalCard()
    }
}
