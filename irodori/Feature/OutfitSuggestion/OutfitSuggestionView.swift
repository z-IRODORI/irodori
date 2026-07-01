//
//  OutfitSuggestionView.swift
//  irodori
//
//  相棒が「次に着るコーデ」を予定に合わせて提案する画面。
//  入力(いつ/どう見られたい/誰と/どこ) → ローディング → 結果(相棒コメント +
//  スナップからおすすめ + クローゼットからコーデ) の3ステップを 1 画面で管理する。
//
//  UI は ZOZOTOWN / WEAR を参考にしたミニマル設計:
//   - 白背景・モノトーン・余白主役（カード/影/グラデ/絵文字は使わない）
//   - 選択 = 黒塗り、非選択 = 白 + hairline ボーダーのピル
//   - チップは自然なフロー、自由入力は下線スタイル
//   - CTA は黒・下部固定
//

import SwiftUI
import Kingfisher

// MARK: - 入力選択肢

enum OutfitWhenOption: String, CaseIterable, Identifiable {
    case today, tomorrow, weekend
    var id: String { rawValue }
    var apiValue: String { rawValue }
    var label: String {
        switch self {
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .weekend: return "今週末"
        }
    }
}

enum OutfitLookOption: String, CaseIterable, Identifiable {
    case clean = "清潔感を出したい"
    case stylish = "おしゃれに見せたい"
    case mature = "大人っぽく見せたい"
    case friendly = "親しみやすく"
    case proper = "きちんとして見せたい"
    case effortless = "こなれ感を出したい"
    case cute = "可愛く見せたい"
    var id: String { rawValue }
}

// サジェスト候補（タップで自由入力欄にセットでき、素早く入力できる）
private let withWhoSuggestions = ["友人", "恋人", "家族", "同僚", "上司", "ひとり"]
private let whereSuggestions = ["カフェでお茶", "ランチ・ごはん", "デート", "友達と遊ぶ", "ショッピング", "仕事・打ち合わせ", "飲み会", "結婚式・式典"]

// MARK: - 自由入力の履歴

// 「誰と」「どこで何をする」の自由入力を UserDefaults に保存し、次回以降サジェストとして再利用する。
// デフォルトのサジェストと同じ値は保存しない。直近入力が先頭・重複なし・最大 maxCount 件。
enum OutfitInputHistory {
    static let maxCount = 6

    static func load(_ key: UserDefaultsKey) -> [String] {
        UserDefaults.standard.stringArray(forKey: key.rawValue) ?? []
    }

