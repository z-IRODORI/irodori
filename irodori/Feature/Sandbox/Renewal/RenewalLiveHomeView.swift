//
//  RenewalLiveHomeView.swift
//  irodori - Sandbox
//
//  リニューアル版ホームの「実 API 接続」版。
//  レイアウトはモック版 (RenewalHomeView) と同じ3要素 (相棒ヘッダー / 今日・明日・週末 + 気温 / 3案) で、
//  データは GET api/home/owned-first (手持ち起点の推薦) から取る。
//   - 手持ちアイテムはクローゼットの実画像、お手本は母集団 (Pinterest) の実画像
//   - 相棒のひとこと・理由は Gemini 生成 (失敗時はサーバ側テンプレート)
//   - 「今日着る」は api/home/owned-first/wear でカレンダー (calendar_outfits) に保存
//   - 見送りは api/home/owned-first/feedback、「使う服を変える」は pivot_item_id で再取得
//

import SwiftUI
import Kingfisher

// MARK: - 接続先

enum RenewalHomeDataSource: String, CaseIterable, Identifiable {
    case mock, local, render

    var id: String { rawValue }

    static let storageKey = "renewalSandbox.homeDataSource"

    var label: String {
        switch self {
        case .mock: return "モック (端末内)"
        case .local: return "実API (ローカル :8080)"
        case .render: return "実API (Render 本番)"
        }
    }

    var baseURL: String? {
        switch self {
        case .mock: return nil
        case .local: return "http://localhost:8080"
        case .render: return OwnedFirstHomeClient.productionBaseURL
        }
    }
}

// MARK: - 状態

@MainActor
@Observable
final class RenewalLiveHomeModel {
    struct Sendoff: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let dateLabel: String
    }

    private(set) var responses: [RenewalScope: OwnedFirstHomeResponse] = [:]
    private(set) var loading: Set<RenewalScope> = []
    private(set) var errors: [RenewalScope: String] = [:]
    private(set) var pivots: [RenewalScope: String] = [:]
    var sendoff: Sendoff?
    var isSending = false

    let source: RenewalHomeDataSource
    private let client: OwnedFirstHomeClientProtocol

    init(source: RenewalHomeDataSource) {
        self.source = source
        self.client = OwnedFirstHomeClient(baseURL: source.baseURL ?? OwnedFirstHomeClient.productionBaseURL)
    }

    var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }

    private var gender: String {
        Gender.fromWithDefault(UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)).apiValue
    }

    // 実日付 (JST)。週末 = 次の土曜 (今日が土日ならその日)
    static func date(for scope: RenewalScope, now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let today = cal.startOfDay(for: now)
        switch scope {
        case .today: return today
        case .tomorrow: return cal.date(byAdding: .day, value: 1, to: today)!
        case .weekend:
            for offset in 0..<7 {
                let d = cal.date(byAdding: .day, value: offset, to: today)!
                let w = cal.component(.weekday, from: d)
                if w == 7 || w == 1 { return d }
            }
            return today
        }
    }

    static func isoDate(_ scope: RenewalScope) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date(for: scope))
    }

    static func dateLabel(_ scope: RenewalScope) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "M/d(E)"
        return f.string(from: date(for: scope))
    }

    func pivotItemId(_ scope: RenewalScope) -> String? { pivots[scope] }

    func load(_ scope: RenewalScope, force: Bool = false) async {
        guard force || responses[scope] == nil, !loading.contains(scope) else { return }
        guard !uid.isEmpty else {
            errors[scope] = "ログインしていないため、実データを取得できません (userId が空)"
            return
        }
        loading.insert(scope)
        errors[scope] = nil
        defer { loading.remove(scope) }
        do {
            let result = try await client.get(uid: uid, gender: gender, targetDate: Self.isoDate(scope), pivotItemId: pivots[scope])
            switch result {
            case .success(let res):
                responses[scope] = res
            case .failure(let error):
                errors[scope] = message(for: error)
            }
        } catch {
            // キャンセルは表示しない
        }
    }

    func pivot(_ itemId: String?, scope: RenewalScope) async {
        pivots[scope] = itemId
        Haptic.impact(.soft)
        await load(scope, force: true)
    }

    func decide(_ recipe: OwnedFirstRecipe, scope: RenewalScope) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        let maxTemp = responses[scope]?.weather.max_temp
        do {
            switch try await client.wear(uid: uid, recipe: recipe, targetDate: Self.isoDate(scope), maxTemp: maxTemp) {
            case .success(let res):
                Haptic.notify(.success)
                sendoff = Sendoff(message: res.sendoff_message, dateLabel: Self.dateLabel(scope))
                await load(scope, force: true)
            case .failure(let error):
                errors[scope] = "保存に失敗しました: \(message(for: error))"
            }
        } catch {}
    }

    /// 戻り値: 相棒からの返事 (トースト表示用)
    func dislike(reason: RenewalDislikeReason, scope: RenewalScope) async -> String? {
        guard let recipes = responses[scope]?.recipes else { return nil }
        do {
            switch try await client.feedback(uid: uid, targetDate: Self.isoDate(scope), reason: reason.rawValue, recipes: recipes) {
            case .success(let res):
                Haptic.impact(.soft)
                await load(scope, force: true)
                return res.ack_message
            case .failure(let error):
                errors[scope] = "送信に失敗しました: \(message(for: error))"
            }
        } catch {}
        return nil
    }

    private func message(for error: HTTPError) -> String {
        if case .notFound = error {
            return "このサーバにはまだ api/home/owned-first がありません。Sandbox 操作で「実API (ローカル :8080)」に切り替えるか、API をデプロイしてください。"
        }
        if case .responseError = error, source == .local {
            return "ローカルサーバ (localhost:8080) に接続できません。irodori-api で ./run.sh を起動してください。"
        }
        return error.errorDescription ?? "通信エラー"
    }
}

