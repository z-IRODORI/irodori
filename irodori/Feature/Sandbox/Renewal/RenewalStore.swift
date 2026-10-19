//
//  RenewalStore.swift
//  irodori - Sandbox
//
//  リニューアル後アプリ体験の「端末内エンジン」。
//  本番ではサーバ (行動ストック) + Gemini 3.8 Flash が担う処理を、Sandbox 内で決定的に再現する。
//
//   - 手持ち起点の推薦: 手持ちの組み合わせ (レシピ) を先に組み、近い着こなしイメージを添える
//   - 3層行動ストック: 短期 (直近3日: 被り防止・新着) / 中期 (着用回数・採用率) / 長期 (理解カルテ)
//   - 日替わり着眼点 A〜E を前日と被らないようローテーション
//   - 口調の即時切り替え (セリフはすべて computed なので、変えた瞬間に全画面が新しい口調になる)
//
//  状態は UserDefaults (Sandbox 専用キー) に保存し、本番の相棒設定・クローゼットには一切触れない。
//

import SwiftUI

@MainActor
@Observable
final class RenewalStore {

    // MARK: - 永続化する状態

    struct State: Codable {
        var baseDate: TimeInterval = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var answers: RenewalAnswers?
        var today: Int = 0
        var closet: [RenewalOwnedItem] = []
        var wears: [RenewalWearRecord] = []
        var logs: [RenewalActionLog] = []
        var dislikes: [RenewalDislike] = []
        var favorites: [String] = []
        var tasteBoost: [String: Int] = [:]
        /// 「この服を着たい」で指名された軸アイテム (key = 日)
        var pivots: [String: String] = [:]
        /// その日に使った着眼点 (マンネリ防止: last_daily_angle)
        var angleHistory: [String: RenewalDailyAngle] = [:]
    }

    private static let storageKey = "renewalSandbox.state.v1"

    var state: State {
        didSet { save() }
    }