    static func save(_ value: String, key: UserDefaultsKey, excluding defaults: [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !defaults.contains(trimmed) else { return }
        var history = load(key).filter { $0 != trimmed }
        history.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(history.prefix(maxCount)), forKey: key.rawValue)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class OutfitSuggestionViewModel {
    enum Step { case input, loading, result }
    var step: Step = .input

    var when: OutfitWhenOption = .today
    var selectedLooks: Set<OutfitLookOption> = []
    var withWho: String = ""
    var whereText: String = ""

    var withWhoHistory: [String] = OutfitInputHistory.load(.outfitWithWhoHistory)
    var whereHistory: [String] = OutfitInputHistory.load(.outfitWhereHistory)

    var result: OutfitSuggestionResponse?
    var errorMessage: String?

    var canSubmit: Bool { !selectedLooks.isEmpty }

    private let client: PartnerClientProtocol
    init(client: PartnerClientProtocol = FallbackPartnerClient()) {
        self.client = client
    }

    func toggle(_ look: OutfitLookOption) {
        if selectedLooks.contains(look) {
            selectedLooks.remove(look)
        } else {
            selectedLooks.insert(look)
        }
    }

    func reset() {
        step = .input
        errorMessage = nil
    }

    func submit() async {
        errorMessage = nil
        step = .loading

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        ).apiValue
        let looks = OutfitLookOption.allCases
            .filter { selectedLooks.contains($0) }
            .map { $0.rawValue }
        let who = withWho.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = whereText.trimmingCharacters(in: .whitespacesAndNewlines)

        OutfitInputHistory.save(who, key: .outfitWithWhoHistory, excluding: withWhoSuggestions)
        OutfitInputHistory.save(place, key: .outfitWhereHistory, excluding: whereSuggestions)
        withWhoHistory = OutfitInputHistory.load(.outfitWithWhoHistory)
        whereHistory = OutfitInputHistory.load(.outfitWhereHistory)

        do {
            let r = try await client.proposeOutfitSuggestion(
                userId: uid,
                gender: gender,
                when: when.apiValue,
                looks: looks,
                withWho: who.isEmpty ? nil : who,
                whereText: place.isEmpty ? nil : place,
                prefectureCode: nil
            )
            switch r {
            case .success(let resp):
                result = resp
                step = .result
            case .failure:
                errorMessage = "提案の取得に失敗しました。少し時間をおいて試してください。"
                step = .input
            }
        } catch is CancellationError {
            step = .input
        } catch {
            errorMessage = "提案の取得に失敗しました。少し時間をおいて試してください。"
            step = .input
        }
    }
}

// MARK: - View

struct OutfitSuggestionView: View {
    @Binding var path: [ViewType]
    @State private var viewModel = OutfitSuggestionViewModel()

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .input:
                inputView
            case .loading:
                loadingView
            case .result:
                resultView
            }
        }
        .navigationTitle("コーデを提案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.white, for: .navigationBar)
        .animation(.easeInOut(duration: 0.22), value: viewModel.step)
    }

    // MARK: 入力

    private var inputView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("予定に合わせて、相棒が今日のコーデを選びます。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 4)

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                // いつ
                section("いつ") {
                    HStack(spacing: 8) {
                        ForEach(OutfitWhenOption.allCases) { opt in
                            segment(opt.label, selected: viewModel.when == opt) {
                                viewModel.when = opt
                            }
                        }
                    }
                }

                // どう見られたい
                section("どう見られたい", note: "複数選択できます") {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(OutfitLookOption.allCases) { look in
                            pill(look.rawValue, selected: viewModel.selectedLooks.contains(look)) {
                                viewModel.toggle(look)
                            }
                        }
                    }
                }

                // 誰と
                section("誰と", note: "任意") {
                    VStack(alignment: .leading, spacing: 14) {
                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(suggestions(history: viewModel.withWhoHistory, defaults: withWhoSuggestions), id: \.self) { s in
                                pill(s, selected: viewModel.withWho == s) {
                                    viewModel.withWho = (viewModel.withWho == s) ? "" : s
                                }
                            }
                        }
                        underlineField("入力する（例: 後輩、義両親）", text: $viewModel.withWho)
                    }
                }

                // どこで何をする
                section("どこで何をする", note: "任意") {
                    VStack(alignment: .leading, spacing: 14) {
                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(suggestions(history: viewModel.whereHistory, defaults: whereSuggestions), id: \.self) { s in
                                pill(s, selected: viewModel.whereText == s) {
                                    viewModel.whereText = (viewModel.whereText == s) ? "" : s
                                }
                            }
                        }
                        underlineField("入力する（例: 渋谷でデート）", text: $viewModel.whereText)
                    }
                }

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .background(Color.gray.opacity(0.05))
        .safeAreaInset(edge: .bottom) { ctaBar }
    }

    // 履歴（直近入力）を先頭に、デフォルト候補と重複しないよう結合する
    private func suggestions(history: [String], defaults: [String]) -> [String] {
        history.filter { !defaults.contains($0) } + defaults
    }

    // セクション: 小さめのグレーラベル + 余白で区切る（カードや線で囲わない）
    private func section<Content: View>(
        _ title: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.primary)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    // セグメント（いつ）: 等幅・選択で黒塗り
    private func segment(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // ピル（複数選択 / サジェスト）: 選択で黒塗り、非選択は白 + hairline
    private func pill(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    Capsule().stroke(selected ? Color.clear : Color.black.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // 下線スタイルの自由入力
    private func underlineField(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(spacing: 7) {
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .tint(.black)
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 下部固定 CTA（黒）
    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                Task { await viewModel.submit() }
            } label: {
                Text("提案する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canSubmit ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: ローディング

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.black)
            Text("コーデを選んでいます")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    // MARK: 結果

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 32) {
                    // 相棒コメント（囲わずテキストで）
                    VStack(alignment: .leading, spacing: 8) {
                        resultLabel("相棒からのおすすめ")
                        Text(result.partner_comment)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .foregroundStyle(.primary)
                    }

                    // スナップからおすすめ
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            resultLabel("スナップからおすすめ")
                            Spacer()
                            DailyMiniWeatherBadge(weather: result.weather)
                        }
                        if result.snap.recommendations.isEmpty {
                            emptyText("おすすめできるスナップが見つかりませんでした")
                        } else {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                                spacing: 8
                            ) {
                                ForEach(result.snap.recommendations) { item in
                                    DailyGridImage(imageURL: item.image_url)
                                }
                            }
                        }
                    }

                    // クローゼットからコーデ
                    VStack(alignment: .leading, spacing: 14) {
                        resultLabel("クローゼットからコーデ")
                        if result.closet.isDisplayable {
                            KFImage(URL(string: result.closet.collage_url))
                                .resizable()
                                .placeholder { Color.gray.opacity(0.1) }
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            if !result.closet.items.isEmpty {
                                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                    ForEach(result.closet.items) { it in
                                        Text(it.displayName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .overlay(Capsule().stroke(Color.black.opacity(0.15), lineWidth: 1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        } else {
                            emptyText("クローゼットのアイテムが足りず、コーデを作れませんでした")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    Haptic.impact(.soft)
                    viewModel.reset()
                } label: {
                    Text("条件を変えてもう一度")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .background(.white)
        }
    }

    private func resultLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(.primary)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