// MARK: - 画面

struct RenewalLiveHomeView: View {
    let store: RenewalStore
    let model: RenewalLiveHomeModel
    var onOpenPartner: () -> Void
    var onOpenToneSheet: () -> Void
    var onOpenPhotoPicker: () -> Void
    var onOpenCalendar: () -> Void

    @State private var scope: RenewalScope = .today
    @State private var detailRecipe: OwnedFirstRecipe?
    @State private var showPivot = false
    @State private var showDislike = false
    @AppStorage(RenewalFirstViewLayout.storageKey) private var layoutRaw = RenewalFirstViewLayout.list.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var response: OwnedFirstHomeResponse? { model.responses[scope] }
    private var layout: RenewalFirstViewLayout { RenewalFirstViewLayout(rawValue: layoutRaw) ?? .current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                partnerHeader
                scopeBar
                if let error = model.errors[scope] {
                    errorCard(error)
                }
                RenewalLayoutSwitcher(layoutRaw: $layoutRaw)
                if let response {
                    recipesView(response)
                    passButton
                } else if model.loading.contains(scope) {
                    loadingCard
                }
            }
            .padding(.vertical, 12)
        }
        .background(RenewalTokens.ground)
        .refreshable { await model.load(scope, force: true) }
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scope) { await model.load(scope) }
        .sheet(item: $detailRecipe) { recipe in
            RenewalLiveRecipeDetailView(model: model, recipe: recipe, scope: scope)
        }
        .sheet(isPresented: $showPivot) {
            pivotSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDislike) {
            dislikeSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if let sendoff = model.sendoff {
                sendoffOverlay(sendoff).transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.sendoff)
    }

    // MARK: ① 相棒ヘッダー

    private var partnerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpenPartner) {
                VStack(spacing: 4) {
                    RenewalPartnerAvatar(typeName: partnerTypeName, size: 48)
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

            VStack(alignment: .leading, spacing: 8) {
                if let response {
                    Text(response.greeting)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if store.showCharCount {
                        HStack(spacing: 6) {
                            RenewalCharCountBadge(text: response.greeting)
                            Text("\(response.daily_angle_label) ・ \(response.text_source == "gemini" ? "Gemini" : "テンプレート")")
                                .font(.system(size: 11))
                                .foregroundStyle(RenewalTokens.muted)
                        }
                    }
                    if let nudge = response.data_nudge {
                        Divider().overlay(RenewalTokens.rule)
                        Button(action: onOpenPhotoPicker) {
                            HStack(spacing: 4) {
                                Text(nudge).font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(RenewalTokens.ink)
                            .frame(minHeight: 32)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("相棒があなたの手持ち服から3案を組んでいます…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .renewalCard()
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    private var partnerTypeName: String {
        if let name = response?.partner_type_name, !name.isEmpty { return name }
        return store.typeName
    }

    // MARK: ② 今日 / 明日 / 週末 + 気温

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
                Text(RenewalLiveHomeModel.dateLabel(scope))
                    .font(.system(size: 13, weight: .semibold))
                if let w = response?.weather {
                    Image(systemName: weatherSymbol(w.condition)).font(.system(size: 12))
                    Text("\(w.max_temp)℃ / \(w.min_temp)℃").font(.system(size: 13).monospacedDigit())
                }
            }
            .foregroundStyle(RenewalTokens.ink)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, RenewalTokens.edge)
    }

    private func weatherSymbol(_ condition: String) -> String {
        if condition.contains("雨") { return "cloud.rain" }
        if condition.contains("雪") { return "cloud.snow" }
        if condition.contains("くもり") || condition.contains("曇") { return "cloud" }
        return "sun.max"
    }

    // MARK: ③ 3案 (レイアウト候補の切り替え)

    @ViewBuilder
    private func recipesView(_ response: OwnedFirstHomeResponse) -> some View {
        let actions = RenewalRecipeActions(
            scope: scope,
            decidedId: response.decided_recipe_id,
            isSending: model.isSending,
            showCharCount: store.showCharCount,
            onDetail: { detailRecipe = $0 },
            onDecide: { recipe in Task { await model.decide(recipe, scope: scope) } },
            onPivot: { showPivot = true }
        )
        Group {
            switch layout {
            case .current: carousel(response)
            case .list: RenewalListLayout(recipes: response.recipes, actions: actions)
            case .featured: RenewalFeaturedLayout(recipes: response.recipes, actions: actions)
            case .columns: RenewalColumnsLayout(recipes: response.recipes, actions: actions)
            case .peek: RenewalPeekLayout(recipes: response.recipes, actions: actions)
            }
        }
        .opacity(model.loading.contains(scope) ? 0.5 : 1)
        .overlay { if model.loading.contains(scope) && layout != .current { ProgressView() } }
    }

    private func carousel(_ response: OwnedFirstHomeResponse) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(response.recipes.enumerated()), id: \.element.id) { index, recipe in
                    card(recipe, index: index, total: response.recipes.count, decidedId: response.decided_recipe_id)
                        .containerRelativeFrame(.horizontal) { width, _ in width - 64 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, RenewalTokens.edge, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .opacity(model.loading.contains(scope) ? 0.5 : 1)
        .overlay {
            if model.loading.contains(scope) { ProgressView() }
        }
    }

    private func card(_ recipe: OwnedFirstRecipe, index: Int, total: Int, decidedId: String?) -> some View {
        let decided = decidedId == recipe.recipe_id
        let tileSize: CGFloat = recipe.owned_items.count + recipe.missing_items.count > 3 ? 50 : 60
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(recipe.status_label)
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
                Text("\(index + 1)/\(total)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(RenewalTokens.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(recipe.owned_items) { item in
                        Button { showPivot = true } label: {
                            RenewalRemoteItemTile(label: item.label, imageURL: item.image_url, slot: item.slot, size: tileSize, owned: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("タップで使う服を変えられます")
                    }
                    ForEach(recipe.missing_items) { m in
                        RenewalRemoteItemTile(label: m.label, imageURL: nil, slot: m.slot, size: tileSize, owned: false)
                    }
                }
            }

            Button {
                detailRecipe = recipe
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    RenewalRemoteExampleImage(example: recipe.example, height: 200)
                    Text(recipe.reason)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if store.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("タップで詳細を開きます")

            Spacer(minLength: 0)

            Button {
                guard !decided else { return }
                Task { await model.decide(recipe, scope: scope) }
            } label: {
                HStack(spacing: 6) {
                    if model.isSending { ProgressView().tint(.white) }
                    if decided { Image(systemName: "checkmark") }
                    Text(decided ? "\(scope.label)はこれに決定済み" : scope.actionLabel)
                }
            }
            .buttonStyle(RenewalPrimaryButtonStyle(filled: !decided))
            .disabled(model.isSending)

            Button {
                showPivot = true
            } label: {
                Text(pivotLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .renewalCard()
    }

    private var pivotLabel: String {
        if let id = model.pivotItemId(scope),
           let item = response?.closet_items.first(where: { $0.item_id == id }) {
            return "\(item.label)を軸に組み直し中 ・ 変える"
        }
        return "使う服を変える"
    }

    // MARK: 状態表示

    private var loadingCard: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("クローゼットの服から組み合わせを作っています")
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .renewalCard()
        .padding(.horizontal, RenewalTokens.edge)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("取得できませんでした", systemImage: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("再読み込み") { Task { await model.load(scope, force: true) } }
                .buttonStyle(RenewalPrimaryButtonStyle(filled: false))
        }
        .padding(14)
        .renewalCard()
        .padding(.horizontal, RenewalTokens.edge)
    }

    // MARK: 見送り

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
                RenewalPartnerAvatar(typeName: partnerTypeName, size: 36)
                Text("どこが違った？ひとつだけ教えてくれたら、次の提案から外すね。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                ForEach(RenewalDislikeReason.allCases) { reason in
                    Button {
                        showDislike = false
                        Task {
                            if let ack = await model.dislike(reason: reason, scope: scope) {
                                store.showToast(ack)
                            }
                        }
                    } label: {
                        HStack {
                            Text(reason.label).font(.system(size: 14, weight: .medium))
                            Spacer()
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

    // MARK: 使う服を変える (実クローゼット)

    private var pivotSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("着たい服を1着選ぶと、その服を主役にした手持ちの組み合わせ＋近い着こなしイメージに組み直します。")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                }
                if model.pivotItemId(scope) != nil {
                    Section {
                        Button("相棒のおまかせに戻す") {
                            showPivot = false
                            Task { await model.pivot(nil, scope: scope) }
                        }
                        .foregroundStyle(RenewalTokens.ink)
                    }
                }
                ForEach(["tops", "bottoms", "outer", "shoes"], id: \.self) { slot in
                    let items = (response?.closet_items ?? []).filter { $0.slot == slot }
                    if !items.isEmpty {
                        Section(slotLabel(slot)) {
                            ForEach(items) { item in
                                Button {
                                    showPivot = false
                                    Task { await model.pivot(item.item_id, scope: scope) }
                                } label: {
                                    HStack(spacing: 12) {
                                        RenewalRemoteItemTile(label: item.label, imageURL: item.image_url, slot: item.slot, size: 40, owned: true, showName: false)
                                        Text(item.label)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(RenewalTokens.ink)
                                        Spacer()
                                        if model.pivotItemId(scope) == item.item_id {
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

    private func slotLabel(_ slot: String) -> String {
        switch slot {
        case "tops": return "トップス"
        case "bottoms": return "ボトムス"
        case "outer": return "羽織り"
        default: return "靴"
        }
    }

    // MARK: 見送りのひとこと

    private func sendoffOverlay(_ sendoff: RenewalLiveHomeModel.Sendoff) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { model.sendoff = nil }
            VStack(spacing: 16) {
                RenewalPartnerIllustration(typeName: partnerTypeName, height: 120)
                Text(sendoff.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("カレンダーの\(sendoff.dateLabel)に記録しました")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                HStack(spacing: 10) {
                    Button("カレンダーで見る") {
                        model.sendoff = nil
                        onOpenCalendar()
                    }
                    .buttonStyle(RenewalPrimaryButtonStyle(filled: false))
                    Button("閉じる") { model.sendoff = nil }
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

// MARK: - 詳細シート

struct RenewalLiveRecipeDetailView: View {
    let model: RenewalLiveHomeModel
    let recipe: OwnedFirstRecipe
    let scope: RenewalScope
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RenewalRemoteExampleImage(example: recipe.example, height: 380)
                    if let vibe = recipe.example?.vibe, !vibe.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("着こなしのお手本")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RenewalTokens.muted)
                            Text(vibe)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RenewalTokens.ink)
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        RenewalSectionTitle(title: "このコーデで使う服", caption: recipe.status_label)
                            .padding(14)
                        Divider().overlay(RenewalTokens.rule)
                        ForEach(recipe.owned_items) { item in
                            row(label: item.label, imageURL: item.image_url, slot: item.slot, owned: true)
                            Divider().overlay(RenewalTokens.rule)
                        }
                        ForEach(recipe.missing_items) { m in
                            row(label: m.label, imageURL: nil, slot: m.slot, owned: false)
                            Divider().overlay(RenewalTokens.rule)
                        }
                    }
                    .renewalCard()

                    Button(scope.actionLabel) {
                        Task { await model.decide(recipe, scope: scope) }
                        dismiss()
                    }
                    .buttonStyle(RenewalPrimaryButtonStyle())
                    .disabled(model.responses[scope]?.decided_recipe_id == recipe.recipe_id)
                }
                .padding(RenewalTokens.edge)
            }
            .background(RenewalTokens.ground)
            .navigationTitle("コーデの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundStyle(RenewalTokens.ink)
                }
            }
        }
    }

    private func row(label: String, imageURL: String?, slot: String, owned: Bool) -> some View {
        HStack(spacing: 12) {
            RenewalRemoteItemTile(label: label, imageURL: imageURL, slot: slot, size: 48, owned: owned, showName: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
                Text(owned ? "手持ち" : "まだ持っていない")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
            if owned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RenewalTokens.ink)
                    .accessibilityLabel("手持ち")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - 実画像の部品

/// クローゼットの実画像タイル。画像が無いアイテムはスロットのアイコンで代替する
struct RenewalRemoteItemTile: View {
    let label: String
    let imageURL: String?
    let slot: String
    var size: CGFloat = 60
    var owned: Bool = true
    var showName: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RenewalTokens.raised
                if let imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                    KFImage(url)
                        .placeholder { ProgressView() }
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.36))
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(owned ? RenewalTokens.border : RenewalTokens.controlBorder,
                            style: StrokeStyle(lineWidth: 1, dash: owned ? [] : [3, 2.5]))
            )
            if showName {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(owned ? RenewalTokens.ink : RenewalTokens.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: size + 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(owned ? "手持ち: \(label)" : "未所持: \(label)")
    }

    private var symbol: String {
        switch slot {
        case "tops": return "tshirt"
        case "shoes": return "shoe"
        case "outer": return "hanger"
        default: return "rectangle.portrait"
        }
    }
}

/// 母集団 (Pinterest) の実画像による「着こなしイメージ」
struct RenewalRemoteExampleImage: View {
    let example: OwnedFirstExample?
    var height: CGFloat = 200
    var showBadge: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            RenewalTokens.raised
            if let s = example?.image_url, let url = URL(string: s) {
                KFImage(url)
                    .placeholder { ProgressView() }
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: height)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showBadge {
                Text("着こなしイメージ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
                    .padding(8)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("着こなしイメージ: \(example?.vibe ?? "")")
    }
}
