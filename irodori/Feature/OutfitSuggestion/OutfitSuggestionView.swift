//
//  OutfitSuggestionView.swift
//  irodori
//
//  相棒が「次に着るコーデ」を予定に合わせて提案する画面。
//  入力(いつ/どう見られたい/誰と/どこ) → ローディング → 結果(相棒コメント +
//  スナップからおすすめ + クローゼットからコーデ) の3ステップを 1 画面で管理する。
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
    case cool = "かっこよく"
    case attractive = "モテたい"
    case elegant = "上品に"
    case neat = "きれいめ"
    case casual = "カジュアルに"
    case cute = "かわいく"
    case calm = "落ち着いて"
    var id: String { rawValue }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    PartnerIconImage(size: 44)
                    Text("予定を教えてくれたら、\n次に着るコーデを提案するよ！")
                        .font(.system(size: 14, weight: .medium))
                        .lineSpacing(3)
                    Spacer()
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // いつ
                section(title: "いつ", required: true) {
                    HStack(spacing: 8) {
                        ForEach(OutfitWhenOption.allCases) { opt in
                            let selected = viewModel.when == opt
                            Button { viewModel.when = opt } label: {
                                Text(opt.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selected ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? Color.black : Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // どう見られたい (複数選択)
                section(title: "どう見られたい？", required: true, hint: "いくつでも選べるよ") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(OutfitLookOption.allCases) { look in
                            lookChip(look)
                        }
                    }
                }

                // 誰と (任意)
                section(title: "誰と会う？", required: false, hint: "任意") {
                    TextField("例: 友人、恋人、上司 など", text: $viewModel.withWho)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // どこに (任意)
                section(title: "どこに行く？", required: false, hint: "任意") {
                    TextField("例: 渋谷のカフェ、結婚式 など", text: $viewModel.whereText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button { Task { await viewModel.submit() } } label: {
                    Text("相棒に提案してもらう")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(viewModel.canSubmit ? Color.pink : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canSubmit)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func lookChip(_ look: OutfitLookOption) -> some View {
        let selected = viewModel.selectedLooks.contains(look)
        return Button { viewModel.toggle(look) } label: {
            Text(look.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? Color.pink : Color.gray.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? Color.pink : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(
        title: String,
        required: Bool,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                if required {
                    Text("必須")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.pink)
                        .clipShape(Capsule())
                }
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    // MARK: ローディング

    private var loadingView: some View {
        VStack(spacing: 20) {
            PartnerIconImage(size: 72)
            ProgressView()
                .scaleEffect(1.2)
            Text("相棒がコーデを考えているよ…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 結果

    private var resultView: some View {
        ScrollView {
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

                    Button { viewModel.reset() } label: {
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