    // MARK: - 一時的な UI 状態

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let isProgress: Bool
    }

    struct Sendoff: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let scope: RenewalScope
    }

    var toast: Toast?
    var sendoff: Sendoff?
    var isAnalyzing = false
    /// 文字数バッジの表示 (黄金律 45〜65字の確認用)
    var showCharCount = false
    /// 口調変更直後にセリフを「再生成中」に見せる
    var isRegenerating = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - 基本情報

    var answers: RenewalAnswers { state.answers ?? RenewalAnswers() }
    var tone: RenewalTone { answers.tone }
    var hasOnboarded: Bool { state.answers != nil }
    var typeName: String { answers.typeName }

    func date(of day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: Date(timeIntervalSince1970: state.baseDate)) ?? Date()
    }

    func day(of date: Date) -> Int {
        let base = Date(timeIntervalSince1970: state.baseDate)
        return Calendar.current.dateComponents([.day], from: base, to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    func targetDay(_ scope: RenewalScope) -> Int {
        switch scope {
        case .today: return state.today
        case .tomorrow: return state.today + 1
        case .weekend:
            // 次の土曜 (今日が土日ならその日)
            for offset in 0..<7 {
                let d = state.today + offset
                let weekday = Calendar.current.component(.weekday, from: date(of: d))
                if weekday == 7 || weekday == 1 { return d }
            }
            return state.today
        }
    }

    func isWeekend(_ day: Int) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date(of: day))
        return weekday == 7 || weekday == 1
    }

    func dateLabel(_ day: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f.string(from: date(of: day))
    }

    // MARK: - 中期ストック (着用回数・一軍スコア)

    func wearCount(_ itemID: String) -> Int {
        state.wears.filter { $0.day <= state.today && $0.itemIDs.contains(itemID) }.count
    }

    func lastWornDay(_ itemID: String, before day: Int) -> Int? {
        state.wears.filter { $0.day < day && $0.itemIDs.contains(itemID) }.map(\.day).max()
    }

    func wear(on day: Int) -> RenewalWearRecord? {
        state.wears.first { $0.day == day }
    }

    /// 短期ストック: 直近2日に着た服 (翌朝の被り防止)
    private func recentlyWornIDs(before day: Int) -> Set<String> {
        Set(state.wears.filter { $0.day < day && $0.day >= day - 2 }.flatMap(\.itemIDs))
    }

    /// 眠っている服 (登録から14日以上・14日以上着ていない)
    private func sleepingItems(at day: Int) -> [RenewalOwnedItem] {
        state.closet.filter { item in
            guard item.addedDay <= day - 14 else { return false }
            if let last = lastWornDay(item.id, before: day) { return last <= day - 14 }
            return true
        }
    }

    private func recentDislikes(at day: Int) -> [RenewalDislike] {
        state.dislikes.filter { $0.day < day + 1 && $0.day >= day - 3 }
    }

    // MARK: - 日替わり着眼点

    func angle(for day: Int) -> RenewalDailyAngle {
        guard !state.closet.isEmpty else { return .birth }
        let w = RenewalWeather.forDay(day)
        var candidates: [RenewalDailyAngle] = []
        if state.closet.contains(where: { $0.addedDay >= day - 2 && $0.addedDay <= day }) { candidates.append(.newItem) }
        if Swift.abs(w.diffFromYesterday) >= 4 || w.isRain { candidates.append(.weather) }
        if isWeekend(day) { candidates.append(.weekend) }
        if wear(on: day - 1) != nil { candidates.append(.rotation) }
        if !sleepingItems(at: day).isEmpty { candidates.append(.rescue) }

        // A (新着) は最優先。それ以外は前日と同じ着眼点を避ける
        if candidates.first == .newItem { return .newItem }
        let previous = state.angleHistory[String(day - 1)]
        if let pick = candidates.first(where: { $0 != previous }) { return pick }
        return candidates.first ?? .newItem
    }

    // MARK: - 軸アイテム (hero) の決定

    func hero(for day: Int) -> RenewalOwnedItem? {
        if let pivotID = state.pivots[String(day)], let item = state.closet.first(where: { $0.id == pivotID }) {
            return item
        }
        guard !state.closet.isEmpty else { return nil }
        let recent = recentlyWornIDs(before: day)
        switch angle(for: day) {
        case .birth:
            return nil
        case .newItem:
            // 新着のうち、まだ着ていない服 → 直近2日に着ていない服 の順で主役にする (被り防止)
            let fresh = state.closet.filter { $0.addedDay >= day - 2 }.sorted { $0.addedDay > $1.addedDay }
            let main = fresh.filter { $0.category == .top || $0.category == .bottom }
            return main.first { lastWornDay($0.id, before: day) == nil }
                ?? main.first { !recent.contains($0.id) }
                ?? fresh.first { !recent.contains($0.id) }
                ?? main.first ?? fresh.first
        case .rotation:
            let yesterday = Set(wear(on: day - 1)?.itemIDs ?? [])
            return bestOwned(.bottom, at: day, avoid: yesterday) ?? bestOwned(.top, at: day, avoid: yesterday)
        case .rescue:
            return sleepingItems(at: day).first
        case .weather:
            let w = RenewalWeather.forDay(day)
            if w.needsOuter, let outer = bestOwned(.outer, at: day, avoid: recent) { return outer }
            return bestOwned(.bottom, at: day, avoid: recent) ?? bestOwned(.top, at: day, avoid: recent)
        case .weekend:
            let playful = state.closet.filter { [.accent, .denim, .earth].contains($0.family) && !recent.contains($0.id) }
            return playful.first ?? bestOwned(.top, at: day, avoid: recent)
        }
    }

    private func score(_ item: RenewalOwnedItem, at day: Int, avoidFamilies: Set<RenewalColorFamily>) -> Int {
        var s = wearCount(item.id) * 2
        if answers.impression.preferredFamilies.contains(item.family) { s += 3 }
        s += state.tasteBoost[item.family.rawValue] ?? 0
        if item.addedDay >= day - 2 { s += 2 }
        if avoidFamilies.contains(item.family) { s -= 6 }
        return s
    }

    private func bestOwned(
        _ category: RenewalCategory,
        at day: Int,
        avoid: Set<String> = [],
        exclude: Set<String> = [],
        avoidFamilies: Set<RenewalColorFamily> = []
    ) -> RenewalOwnedItem? {
        let pool = state.closet.filter { $0.category == category && !exclude.contains($0.id) }
        let fresh = pool.filter { !avoid.contains($0.id) }
        let candidates = fresh.isEmpty ? pool : fresh
        return candidates.max { score($0, at: day, avoidFamilies: avoidFamilies) < score($1, at: day, avoidFamilies: avoidFamilies) }
    }

    private func missingStaple(
        _ category: RenewalCategory,
        families: [RenewalColorFamily],
        exclude: Set<String>,
        avoidFamilies: Set<RenewalColorFamily>
    ) -> RenewalStaple? {
        let owned = Set(state.closet.map(\.id))
        let pool = RenewalStaple.catalog.filter {
            $0.category == category && !owned.contains($0.id) && !exclude.contains($0.id) && !avoidFamilies.contains($0.family)
        }
        for f in families {
            if let hit = pool.first(where: { $0.family == f }) { return hit }
        }
        return pool.first
    }

    // MARK: - 推薦レシピ (3案)

    func recipes(for scope: RenewalScope) -> [RenewalRecipe] {
        let day = targetDay(scope)
        let weather = RenewalWeather.forDay(day)
        let dislikes = recentDislikes(at: day)
        let needOuter = weather.needsOuter || dislikes.contains { $0.reason == .cold }
        let avoidFamilies = Set(dislikes.filter { $0.reason == .color }.flatMap(\.families))
        let bannedKeys = Set(dislikes.filter { $0.reason == .style || $0.reason == .mood }.map(\.recipeKey))
        let recent = recentlyWornIDs(before: day)
        let prefs = answers.impression.preferredFamilies + RenewalColorFamily.allCases

        var slots: [RenewalCategory] = [.top, .bottom]
        if needOuter { slots.append(.outer) }

        func build(hero: RenewalOwnedItem?, exclude: Set<String>, familyShift: Int) -> RenewalRecipe {
            var owned: [RenewalOwnedItem] = []
            var missing: [RenewalStaple] = []
            let shifted = Array(prefs.dropFirst(familyShift)) + Array(prefs.prefix(familyShift))
            for slot in slots {
                if let hero, hero.category == slot { owned.append(hero); continue }
                if let item = bestOwned(slot, at: day, avoid: recent, exclude: exclude, avoidFamilies: avoidFamilies) {
                    owned.append(item)
                } else if let staple = missingStaple(slot, families: shifted, exclude: exclude, avoidFamilies: avoidFamilies) {
                    missing.append(staple)
                }
            }
            if let hero, hero.category == .outer || hero.category == .shoes, !owned.contains(hero) {
                owned.append(hero)
            }
            if !owned.contains(where: { $0.category == .shoes }),
               let shoes = bestOwned(.shoes, at: day, avoid: recent, exclude: exclude, avoidFamilies: avoidFamilies) {
                owned.append(shoes)
            }
            // hero を先頭に
            if let hero, let idx = owned.firstIndex(of: hero) {
                owned.remove(at: idx)
                owned.insert(hero, at: 0)
            }
            let kind: RenewalRecipe.Kind = owned.isEmpty ? .zero : (missing.isEmpty ? .owned : .partial)
            let main = owned.first?.family ?? missing.first?.family ?? .mono
            return RenewalRecipe(ownedItems: owned, missingItems: missing, kind: kind, heroID: hero?.id, mainFamily: main)
        }

        func discovery(base: RenewalOwnedItem?, exclude: Set<String>) -> RenewalRecipe {
            // いつもと違う系統の1点 (差し色優先) を、手持ちの1点と合わせる
            let usualFamilies = Set(state.closet.map(\.family))
            let fresh = RenewalColorFamily.allCases.filter { !usualFamilies.contains($0) }
            let order: [RenewalColorFamily] = [.accent] + fresh + [.earth, .denim]
            let slot: RenewalCategory = needOuter ? .outer : (base?.category == .top ? .bottom : .top)
            let pick = missingStaple(slot, families: order, exclude: exclude, avoidFamilies: avoidFamilies)
                ?? missingStaple(.outer, families: order, exclude: exclude, avoidFamilies: avoidFamilies)
            var owned: [RenewalOwnedItem] = []
            if let base { owned.append(base) }
            let missing = pick.map { [$0] } ?? []
            return RenewalRecipe(
                ownedItems: owned,
                missingItems: missing,
                kind: owned.isEmpty ? .zero : .discovery,
                heroID: base?.id,
                mainFamily: pick?.family ?? .accent
            )
        }

        let hero = hero(for: day)
        var results: [RenewalRecipe] = []
        var used: Set<String> = []

        func appendUnique(_ r: RenewalRecipe) {
            guard !bannedKeys.contains(r.key), !results.contains(where: { $0.key == r.key }) else { return }
            results.append(r)
            used.formUnion(r.ownedItems.filter { $0.id != hero?.id }.map(\.id))
        }

        // 1案目: 軸アイテムを主役にした王道案
        appendUnique(build(hero: hero, exclude: [], familyShift: 0))

        // 2案目: 別の組み合わせ (Q3 が T なら発見枠にする)
        if answers.range == .T {
            appendUnique(discovery(base: hero ?? bestOwned(.bottom, at: day), exclude: used))
        } else {
            let altHero = state.closet
                .filter { $0.id != hero?.id && !recent.contains($0.id) && ($0.category == .top || $0.category == .bottom) }
                .max { score($0, at: day, avoidFamilies: avoidFamilies) < score($1, at: day, avoidFamilies: avoidFamilies) }
            appendUnique(build(hero: altHero, exclude: used, familyShift: 1))
        }

        // 3案目: 発見枠 (半歩先)
        let base = bestOwned(.bottom, at: day, avoid: recent, avoidFamilies: avoidFamilies) ?? hero
        appendUnique(discovery(base: base, exclude: used))

        // 足りなければ系統をずらして補充
        var shift = 2
        while results.count < 3 && shift < 6 {
            appendUnique(build(hero: nil, exclude: used, familyShift: shift))
            shift += 1
        }
        return Array(results.prefix(3))
    }

    // MARK: - セリフ

    func greetingContext(for scope: RenewalScope) -> RenewalCopy.GreetingContext {
        let day = targetDay(scope)
        let yesterday = wear(on: day - 1)
        let lastName: String? = yesterday.flatMap { record in
            let items = record.itemIDs.compactMap { RenewalStaple.find($0) }
            return (items.first { $0.category == .bottom } ?? items.first)?.name
        }
        return RenewalCopy.GreetingContext(
            weather: RenewalWeather.forDay(day),
            hero: hero(for: day)?.name,
            last: lastName,
            value: answers.priority.valueWord,
            weekdayFamily: weekdayFamily(before: day),
            scopeLabel: scope.label
        )
    }

    func greeting(for scope: RenewalScope) -> String {
        RenewalCopy.greeting(angle: angle(for: targetDay(scope)), tone: tone, ctx: greetingContext(for: scope))
    }

    /// 手持ち0〜2着の初期のみ、吹き出しに添える誘い文句
    var nudge: String? {
        state.closet.count <= 2 ? RenewalCopy.nudge(tone: tone) : nil
    }

    private func weekdayFamily(before day: Int) -> String {
        let weekdayWears = state.wears.filter { $0.day < day && $0.day >= day - 7 && !isWeekend($0.day) }
        let families = weekdayWears.flatMap { $0.itemIDs.compactMap { RenewalStaple.find($0)?.family } }
        let counts = Dictionary(grouping: families, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key.label ?? "モノトーン"
    }

    // MARK: - 行動: 「今日着る」 (最も強い正シグナル)

    func decide(_ recipe: RenewalRecipe, scope: RenewalScope) {
        let day = targetDay(scope)
        let weather = RenewalWeather.forDay(day)
        state.wears.removeAll { $0.day == day }
        state.wears.append(RenewalWearRecord(
            day: day,
            itemIDs: recipe.allStaples.map(\.id),
            source: .decided,
            isDiscovery: recipe.isDiscovery
        ))
        let learned = recipe.isDiscovery
            ? "『半歩先の組み合わせも試したい』と記憶"
            : "『\(weather.tempMax)℃の日の定番コンビ』として記憶"
        log(.wearDecided, action: "\(recipe.pairText)を採用 (\(dateLabel(day)))", learned: learned)
        state.angleHistory[String(day)] = angle(for: day)
        Haptic.notify(.success)
        sendoff = Sendoff(message: RenewalCopy.sendoff(recipe: recipe, tone: tone, scope: scope), scope: scope)
    }

    func decidedKey(for scope: RenewalScope) -> String? {
        guard let record = wear(on: targetDay(scope)), record.source == .decided else { return nil }
        return record.itemIDs.sorted().joined(separator: "|")
    }

    func isDecided(_ recipe: RenewalRecipe, scope: RenewalScope) -> Bool {
        decidedKey(for: scope) == recipe.allStaples.map(\.id).sorted().joined(separator: "|")
    }

    // MARK: - 行動: 見送り・👎 (負シグナル)

    func dislikeAll(_ recipes: [RenewalRecipe], reason: RenewalDislikeReason, scope: RenewalScope) {
        let day = targetDay(scope)
        for r in recipes {
            state.dislikes.append(RenewalDislike(day: day, reason: reason, families: [r.mainFamily], recipeKey: r.key))
        }
        let learned = reasonCount(reason) >= 3
            ? "同じ理由が3回 → 『避ける要素』として理解カルテに記録"
            : (reason == .cold ? "『肌寒い日は羽織り多め』を記憶" : "『\(reason.label)』の傾向を記憶")
        log(.disliked, action: "3案を見送り (理由: \(reason.label))", learned: learned)
        Haptic.impact(.soft)
        showToast(RenewalCopy.dislikeAck(reason, tone: tone))
    }

    func reasonCount(_ reason: RenewalDislikeReason) -> Int {
        Set(state.dislikes.filter { $0.reason == reason }.map(\.day)).count
    }

    // MARK: - 行動: ♡ / 詳細閲覧 (興味シグナル)

    func isFavorite(_ recipe: RenewalRecipe) -> Bool { state.favorites.contains(recipe.key) }

    func toggleFavorite(_ recipe: RenewalRecipe) {
        if let idx = state.favorites.firstIndex(of: recipe.key) {
            state.favorites.remove(at: idx)
        } else {
            state.favorites.append(recipe.key)
            state.tasteBoost[recipe.mainFamily.rawValue, default: 0] += 1
            log(.liked, action: "\(recipe.pairText)に♡", learned: "『\(recipe.mainFamily.label)』を気になる系統として、週末や発見枠に回す")
        }
        Haptic.selection()
    }

    // MARK: - 行動: 「この服を着たい」逆引き (ピボット)

    func pivot(to item: RenewalOwnedItem, scope: RenewalScope) {
        state.pivots[String(targetDay(scope))] = item.id
        log(.pivot, action: "『\(item.name)』を指名", learned: "\(item.name)を『着たい日の軸アイテム』として記憶")
        Haptic.impact(.soft)
    }

    func clearPivot(scope: RenewalScope) {
        state.pivots.removeValue(forKey: String(targetDay(scope)))
    }

    func pivotItem(scope: RenewalScope) -> RenewalOwnedItem? {
        guard let id = state.pivots[String(targetDay(scope))] else { return nil }
        return state.closet.first { $0.id == id }
    }

    // MARK: - 行動: 登録

    func owns(_ staple: RenewalStaple) -> Bool { state.closet.contains { $0.id == staple.id } }

    /// 追加した件数を返す
    @discardableResult
    func addItems(_ staples: [RenewalStaple], source: RenewalItemSource, silent: Bool = false) -> Int {
        let newOnes = staples.filter { !owns($0) }.uniqued()
        guard !newOnes.isEmpty else { return 0 }
        let wasEmpty = state.closet.isEmpty
        let existingFamilies = Set(state.closet.map(\.family))
        state.closet.append(contentsOf: newOnes.map { RenewalOwnedItem(staple: $0, addedDay: state.today, source: source) })

        let families = familySummary()
        let feedback: RenewalCopy.RegisterKind
        if source == .photo || source == .camera, newOnes.count > 1 {
            feedback = .batch(count: newOnes.count, families: families)
        } else if wasEmpty {
            feedback = .first(name: newOnes[0].name)
        } else if let accent = newOnes.first(where: { $0.family == .accent || !existingFamilies.contains($0.family) }),
                  let base = state.closet.first(where: { $0.family != accent.family && $0.category != accent.category }) {
            feedback = .accent(name: accent.name, base: base.name)
        } else {
            feedback = .theme(families: families)
        }

        let names = newOnes.prefix(2).map(\.name).joined(separator: "・") + (newOnes.count > 2 ? " ほか" : "")
        let actionPrefix: String
        switch source {
        case .photo: actionPrefix = "写真から\(newOnes.count)着を登録"
        case .camera: actionPrefix = "全身スナップから\(newOnes.count)着を登録"
        case .ownedTap: actionPrefix = "『\(names)』を持ってると教えてくれた"
        case .staple, .preset: actionPrefix = "\(names)を登録"
        }
        let learned = wasEmpty
            ? "\(newOnes[0].name)を『最初の軸アイテム』として記憶"
            : "『\(families)』の好みを学習"
        log(.itemAdded, action: actionPrefix, learned: learned)
        if !silent {
            Haptic.notify(.success)
            showToast(RenewalCopy.registerFeedback(feedback, tone: tone))
        }
        return newOnes.count
    }

    /// クローゼットの色比率の上位2系統 (例: 「ネイビーとモノトーン」)
    func familySummary() -> String {
        let counts = Dictionary(grouping: state.closet.map(\.family), by: { $0 }).mapValues(\.count)
        let top = counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.prefix(2)
        return top.map(\.key.label).joined(separator: "と")
    }

    // MARK: - 写真フォルダから AI 発掘 (Sandbox ではサンプルの全身写真を生成)

    struct PhotoCandidate: Identifiable, Hashable {
        let id: Int
        let daysAgo: Int
        let staples: [RenewalStaple]
        let score: Int
    }

    func photoCandidates() -> [PhotoCandidate] {
        let prefs = answers.impression.preferredFamilies
        func pick(_ c: RenewalCategory, _ i: Int) -> RenewalStaple {
            let pool = RenewalStaple.catalog.filter { $0.category == c }
            let preferred = pool.filter { prefs.contains($0.family) }
            let source = preferred.isEmpty ? pool : preferred
            return source[i % source.count]
        }
        let daysAgo = [3, 8, 12, 19, 27, 40, 55, 71]
        return daysAgo.enumerated().map { i, ago in
            var staples = [pick(.top, i), pick(.bottom, i / 2), pick(.shoes, i)]
            if i % 3 == 1 { staples.append(pick(.outer, i)) }
            return PhotoCandidate(id: i, daysAgo: ago, staples: staples, score: 98 - i * 6)
        }
    }

    /// 選んだ写真を「裏で」解析する。画面は止めず、完了したらトーストで報告
    func importPhotos(_ photos: [PhotoCandidate]) {
        guard !photos.isEmpty else { return }
        isAnalyzing = true
        toast = Toast(message: "\(photos.count)枚の写真から服を読み取っています…", isProgress: true)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            for p in photos {
                let day = state.today - p.daysAgo
                if wear(on: day) == nil {
                    state.wears.append(RenewalWearRecord(day: day, itemIDs: p.staples.map(\.id), source: .photo, isDiscovery: false))
                }
            }
            let all = photos.flatMap(\.staples)
            isAnalyzing = false
            if addItems(all, source: .photo) == 0 {
                showToast("写真の服は、もう全部覚えていたよ。カレンダーに過去のコーデを並べておいたね。")
            }
        }
    }

    // MARK: - カメラで全身1枚スナップ (Sandbox ではサンプル撮影)

    func cameraSnapshot() {
        let prefs = answers.impression.preferredFamilies
        let offset = state.today + state.wears.count
        func pick(_ c: RenewalCategory) -> RenewalStaple {
            let pool = RenewalStaple.catalog.filter { $0.category == c && (prefs.contains($0.family) || c == .shoes) }
            return pool[((offset % pool.count) + pool.count) % pool.count]
        }
        let staples = [pick(.top), pick(.bottom), pick(.shoes)]
        isAnalyzing = true
        toast = Toast(message: "全身写真から服を分解しています…", isProgress: true)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            state.wears.removeAll { $0.day == state.today }
            state.wears.append(RenewalWearRecord(day: state.today, itemIDs: staples.map(\.id), source: .camera, isDiscovery: false))
            isAnalyzing = false
            if addItems(staples, source: .camera) == 0 {
                showToast("今日のコーデをカレンダーに記録したよ。服はもう全部覚えていたね。")
            }
        }
    }

    // MARK: - 2択比較 (好みの直感)

    func recordTasteVote(_ families: [RenewalColorFamily]) {
        for f in families { state.tasteBoost[f.rawValue, default: 0] += 1 }
        let top = Dictionary(grouping: families, by: { $0 }).mapValues(\.count).max { $0.value < $1.value }?.key ?? .mono
        log(.tasteVote, action: "2択比較に\(families.count)回答えた", learned: "『\(top.label)』の雰囲気に惹かれる傾向を学習")
        showToast(RenewalCopy.tasteVoteDone(top, tone: tone))
    }

    // MARK: - 口調の変更 (即時反映)

    func changeTone(_ newTone: RenewalTone) {
        guard newTone != tone else { return }
        var a = answers
        a.tone = newTone
        state.answers = a
        log(.toneChanged, action: "話し方を『\(newTone.label)』に変更", learned: "これからは\(newTone.label)の話し方で伝える")
        isRegenerating = true
        Task { @MainActor in
            // 本番では Gemini 3.8 Flash で home_greeting / アドバイスを再生成 (約0.5〜1秒)
            try? await Task.sleep(for: .milliseconds(700))
            isRegenerating = false
            showToast(RenewalCopy.toneChanged(newTone))
        }
    }

    // MARK: - オンボーディング

    func completeOnboarding(_ answers: RenewalAnswers) {
        state.answers = answers
        log(.toneChanged, action: "4問に回答して相棒が誕生", learned: "『\(answers.impression.shortWord)』に見られたい、\(answers.priority.valueWord)を大事にする人")
    }

    func updateAnswers(_ answers: RenewalAnswers) {
        state.answers = answers
        log(.toneChanged, action: "4問の回答を変更", learned: "指針を『\(answers.impression.shortWord)・\(answers.priority.valueWord)』に更新")
    }

    // MARK: - 時間を進める (Sandbox 操作)

    func advanceDays(_ n: Int) {
        for _ in 0..<n {
            if state.angleHistory[String(state.today)] == nil {
                state.angleHistory[String(state.today)] = angle(for: state.today)
            }
            state.today += 1
        }
        Haptic.impact(.soft)
    }

    // MARK: - シナリオ

    func reset() {
        state = State()
        toast = nil
        sendoff = nil
    }

    /// 「手持ち6着・着用履歴あり」の育った状態 (Stage 3) にする
    func applyGrownPreset() {
        if state.answers == nil { state.answers = RenewalAnswers() }
        let ids = ["top_white_shirt", "btm_black_slacks", "top_navy_knit", "btm_denim", "out_navy_cardigan", "sho_white_sneaker", "top_gray_sweat"]
        let staples = ids.compactMap { RenewalStaple.find($0) }
        for (i, s) in staples.enumerated() where !owns(s) {
            state.closet.append(RenewalOwnedItem(staple: s, addedDay: state.today - 20 + i, source: .preset))
        }
        let history: [(Int, [String])] = [
            (-6, ["top_white_shirt", "btm_black_slacks", "sho_white_sneaker"]),
            (-5, ["top_navy_knit", "btm_denim", "sho_white_sneaker"]),
            (-4, ["top_white_shirt", "btm_black_slacks", "sho_white_sneaker"]),
            (-2, ["top_navy_knit", "btm_black_slacks", "sho_white_sneaker"]),
            (-1, ["top_white_shirt", "btm_denim", "sho_white_sneaker"]),
        ]
        for (offset, items) in history where wear(on: state.today + offset) == nil {
            state.wears.append(RenewalWearRecord(day: state.today + offset, itemIDs: items, source: .decided, isDiscovery: false))
        }
        log(.itemAdded, action: "シナリオ: 手持ち\(staples.count)着・着用5回を投入", learned: "『モノトーンとネイビー』の好みを学習")
    }

    // MARK: - ログ・トースト

    private func log(_ type: RenewalActionType, action: String, learned: String) {
        state.logs.append(RenewalActionLog(day: state.today, type: type, action: action, learned: learned))
    }

    func showToast(_ message: String) {
        toast = Toast(message: message, isProgress: false)
    }
}

