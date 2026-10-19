//
//  RenewalHomeView.swift
//  irodori - Sandbox
//
//  新ホーム画面 (app_ecosystem_and_improvement_design.md §3・§5①②)
//   ① 相棒ヘッダー (アイコン + 提案理由の吹き出し。手持ち0〜2着の間だけ1行リンク)
//   ② 今日 / 明日 / 週末 + 日付・気温の1行バー
//   ③ 手持ち起点の3案カルーセル (主役=手持ちの組み合わせ / お手本=着こなしイメージ / 理由 / ボタン1つ)
//  直近コーデ一覧・常設データ獲得カード・右上の📅/？は置かない (右上は♡のみ)。
//

import SwiftUI

struct RenewalHomeView: View {
    let store: RenewalStore
    var onOpenPartner: () -> Void
    var onOpenToneSheet: () -> Void
    var onOpenPhotoPicker: () -> Void
    var onOpenCalendar: () -> Void

    @State private var scope: RenewalScope = .today
    @State private var detailRecipe: RenewalRecipe?
    @State private var showPivot = false
    @State private var showDislike = false
    @State private var showFavorites = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var day: Int { store.targetDay(scope) }
    private var weather: RenewalWeather { RenewalWeather.forDay(day) }
    private var recipes: [RenewalRecipe] { store.recipes(for: scope) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                partnerHeader
                scopeBar
                carousel
                passButton
            }
            .padding(.vertical, 12)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFavorites = true
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("お気に入り")
            }
        }
        .sheet(item: $detailRecipe) { recipe in
            RenewalRecipeDetailView(store: store, recipe: recipe, scope: scope)
        }
        .sheet(isPresented: $showPivot) {
            RenewalPivotSheet(store: store, scope: scope)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDislike) {
            dislikeSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFavorites) {
            RenewalFavoritesSheet(store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if let sendoff = store.sendoff {
                sendoffOverlay(sendoff)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.sendoff)
    }

    // MARK: - ① 相棒ヘッダー

    private var partnerHeader: some View {
        let greeting = store.greeting(for: scope)
        return HStack(alignment: .top, spacing: 12) {
            Button(action: onOpenPartner) {
                VStack(spacing: 4) {
                    RenewalPartnerAvatar(typeName: store.typeName, size: 48)
                    Text("相棒")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                }
                .frame(minWidth: 52, minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                Haptic.impact(.medium)
                onOpenToneSheet()
            })
            .accessibilityLabel("相棒画面を開く")
            .accessibilityHint("長押しで話し方を変更できます")

            VStack(alignment: .leading, spacing: 8) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .redacted(reason: store.isRegenerating ? .placeholder : [])

                if store.showCharCount {
                    HStack(spacing: 6) {
                        RenewalCharCountBadge(text: greeting)
                        Text("着眼点: \(store.angle(for: day).label)")
                            .font(.system(size: 11))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }

                if let nudge = store.nudge {
                    Divider().overlay(RenewalTokens.rule)
                    Button(action: onOpenPhotoPicker) {
                        HStack(spacing: 4) {
                            Text(nudge)
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(RenewalTokens.ink)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .renewalCard()
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    // MARK: - ② 今日 / 明日 / 週末 + 日付・気温 (1行)

    private var scopeBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(RenewalScope.allCases) { s in
                    Button {
                        Haptic.selection()
                        scope = s
                    } label: {
                        Text(s.label)
                            .font(.system(size: 13, weight: scope == s ? .semibold : .regular))
                            .foregroundStyle(scope == s ? .white : RenewalTokens.ink)
                            .frame(minWidth: 44, minHeight: 32)
                            .padding(.horizontal, 4)
                            .background(scope == s ? RenewalTokens.primaryFill : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(scope == s ? .isSelected : [])
                }
            }
            .padding(2)
            .background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2).stroke(RenewalTokens.border, lineWidth: 1))

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text(store.dateLabel(day))
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: weather.symbol)
                    .font(.system(size: 12))
                Text("\(weather.tempMax)℃ / \(weather.tempMin)℃")
                    .font(.system(size: 13).monospacedDigit())
            }
            .foregroundStyle(RenewalTokens.ink)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(store.dateLabel(day))、\(weather.condition)、最高\(weather.tempMax)度、最低\(weather.tempMin)度")
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    // MARK: - ③ 3案カルーセル

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    card(recipe, index: index)
                        .containerRelativeFrame(.horizontal) { width, _ in width - 64 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, RenewalTokens.edge, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private func card(_ recipe: RenewalRecipe, index: Int) -> some View {
        let decided = store.isDecided(recipe, scope: scope)
        let reason = RenewalCopy.cardReason(recipe: recipe, tone: store.tone, weather: weather)
        return VStack(alignment: .leading, spacing: 12) {
            // 主役: 使う手持ちアイテム
            HStack(spacing: 6) {
                Text(recipe.statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                Spacer(minLength: 0)
                if recipe.isDiscovery {
                    Text("発見枠")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.discovery)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RenewalTokens.discovery.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
                }
                Text("\(index + 1)/\(recipes.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(RenewalTokens.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(recipe.ownedItems) { item in
                        Button {
                            showPivot = true
                        } label: {
                            RenewalItemTile(staple: item.staple, size: 60, owned: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("タップで使う服を変えられます")
                    }
                    ForEach(recipe.missingItems) { staple in
                        RenewalItemTile(staple: staple, size: 60, owned: false)
                    }
                }
            }

            // お手本: 近い着こなしイメージ
            Button {
                detailRecipe = recipe
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    RenewalExampleImage(recipe: recipe, height: 170)
                    // 納得: 相棒からの推薦理由
                    Text(reason)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .redacted(reason: store.isRegenerating ? .placeholder : [])
                    if store.showCharCount { RenewalCharCountBadge(text: reason) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("タップで詳細を開きます")

            Spacer(minLength: 0)

            // アクション (1ボタンのみ)
            Button {
                if !decided { store.decide(recipe, scope: scope) }
            } label: {
                HStack(spacing: 6) {
                    if decided { Image(systemName: "checkmark") }
                    Text(decided ? "\(scope.label)はこれに決定済み" : scope.actionLabel)
                }
            }
            .buttonStyle(RenewalPrimaryButtonStyle(filled: !decided))

            if !store.state.closet.isEmpty {
                Button {
                    showPivot = true
                } label: {
                    Text(store.pivotItem(scope: scope).map { "\($0.name)を軸に組み直し中 ・ 変える" } ?? "使う服を変える")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .renewalCard()
    }

    // MARK: - 見送り (負シグナル)

    private var passButton: some View {
        Button {
            showDislike = true
        } label: {
            Text("今日はどれも違うかも")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .underline()
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, RenewalTokens.edge)
    }

    private var dislikeSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RenewalPartnerAvatar(typeName: store.typeName, size: 36)
                Text("どこが違った？ひとつだけ教えてくれたら、次の提案から外すね。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                ForEach(RenewalDislikeReason.allCases) { reason in
                    Button {
                        store.dislikeAll(recipes, reason: reason, scope: scope)
                        showDislike = false
                    } label: {
                        HStack {
                            Text(reason.label).font(.system(size: 14, weight: .medium))
                            Spacer()
                            if store.reasonCount(reason) > 0 {
                                Text("これまで\(store.reasonCount(reason))回")
                                    .font(.system(size: 11))
                                    .foregroundStyle(RenewalTokens.muted)
                            }
                        }
                        .foregroundStyle(RenewalTokens.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .renewalCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(RenewalTokens.edge)
    }

    // MARK: - 「今日着る」の見送り

    private func sendoffOverlay(_ sendoff: RenewalStore.Sendoff) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { store.sendoff = nil }
            VStack(spacing: 16) {
                RenewalPartnerIllustration(typeName: store.typeName, height: 120)
                Text(sendoff.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if store.showCharCount { RenewalCharCountBadge(text: sendoff.message) }
                Text("カレンダーの\(store.dateLabel(store.targetDay(sendoff.scope)))に記録しました")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                HStack(spacing: 10) {
                    Button("カレンダーで見る") {
                        store.sendoff = nil
                        onOpenCalendar()
                    }
                    .buttonStyle(RenewalPrimaryButtonStyle(filled: false))
                    Button("閉じる") { store.sendoff = nil }
                        .buttonStyle(RenewalPrimaryButtonStyle())
                }
            }
            .padding(20)
            .renewalCard()
            .padding(.horizontal, RenewalTokens.edge)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - 推薦の詳細シート (試着・逆登録はここに格納)

struct RenewalRecipeDetailView: View {
    let store: RenewalStore
    let recipe: RenewalRecipe
    let scope: RenewalScope

    @Environment(\.dismiss) private var dismiss
    @State private var showTryOnNote = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RenewalExampleImage(recipe: recipe, height: 300)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("着こなしのお手本")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RenewalTokens.muted)
                        Text(recipe.mainFamily.vibe)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                        Text("本番ではこの枠に、手持ちの組み合わせに色・シルエット・季節感が最も近い Pinterest 画像が入ります。")
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        RenewalSectionTitle(title: "このコーデで使う服", caption: recipe.statusLabel)
                            .padding(14)
                        Divider().overlay(RenewalTokens.rule)
                        ForEach(recipe.ownedItems) { item in
                            row(item.staple, owned: true)
                            Divider().overlay(RenewalTokens.rule)
                        }
                        ForEach(recipe.missingItems) { staple in
                            row(staple, owned: store.owns(staple))
                            Divider().overlay(RenewalTokens.rule)
                        }
                    }
                    .renewalCard()

                    HStack(spacing: 10) {
                        Button {
                            showTryOnNote = true
                        } label: {
                            Label("試着", systemImage: "person.crop.rectangle")
                        }
                        .buttonStyle(RenewalPrimaryButtonStyle(filled: false))

                        Button {
                            store.toggleFavorite(recipe)
                        } label: {
                            Label(store.isFavorite(recipe) ? "お気に入り済み" : "お気に入り",
                                  systemImage: store.isFavorite(recipe) ? "heart.fill" : "heart")
                        }
                        .buttonStyle(RenewalPrimaryButtonStyle(filled: false))
                        .accessibilityAddTraits(store.isFavorite(recipe) ? .isSelected : [])
                    }

                    Button(store.isDecided(recipe, scope: scope) ? "\(scope.label)はこれに決定済み" : scope.actionLabel) {
                        store.decide(recipe, scope: scope)
                        dismiss()
                    }
                    .buttonStyle(RenewalPrimaryButtonStyle())
                    .disabled(store.isDecided(recipe, scope: scope))
                }
                .padding(RenewalTokens.edge)
            }
            .background(RenewalTokens.ground)
            .navigationTitle("コーデの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(RenewalTokens.ink)
                }
            }
            .alert("試着 (Sandbox では省略)", isPresented: $showTryOnNote) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("本番では、この詳細シートから既存のバーチャル試着を開きます。カード表面からは外し、ここに格納する設計です。")
            }
        }
    }

    private func row(_ staple: RenewalStaple, owned: Bool) -> some View {
        HStack(spacing: 12) {
            RenewalItemTile(staple: staple, size: 48, owned: owned, showName: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(staple.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                Text(owned ? "手持ち・\(staple.category.label)" : "まだ持っていない・\(staple.category.label)")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
            if !owned {
                Button {
                    store.addItems([staple], source: .ownedTap)
                } label: {
                    Text("似た服を持ってる")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius).stroke(RenewalTokens.controlBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("\(staple.name)をクローゼットに追加します")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RenewalTokens.ink)
                    .accessibilityLabel("手持ち")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - 「この服を着たい」逆引きシート

struct RenewalPivotSheet: View {
    let store: RenewalStore
    let scope: RenewalScope
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("着たい服を1着選ぶと、その服を主役にした手持ちの組み合わせ＋近い着こなしイメージに組み直します。")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                }
                if store.pivotItem(scope: scope) != nil {
                    Section {
                        Button("相棒のおまかせに戻す") {
                            store.clearPivot(scope: scope)
                            dismiss()
                        }
                        .foregroundStyle(RenewalTokens.ink)
                    }
                }
                ForEach(RenewalCategory.allCases) { category in
                    let items = store.state.closet.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.label) {
                            ForEach(items) { item in
                                Button {
                                    store.pivot(to: item, scope: scope)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        RenewalItemTile(staple: item.staple, size: 40, showName: false)
                                        Text(item.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(RenewalTokens.ink)
                                        Spacer()
                                        if store.pivotItem(scope: scope)?.id == item.id {
                                            Image(systemName: "checkmark").foregroundStyle(RenewalTokens.ink)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(scope.label)はこの服を着たい")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - お気に入り (♡)

struct RenewalFavoritesSheet: View {
    let store: RenewalStore

    var body: some View {
        NavigationStack {
            Group {
                if store.state.favorites.isEmpty {
                    ContentUnavailableView("まだお気に入りはありません",
                                           systemImage: "heart",
                                           description: Text("コーデ詳細の♡で保存できます"))
                } else {
                    List(store.state.favorites, id: \.self) { key in
                        let staples = key.split(separator: "|").compactMap { RenewalStaple.find(String($0).replacingOccurrences(of: "m:", with: "")) }
                        HStack(spacing: 8) {
                            ForEach(staples) { s in
                                RenewalItemTile(staple: s, size: 44, owned: store.owns(s), showName: false)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(staples.map(\.name).joined(separator: "、"))
                    }
                }
            }
            .navigationTitle("お気に入り")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
