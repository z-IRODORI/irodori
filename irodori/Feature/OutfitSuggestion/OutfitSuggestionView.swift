//
//  OutfitSuggestionView.swift
//  irodori
//
//  相棒が「次に着るコーデ」を予定に合わせて提案する画面。
//  入力(いつ/どう見られたい/誰と/どこ) → ローディング → 結果(相棒コメント +
//  スナップからおすすめ + クローゼットからコーデ) の3ステップを 1 画面で管理する。
//
//  入力UIは IRODORI のデザインシステムに準拠:
//   - 背景 gray.0.08 / セクションは白カード(角丸16, shadow)
//   - アクセントはブランドグラデーション(#FF446B→#FF724C)
//   - 「どう見られたい」は絵文字付き複数選択チップ
//   - 「誰と/どこ」はサジェストチップ + 自由入力で素早く
//   - CTA は下部固定(safeAreaInset)
//

import SwiftUI
import Kingfisher

// MARK: - ブランドカラー

private let brandGradient = LinearGradient(
    colors: [Color(red: 1.0, green: 0.27, blue: 0.42), Color(red: 1.0, green: 0.45, blue: 0.30)],
    startPoint: .leading, endPoint: .trailing
)

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
    case cool = "かっこよく"
    case attractive = "モテたい"
    case elegant = "上品に"
    case neat = "きれいめ"
    case casual = "カジュアルに"
    case cute = "かわいく"
    case calm = "落ち着いて"
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .cool: return "🔥"
        case .attractive: return "💘"
        case .elegant: return "✨"
        case .neat: return "🤍"
        case .casual: return "🧢"
        case .cute: return "🎀"
        case .calm: return "🍵"
        }
    }
}

// サジェスト候補（タップで自由入力欄にセットでき、素早く入力できる）
private let withWhoSuggestions = ["友人", "恋人", "家族", "同僚", "上司", "ひとり"]
private let whereSuggestions = ["カフェ", "デート", "オフィス", "ごはん", "お出かけ", "結婚式"]

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
        // CaseIterable の順で安定させて送る
        let looks = OutfitLookOption.allCases
            .filter { selectedLooks.contains($0) }
            .map { $0.rawValue }
        let who = withWho.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = whereText.trimmingCharacters(in: .whitespacesAndNewlines)

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
                errorMessage = "提案の取得に失敗しました。少し時間をおいて試してね。"
                step = .input
            }
        } catch is CancellationError {
            step = .input
        } catch {
            errorMessage = "提案の取得に失敗しました。少し時間をおいて試してね。"
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
        .navigationTitle("相棒のコーデ提案")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: viewModel.step)
    }

    // MARK: 入力

    private var inputView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                greetingHeader
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }
                whenCard
                looksCard
                withWhoCard
                whereCard
                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.gray.opacity(0.08))
        .safeAreaInset(edge: .bottom) { ctaBar }
    }

    // 相棒の吹き出し風ヘッダー
    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            PartnerIconImage(size: 44)
            Text("予定を教えてくれたら、\nぴったりのコーデを提案するよ！")
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .padding(.top, 4)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red.opacity(0.8))
            Text(msg)
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.red.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // カード共通レイアウト
    private func card<Content: View>(
        title: String,
        required: Bool,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(required ? "必須" : "任意")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(required ? Color.white : Color.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(required ? AnyShapeStyle(Color.pink) : AnyShapeStyle(Color.gray.opacity(0.15)))
                    .clipShape(Capsule())
                if let hint {
                    Text(hint).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var whenCard: some View {
        card(title: "いつ着る？", required: true) {
            HStack(spacing: 8) {
                ForEach(OutfitWhenOption.allCases) { opt in
                    let selected = viewModel.when == opt
                    Button {
                        Haptic.impact(.soft)
                        viewModel.when = opt
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(selected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.gray.opacity(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var looksCard: some View {
        card(title: "どう見られたい？", required: true, hint: "いくつでもOK") {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(OutfitLookOption.allCases) { look in
                    lookChip(look)
                }
            }
        }
    }

    private func lookChip(_ look: OutfitLookOption) -> some View {
        let selected = viewModel.selectedLooks.contains(look)
        return Button {
            Haptic.impact(.soft)
            viewModel.toggle(look)
        } label: {
            HStack(spacing: 6) {
                Text(look.emoji).font(.system(size: 15))
                Text(look.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? .white : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(selected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.gray.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var withWhoCard: some View {
        card(title: "誰と会う？", required: false, hint: "任意") {
            suggestionRow(suggestions: withWhoSuggestions, selection: viewModel.withWho) {
                viewModel.withWho = $0
            }
            TextField("自由入力もできるよ（例: 後輩、義両親）", text: $viewModel.withWho)
                .font(.system(size: 14))
                .padding(12)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var whereCard: some View {
        card(title: "どこに行く？", required: false, hint: "任意") {
            suggestionRow(suggestions: whereSuggestions, selection: viewModel.whereText) {
                viewModel.whereText = $0
            }
            TextField("自由入力もできるよ（例: 渋谷のカフェ）", text: $viewModel.whereText)
                .font(.system(size: 14))
                .padding(12)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // サジェストチップ行（タップで自由入力欄にセット / もう一度タップで解除）
    private func suggestionRow(
        suggestions: [String],
        selection: String,
        onTap: @escaping (String) -> Void
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 76), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(suggestions, id: \.self) { s in
                let selected = (selection == s)
                Button {
                    Haptic.impact(.soft)
                    onTap(selected ? "" : s)
                } label: {
                    Text(s)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? AnyShapeStyle(Color.pink) : AnyShapeStyle(Color.gray.opacity(0.08)))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 下部固定 CTA
    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                Task { await viewModel.submit() }
            } label: {
                Text("相棒に提案してもらう")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canSubmit ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.gray.opacity(0.35)))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: ローディング

    private var loadingView: some View {
        VStack(spacing: 20) {
            PartnerIconImage(size: 72)
            ProgressView()
                .scaleEffect(1.2)
                .tint(.pink)
            Text("相棒がコーデを考えているよ…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.08))
    }

    // MARK: 結果

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 28) {
                    // 相棒コメント
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            PartnerIconImage(size: 36)
                            Text("相棒からのおすすめ")
                                .font(.system(size: 14, weight: .bold))
                        }
                        DailyPartnerCommentBox(text: result.partner_comment)
                    }

                    // スナップからおすすめ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("スナップからおすすめ")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            DailyMiniWeatherBadge(weather: result.weather)
                        }
                        if result.snap.recommendations.isEmpty {
                            emptyBox("おすすめできるスナップが見つかりませんでした")
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("クローゼットからコーデ")
                            .font(.system(size: 16, weight: .bold))
                        if result.closet.isDisplayable {
                            KFImage(URL(string: result.closet.collage_url))
                                .resizable()
                                .placeholder { Color.gray.opacity(0.12) }
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            if !result.closet.items.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(result.closet.items) { it in
                                            Text(it.displayName)
                                                .font(.system(size: 12))
                                                .padding(.horizontal, 10).padding(.vertical, 6)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        } else {
                            emptyBox("クローゼットのアイテムが足りず、コーデを作れませんでした")
                        }
                    }

                    Button {
                        Haptic.impact(.soft)
                        viewModel.reset()
                    } label: {
                        Text("条件を変えてもう一度")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .background(Color.gray.opacity(0.08))
    }

    private func emptyBox(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