// MARK: - 理解カルテ (長期ストック)

extension RenewalStore {

    struct CarteRow: Identifiable {
        let id: String
        let label: String
        let value: String
        let learned: Bool
    }

    /// 3行のスタイル定義 (いまの軸 / 好む色・素材 / 相棒からのメモ)
    var styleDefinition: [CarteRow] {
        let a = answers
        let core = coreItems
        let enough = state.closet.count >= 3
        let decidedWears = state.wears.filter { $0.day <= state.today }
        let axis = enough && !core.isEmpty
            ? "\(core[0].name)を軸にした、\(a.impression.shortWord.replacingOccurrences(of: "人", with: ""))スタイル"
            : a.impression.label
        let colors = enough
            ? "\(familySummary())ベース (\(a.priority == .F ? "肌触りのいい素材" : "きれいに見える素材")中心)"
            : a.priority.sub
        let memo: String
        if decidedWears.count >= 3 {
            memo = wearPatternText
        } else if !state.closet.isEmpty {
            memo = "登録してくれた服で、着回しを少しずつ広げていくね"
        } else {
            memo = "まずは手持ちの定番服から教えてね"
        }
        return [
            CarteRow(id: "axis", label: "いまの軸", value: axis, learned: enough),
            CarteRow(id: "color", label: "好む色・素材", value: colors, learned: enough),
            CarteRow(id: "memo", label: "相棒からのメモ", value: memo, learned: decidedWears.count >= 3),
        ]
    }

