//
//  BrandMatchView.swift
//  irodori
//
//  あなたに合うブランド 10 選 (本番)。相棒画面・診断結果の画面から開く。
//  irodori-api の /api/brand-match から、本人のファッションタイプ・クローゼットの服・性別・年齢で選んだ 10 選を読み、
//  一覧 (BrandMatchListView) と詳細シートで見せる。反応 (好き など) は API に送り、次の 10 選に効かせる。
//  価格帯への返事 (高い / ちょうどいい / 安い) は予算感を直すので、送ったらすぐ 10 選を読み直して入れ替える。
//

import SwiftUI

struct BrandMatchView: View {
    @Binding var path: [ViewType]
    var client: BrandMatchClientProtocol = BrandMatchClient()

    private enum Phase {
        case loading
        case ready(BrandMatchStore)
        case needsDiagnosis
        case failed
    }

    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                loadingView
            case .ready(let store):
                BrandMatchListView(store: store)
            case .needsDiagnosis:
                needsDiagnosisView
            case .failed:
                failedView
            }
        }
        .background(BMTokens.ground)
        .navigationTitle("あなたに合うブランド")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .loading = phase { await load() }
        }
    }

    // MARK: 読み込み

    private func load() async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { phase = .failed; return }
        let gender = Gender.fromWithDefault(UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)).apiValue
        let age = Self.userAge()
        switch await client.fetch(userId: uid, gender: gender, age: age) {
        case .success(let res):
            if res.status == "needs_fashion_type" {
                phase = .needsDiagnosis
            } else if let persona = res.persona(userId: uid), !persona.picks.isEmpty {
                let store = BrandMatchStore(persona: persona)
                Self.preload(res, into: store)
                let client = self.client
                store.onReaction = { brandID, reaction in
                    Task { await client.sendFeedback(userId: uid, brandId: brandID, reaction: reaction) }
                }
                // 価格帯への返事: 送る → 直した予算感で 10 選を読み直す → 入れ替える
                store.onPriceFeedback = { [weak store] brandID, verdict in
                    guard let store,
                          let res = await client.sendPriceFeedback(userId: uid, brandId: brandID, verdict: verdict)
                    else { return nil }
                    let before = store.persona
                    var changed = 0
                    if case .success(let fresh) = await client.fetch(userId: uid, gender: gender, age: age),
                       let next = fresh.persona(userId: uid), !next.picks.isEmpty {
                        let shown = Set(before.picks.map(\.brandID))
                        changed = next.picks.filter { !shown.contains($0.brandID) }.count
                        Self.preload(fresh, into: store)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            store.persona = next
                            if changed > 0 { store.note = "教えてくれた予算感で、\(changed) ブランドを選び直したよ" }
                        }
                    }
                    return BMPriceLearning(
                        budgetBefore: 6 - before.economy,
                        budgetAfter: res.budget?.tier ?? 6 - store.persona.economy,
                        changed: changed,
                        gainedPct: res.growth.gained_pct,
                        answers: res.growth.answers,
                        nextTarget: res.growth.next_target)
                }
                phase = .ready(store)
            } else {
                phase = .failed
            }
        case .failure:
            phase = .failed
        }
    }

    /// サーバーに残っている反応と価格帯への返事を、送り返さずに読み込む
    private static func preload(_ res: BrandMatchResponse, into store: BrandMatchStore) {
        for p in res.picks {
            if let r = BMReaction(apiValue: p.reaction) { store.preload(r, for: p.brand.id) }
            if let v = p.price_feedback.flatMap(BMPriceVerdict.init(rawValue:)) { store.preloadPrice(v, for: p.brand.id) }
        }
    }

    /// 登録した誕生日から年齢 (無ければ nil。年齢は選び方の 10% だけに効く)
    static func userAge(now: Date = Date()) -> Int? {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.userInfo.rawValue),
              let user = try? JSONDecoder().decode(User.self, from: data),
              let y = Int(user.birthday.year), let m = Int(user.birthday.month), let d = Int(user.birthday.day),
              let birth = Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))
        else { return nil }
        let age = Calendar(identifier: .gregorian).dateComponents([.year], from: birth, to: now).year
        return age.flatMap { (10...100).contains($0) ? $0 : nil }
    }

    // MARK: 状態ごとの画面

    private var loadingView: some View {
        VStack(spacing: 14) {
            PartnerIconImage(size: 56)
                .overlay(Circle().stroke(BMTokens.border, lineWidth: 1))
            Text("相棒が、あなたに合うブランドを選んでいます…")
                .font(.system(size: 14))
                .foregroundStyle(BMTokens.muted)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var needsDiagnosisView: some View {
        VStack(spacing: 16) {
            PartnerIconImage(size: 56)
                .overlay(Circle().stroke(BMTokens.border, lineWidth: 1))
            Text("あなたの好みがわかると、\n合うブランドを 10 個選べるよ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BMTokens.ink)
                .multilineTextAlignment(.center)
            Button {
                path.append(.fashionType)
            } label: {
                Text("ファッションタイプを診断する")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BMTokens.surface)
                    .frame(maxWidth: 280, minHeight: 48)
                    .background(BMTokens.primary, in: RoundedRectangle(cornerRadius: BMTokens.controlRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedView: some View {
        VStack(spacing: 12) {
            Text("ブランドを読み込めませんでした")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BMTokens.ink)
            Text("通信の状態を確かめて、もう一度お試しください")
                .font(.system(size: 13))
                .foregroundStyle(BMTokens.muted)
            Button {
                phase = .loading
                Task { await load() }
            } label: {
                Text("もう一度読み込む")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BMTokens.ink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 入口のカード (相棒画面・診断結果の画面)

struct BrandMatchEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PartnerIconImage(size: 40)
                    .overlay(Circle().stroke(BMTokens.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text("あなたに合う 10 ブランド")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                    Text("好みとクローゼットの服から、相棒が選んだよ")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BMTokens.faint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .bmCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("ブランドの一覧を開きます"))
    }
}
