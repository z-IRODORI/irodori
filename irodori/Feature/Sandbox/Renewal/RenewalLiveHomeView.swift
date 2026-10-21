//
//  RenewalLiveHomeView.swift
//  irodori - Sandbox
//
//  リニューアル版ホームの「実 API 接続」版。
//  レイアウトは3要素 (相棒ヘッダー / 次に着る日の気温と目安 / 3案)。日付は選ばせず「次に着る日」を自動で決める
//  (15時までは今日、以降は明日)。
//  データは GET api/home/owned-first (手持ち起点の推薦) から取る。
//   - 手持ちアイテムはクローゼットの実画像、コーデモデルは母集団 (Pinterest) の実画像
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
    /// コーデモデルから抽出したアイテム (pool_id → 最新の状況)。ポーリングで更新する
    private(set) var extractions: [String: OwnedFirstExtraction] = [:]
    var sendoff: Sendoff?
    var isSending = false
    /// 案ごとのフィードバック (recipe_id → 状態)。案が入れ替われば使われなくなる
    var reactions: [String: RenewalRecipeReaction] = [:]

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

    /// 案ごとの「いいね」。相棒の返事をその案のカードに出す (案は入れ替えない)
    func like(_ recipe: OwnedFirstRecipe, scope: RenewalScope) async {
        reactions[recipe.recipe_id] = .sending
        Haptic.impact(.soft)
        do {
            if case .success(let res) = try await client.feedback(uid: uid, targetDate: Self.isoDate(scope), reason: "like", recipes: [recipe]) {
                reactions[recipe.recipe_id] = .liked(res.ack_message)
                return
            }
        } catch {}
        reactions[recipe.recipe_id] = .failed
    }

    /// 案ごとの見送り。理由を相棒に伝え、その案だけ見送り済みにする (ほかの案はそのまま)
    func dislike(_ recipe: OwnedFirstRecipe, reason: RenewalDislikeReason, scope: RenewalScope) async {
        reactions[recipe.recipe_id] = .sending
        Haptic.impact(.soft)
        do {
            if case .success(let res) = try await client.feedback(uid: uid, targetDate: Self.isoDate(scope), reason: reason.rawValue, recipes: [recipe]) {
                reactions[recipe.recipe_id] = .disliked(reason, res.ack_message)
                return
            }
        } catch {}
        reactions[recipe.recipe_id] = .failed
    }

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
                for r in res.recipes {
                    if let pid = r.example?.pool_id, let e = r.example?.extraction { extractions[pid] = e }
                }
            case .failure(let error):
                errors[scope] = message(for: error)
            }
        } catch {
            // キャンセルは表示しない
        }
    }

    func extraction(for recipe: OwnedFirstRecipe) -> OwnedFirstExtraction? {
        guard let pid = recipe.example?.pool_id else { return nil }
        return extractions[pid] ?? recipe.example?.extraction
    }

    /// 抽出中のコーデモデルがあれば、完了するまで数秒おきに状況を取りに行く (画面表示中のみ)
    func pollExtractions(_ scope: RenewalScope) async {
        for _ in 0..<40 {
            let pending = (responses[scope]?.recipes ?? []).compactMap { r -> String? in
                guard let pid = r.example?.pool_id else { return nil }
                return (extraction(for: r)?.isInProgress ?? false) ? pid : nil
            }
            if pending.isEmpty { return }
            do {
                try await Task.sleep(for: .seconds(6))
                if case .success(let res) = try await client.examples(uid: uid, poolIds: pending) {
                    for (pid, e) in res.examples { extractions[pid] = e }
                }
            } catch {
                return  // キャンセル (画面離脱・スコープ切替)
            }
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
        if case .notFound = error, source == .render {
            return "コーデの提案を準備中です。少し時間をおいて、下に引っぱって更新してください。"
        }
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
    /// 本番ホームと Sandbox で異なる部分
    struct Host {
        var isSandbox = true
        var showCharCount = false
        var fallbackTypeName = ""
        var showToast: (String) -> Void = { _ in }
    }

    let host: Host
    let model: RenewalLiveHomeModel
    var onOpenPartner: () -> Void
    var onOpenToneSheet: () -> Void
    var onOpenPhotoPicker: () -> Void
    var onOpenCalendar: () -> Void
    /// 3案と相棒の問いかけの下に続ける本番ホームの既存セクション (登録カード・直近コーデなど)
    var footer: AnyView? = nil
    var onRefresh: (() async -> Void)? = nil

    /// 次に着る日 (選択肢は出さない)
    @State private var scope: RenewalScope = .next()
    @State private var detailRecipe: OwnedFirstRecipe?
    @State private var showPivot = false
    // 動き: 入場 (1日1回 / 主役を選んだ直後)・主役の服が飛ぶ・ひとことを話すように
    @AppStorage("renewalHome.introDay") private var introDay = ""
    @AppStorage("renewalHome.spokenDay") private var spokenDay = ""
    @State private var introDelay: Double? = nil
    @State private var introKey = 0
    @State private var pulseItemId: String?
    @State private var pendingPivotIntro: String?
    @State private var flying: (url: String, from: CGRect)?
    @State private var memoryShown = false
    @State private var showDislike = false
    /// 最近主役に選んだ服 (新しい順・カンマ区切り)
    @AppStorage("renewalHome.recentPivots") private var recentPivotsRaw = ""
    @AppStorage(RenewalFirstViewLayout.storageKey) private var layoutRaw = RenewalFirstViewLayout.list.rawValue
    @AppStorage(RenewalVisualMode.storageKey) private var visualRaw = RenewalVisualMode.exampleItems.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var response: OwnedFirstHomeResponse? { model.responses[scope] }
    // 本番はリスト × コーデモデルのアイテムで固定 (切替は Sandbox のみ)
    private var layout: RenewalFirstViewLayout { host.isSandbox ? (RenewalFirstViewLayout(rawValue: layoutRaw) ?? .list) : .list }
    private var visualMode: RenewalVisualMode { host.isSandbox ? (RenewalVisualMode(rawValue: visualRaw) ?? .exampleItems) : .exampleItems }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                partnerHeader
                if let items = response?.closet_items, !items.isEmpty {
                    RenewalPivotStrip(
                        items: items,
                        pinnedId: model.pivotItemId(scope),
                        isLoading: model.loading.contains(scope),
                        recentIds: recentPivots,
                        onSelect: { id, frame in selectPivot(id, frame: frame) }
                    )
                }
                if let error = model.errors[scope] {
                    errorCard(error)
                }
                if let response {
                    recipesView(response)
                    partnerFollowUp
                } else if model.loading.contains(scope) {
                    loadingCard
                }
                if let footer {
                    footer.padding(.top, 10)
                }
            }
            .padding(.vertical, 12)
        }
        .background(RenewalTokens.ground)
        .overlay {
            if model.loading.contains(scope) { loadingSquare }
        }
        .overlay {
            GeometryReader { geo in
                let g = geo.frame(in: .global)
                if let flying {
                    RenewalFlyingItem(imageURL: flying.url, from: flying.from,
                                      to: CGPoint(x: g.midX, y: g.midY), origin: g.origin)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: response?.recipes.map(\.recipe_id) ?? []) { _, ids in
            guard !ids.isEmpty else { return }
            startIntroIfNeeded()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.loading.contains(scope))
        .refreshable {
            await model.load(scope, force: true)
            await onRefresh?()
        }
        .modifier(SandboxNavigation(enabled: host.isSandbox, layoutRaw: $layoutRaw, visualRaw: $visualRaw))
        .task(id: scope) {
            await model.load(scope)
            await model.pollExtractions(scope)
        }
        .sheet(item: $detailRecipe) { recipe in
            RenewalLiveRecipeDetailView(model: model, recipe: recipe, scope: scope, visualMode: visualMode)
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

    // MARK: ① 相棒カード

    /// 案C (1画面凝縮) の相棒カード: 白いカード1枚に アバター + 日付・気温 + ひとこと (2〜3行) + ›。
    /// カード全体で相棒画面を開く (長押しで話し方)。覚えていることはひとことの下に1行だけ
    private var partnerHeader: some View {
        Button(action: onOpenPartner) {
            HStack(alignment: .center, spacing: 12) {
                RenewalPartnerAvatar(typeName: partnerTypeName, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    nextWearMeta
                    if let response {
                        RenewalSpokenText(
                            text: response.greeting,
                            animate: !reduceMotion && spokenDay != Self.todayKey,
                            tapToFinish: false,
                            onFinished: {
                                spokenDay = Self.todayKey
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.25)) { memoryShown = true }
                            }
                        )
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        if let memory = response.memory {
                            memoryNote(memory)
                                .opacity(memoryShown ? 1 : 0)
                                .offset(y: memoryShown ? 0 : 3)
                        }
                        if host.showCharCount {
                            HStack(spacing: 6) {
                                RenewalCharCountBadge(text: response.greeting)
                                Text("\(response.daily_angle_label) ・ \(response.text_source == "gemini" ? "Gemini" : "テンプレート")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(RenewalTokens.muted)
                            }
                        }
                    } else {
                        Text("相棒があなたの手持ち服から3案を組んでいます…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RenewalTokens.muted)
                            .redacted(reason: .placeholder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            Haptic.impact(.medium)
            onOpenToneSheet()
        })
        .accessibilityHint("相棒画面を開く")
        .padding(.horizontal, 16)   // 3案のカードと端をそろえる
        .padding(.top, 4)
    }

    // MARK: 動き

    static var todayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// 案がそろったとき: 主役を選んだ直後か、その日の最初の表示なら入場演出を流す
    private func startIntroIfNeeded() {
        if let pinned = pendingPivotIntro {
            pulseItemId = pinned
            pendingPivotIntro = nil
        } else if introDay != Self.todayKey {
            introDay = Self.todayKey
            pulseItemId = nil
        } else {
            return
        }
        guard !reduceMotion else { return }
        introDelay = 0.05
        introKey += 1
        // 演出が終わったら通常表示に戻す (再描画で再生しないように)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            introDelay = nil
        }
    }

    /// 主役の服を選ぶ: チップの服を画面中央 (相棒) へ飛ばしてから組み直す
    private func selectPivot(_ id: String?, frame: CGRect?) {
        if let id, let frame, !reduceMotion,
           let url = response?.closet_items.first(where: { $0.item_id == id })?.image_url, !url.isEmpty {
            flying = (url, frame)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.55))
                flying = nil
            }
        }
        pendingPivotIntro = id
        Task {
            await model.pivot(id, scope: scope)
            // 組み直した案が出てから、選んだ服を主役の服の先頭へ
            if let id { rememberPivot(id) }
        }
    }

    private var recentPivots: [String] {
        recentPivotsRaw.split(separator: ",").map(String.init)
    }

    private func rememberPivot(_ id: String) {
        let ids = [id] + recentPivots.filter { $0 != id }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            recentPivotsRaw = ids.prefix(12).joined(separator: ",")
        }
    }

    /// ひとことの根拠になった「相棒が覚えていること」(さりげなく1行)
    private func memoryNote(_ m: OwnedFirstMemory) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .semibold))
            Text("覚えてるよ ・ \(m.label)")
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(RenewalTokens.muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("相棒が覚えていること: \(m.label)")
    }

    /// 「明日 10/21(水) ・ 29° / 20°」(季節ラベルはテキストだけで添える)
    private var nextWearMeta: some View {
        HStack(spacing: 5) {
            Text("\(scope == .today ? "今日" : "明日") \(RenewalLiveHomeModel.dateLabel(scope))")
            if let w = response?.weather {
                Text("・")
                Image(systemName: weatherSymbol(w.condition)).font(.system(size: 11))
                Text("\(w.max_temp)° / \(w.min_temp)°").monospacedDigit()
            }
            if let climate = response?.climate {
                Text("・\(climate.label)")
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(RenewalTokens.muted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metaAccessibility)
    }

    private var metaAccessibility: String {
        var s = "\(scope == .today ? "今日" : "明日")着るなら、\(RenewalLiveHomeModel.dateLabel(scope))"
        if let w = response?.weather { s += "、最高\(w.max_temp)度、最低\(w.min_temp)度" }
        if let c = response?.climate { s += "、\(c.label)。\(c.guidance)" }
        return s
    }

    private var partnerTypeName: String {
        if let name = response?.partner_type_name, !name.isEmpty { return name }
        return host.fallbackTypeName
    }

    private func weatherSymbol(_ condition: String) -> String {
        if condition.contains("雨") { return "cloud.rain" }
        if condition.contains("雪") { return "cloud.snow" }
        if condition.contains("くもり") || condition.contains("曇") { return "cloud" }
        return "sun.max"
    }

    // MARK: ③ 3案 (リスト / のぞき見 × 見せ方)

    @ViewBuilder
    private func recipesView(_ response: OwnedFirstHomeResponse) -> some View {
        let actions = RenewalRecipeActions(
            scope: scope,
            decidedId: response.decided_recipe_id,
            isSending: model.isSending,
            showCharCount: host.showCharCount,
            visualMode: visualMode,
            extraction: { model.extraction(for: $0) },
            onDetail: { detailRecipe = $0 },
            onDecide: { recipe in Task { await model.decide(recipe, scope: scope) } },
            onPivot: { showPivot = true },
            partnerTypeName: partnerTypeName,
            reaction: { model.reactions[$0.recipe_id] },
            onLike: { recipe in Task { await model.like(recipe, scope: scope) } },
            onDislike: { recipe, reason in Task { await model.dislike(recipe, reason: reason, scope: scope) } }
        )
        Group {
            switch layout {
            case .list:
                RenewalListLayout(recipes: response.recipes, actions: actions, introDelay: introDelay)
                    .environment(\.renewalPulseItemId, pulseItemId)
                    .id(introKey)
            case .peek: RenewalPeekLayout(recipes: response.recipes, actions: actions)
            }
        }
        .opacity(model.loading.contains(scope) ? 0.5 : 1)
        .task(id: response.recipes.map(\.recipe_id).joined()) {
            // ピボット・見送りで案が入れ替わったら、新しいコーデモデルの抽出状況も追う
            await model.pollExtractions(scope)
        }
    }

    private var followUpMessage: String {
        if let id = model.pivotItemId(scope),
           let item = response?.closet_items.first(where: { $0.item_id == id }) {
            return "\(item.label)を主役に組み直したよ。ピンとこなかったら教えてね"
        }
        return "ピンとこなかったら教えてね"
    }

    private var pivotLabel: String {
        if let id = model.pivotItemId(scope),
           let item = response?.closet_items.first(where: { $0.item_id == id }) {
            return "\(item.label)を軸に組み直し中 ・ 変える"
        }
        return "使う服を変える"
    }

    // MARK: 状態表示

    /// 初回の読み込み中は案の場所だけ空けておく (ローディングは画面中央の正方形)
    private var loadingCard: some View {
        Color.clear.frame(height: 320)
    }

    /// 画面中央に出す正方形のローディング (初回の読み込みと、主役の服で組み直す間)
    private var loadingSquare: some View {
        RenewalPartnerLoadingView(typeName: partnerTypeName, pinnedLabel: pinnedItemLabel, compact: true)
            .padding(.horizontal, 12)
            .frame(width: 168, height: 168)
            .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var pinnedItemLabel: String? {
        guard let id = model.pivotItemId(scope) else { return nil }
        return response?.closet_items.first(where: { $0.item_id == id })?.label
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

    /// 3案の後の相棒のひとこと。上の相棒カードと同じ白いカードにして、返事 (どれも違うかも) を右に置く
    private var partnerFollowUp: some View {
        HStack(alignment: .center, spacing: 12) {
            RenewalPartnerAvatar(typeName: partnerTypeName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(followUpMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("理由を選ぶと次から外すよ")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Haptic.impact(.soft)
                showDislike = true
            } label: {
                Text("どれも違うかも")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .overlay(Capsule().stroke(RenewalTokens.controlBorder, lineWidth: 1))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)   // 3案のカードと端をそろえる
        .padding(.top, 2)
    }

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
                                host.showToast(ack)
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

/// Sandbox だけナビバーにタイトルと見せ方の切替を出す (本番ホームは独自ヘッダーを持つ)
private struct SandboxNavigation: ViewModifier {
    let enabled: Bool
    @Binding var layoutRaw: String
    @Binding var visualRaw: String

    func body(content: Content) -> some View {
        if enabled {
            content
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { RenewalViewModeMenu(layoutRaw: $layoutRaw, visualRaw: $visualRaw) }
                }
        } else {
            content
        }
    }
}

/// 左上にしっぽが付いた吹き出し (しっぽは相棒のアバターの方を向く)
struct RenewalSpeechBubble: Shape {
    var radius: CGFloat = 16
    var tailWidth: CGFloat = 10
    var tailTop: CGFloat = 10
    var tailHeight: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX + tailWidth, y: rect.minY, width: rect.width - tailWidth, height: rect.height)
        var p = Path(roundedRect: body, cornerRadius: radius)
        var tail = Path()
        tail.move(to: CGPoint(x: body.minX + 1, y: body.minY + tailTop))
        tail.addLine(to: CGPoint(x: rect.minX, y: body.minY + tailTop))
        tail.addLine(to: CGPoint(x: body.minX + 1, y: body.minY + tailTop + tailHeight))
        tail.closeSubpath()
        p.addPath(tail)
        return p.normalized()
    }
}

// MARK: - 詳細シート

struct RenewalLiveRecipeDetailView: View {
    let model: RenewalLiveHomeModel
    let recipe: OwnedFirstRecipe
    let scope: RenewalScope
    var visualMode: RenewalVisualMode = .photo
    @Environment(\.dismiss) private var dismiss

    /// アイテムを並べる見せ方では Pinterest の写真を出さず、並べたアイテムを大きく見せる
    private var isItemMode: Bool { visualMode != .photo }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isItemMode {
                        let extraction = model.extraction(for: recipe)
                        let modelPieces = visualMode == .exampleItems
                            ? RenewalFlatLayBuilder.exampleItems(recipe, extraction: extraction) : []
                        let pieces = modelPieces.isEmpty
                            ? RenewalFlatLayBuilder.ownedPlusExample(recipe, extraction: extraction) : modelPieces
                        RenewalFlatLayBoard(pieces: pieces, showsExampleTag: visualMode == .ownedPlusExample, height: 380)
                    } else {
                        RenewalRemoteExampleImage(example: recipe.example, height: 380)
                    }
                    if !isItemMode, let vibe = recipe.example?.vibe, !vibe.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("コーデモデル")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RenewalTokens.muted)
                            Text(vibe)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RenewalTokens.ink)
                        }
                    }
                    if isItemMode {
                        Text(recipe.reason)
                            .font(.system(size: 14))
                            .foregroundStyle(RenewalTokens.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        coordeModelSection
                    }
                    ForEach(recipe.climate_warnings ?? [], id: \.self) { w in
                        Label(w, systemImage: "thermometer.medium")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.70, green: 0.33, blue: 0.04))
                    }
                    if let e = model.extraction(for: recipe), !e.items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            RenewalSectionTitle(title: "コーデモデルのアイテム",
                                                caption: e.isInProgress ? "商品画像を用意中…" : "コーデモデルのアイテム (アイテムカタログ)")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 10) {
                                    ForEach(e.items) { it in
                                        VStack(spacing: 4) {
                                            RenewalRemoteItemTile(label: it.label, imageURL: it.displayURL, slot: it.slot, size: 76,
                                                                  owned: it.owned_item_id != nil, showName: false)
                                            Text(it.label)
                                                .font(.system(size: 10))
                                                .foregroundStyle(RenewalTokens.ink)
                                                .lineLimit(2)
                                                .frame(width: 84)
                                            if it.owned_item_id != nil {
                                                Text("手持ちにあり")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 4)
                                                    .background(RenewalTokens.owned)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                        }
                                    }
                                }
                            }
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

    /// 参考にした着こなし写真。アイテムを並べる見せ方でも「元になったコーデ」として添える
    @ViewBuilder
    private var coordeModelSection: some View {
        if let example = recipe.example, example.image_url != nil {
            VStack(alignment: .leading, spacing: 8) {
                RenewalSectionTitle(title: "コーデモデル", caption: "この着こなしを参考に、手持ちで組み直した案です")
                HStack(alignment: .top, spacing: 12) {
                    RenewalRemoteExampleImage(example: example, height: 200, showBadge: false)
                        .frame(width: 150)
                    VStack(alignment: .leading, spacing: 6) {
                        if let vibe = example.vibe, !vibe.isEmpty {
                            Text(vibe)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RenewalTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let e = model.extraction(for: recipe), !e.items.isEmpty {
                            let owned = e.items.filter { $0.owned_item_id != nil }.count
                            Text("このモデルのアイテムのうち \(owned)/\(e.items.count) 点が手持ちにあります")
                                .font(.system(size: 12))
                                .foregroundStyle(RenewalTokens.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
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
                    .foregroundStyle(RenewalTokens.owned)
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
                    .strokeBorder(owned ? RenewalTokens.border : RenewalTokens.controlBorder,
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