    /// 4問の基本設定 + 行動から見つけた傾向
    var carteRows: [CarteRow] {
        let a = answers
        var rows: [CarteRow] = [
            CarteRow(id: "q1", label: "なりたい印象", value: a.impression.label, learned: false),
            CarteRow(id: "q2", label: "服選びの基準", value: a.priority.label, learned: false),
            CarteRow(id: "q3", label: "提案のスタンス", value: a.range.stance, learned: false),
            CarteRow(id: "q4", label: "話し方", value: a.tone.label, learned: false),
        ]
        if state.closet.count >= 3 {
            rows.append(CarteRow(id: "core", label: "よく使う軸服", value: coreItems.prefix(2).map(\.name).joined(separator: "、"), learned: true))
            rows.append(CarteRow(id: "palette", label: "好みの配色", value: "\(familySummary())が中心", learned: true))
        }
        if state.wears.filter({ $0.day <= state.today }).count >= 3 {
            rows.append(CarteRow(id: "pattern", label: "着回しの傾向", value: wearPatternText, learned: true))
        }
        let ng = RenewalDislikeReason.allCases.filter { reasonCount($0) >= 3 }
        if !ng.isEmpty {
            rows.append(CarteRow(id: "ng", label: "避ける要素", value: ng.map(\.label).joined(separator: "、"), learned: true))
        }
        if let boosted = state.tasteBoost.max(by: { $0.value < $1.value }), boosted.value >= 2,
           let family = RenewalColorFamily(rawValue: boosted.key) {
            rows.append(CarteRow(id: "curious", label: "気になっている系統", value: family.label, learned: true))
        }
        return rows
    }

    /// 一軍アイテム (着用回数 → 新しさ順)。靴は「軸服」として語らないので除く
    var coreItems: [RenewalOwnedItem] {
        state.closet.filter { $0.category != .shoes }.sorted {
            let l = wearCount($0.id), r = wearCount($1.id)
            return l == r ? $0.addedDay > $1.addedDay : l > r
        }
    }

    private var wearPatternText: String {
        let past = state.wears.filter { $0.day <= state.today }
        let weekday = past.filter { !isWeekend($0.day) }.flatMap { $0.itemIDs.compactMap { RenewalStaple.find($0)?.family } }
        let weekend = past.filter { isWeekend($0.day) }.flatMap { $0.itemIDs.compactMap { RenewalStaple.find($0)?.family } }
        func top(_ fs: [RenewalColorFamily]) -> RenewalColorFamily? {
            Dictionary(grouping: fs, by: { $0 }).mapValues(\.count).max { $0.value < $1.value }?.key
        }
        let wd = top(weekday)?.label ?? "モノトーン"
        if let we = top(weekend), we.label != wd {
            return "平日は\(wd)が多め。週末は\(we.label)で少し崩すのが好きそう"
        }
        return "平日は\(wd)が多め。週末の記録が増えると違いが見えてくるよ"
    }

    /// 相棒からのアドバイス (いまの強み / 次の発見)
    var advice: (strength: String, next: String)? {
        guard state.closet.count >= 2 else { return nil }
        let core = coreItems
        let strength = core.count >= 2
            ? "手持ちの\(core[0].name)と\(core[1].name)の着回しが安定しているね"
            : "\(core[0].name)を軸にした組み合わせが作りやすいね"
        let owned = Set(state.closet.map(\.id))
        let outer = state.closet.first { $0.category == .outer }
        let next: String
        if let outer {
            next = "手持ちの\(outer.name)を羽織ると、肌寒い日まで着回しの幅が広がるよ"
        } else if let suggestion = RenewalStaple.catalog.first(where: { $0.category == .outer && !owned.contains($0.id) && answers.impression.preferredFamilies.contains($0.family) }) {
            next = "\(suggestion.name)のような羽織りが1枚あると、秋口まで幅が広がるよ"
        } else {
            next = "差し色を1点足すと、いつもの組み合わせが新鮮に見えるよ"
        }
        return (strength, next)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
