//
//  PartnerOnboardingFlowView.swift
//  irodori
//
//  初回オンボーディング刷新（カード形式・8問 + 相棒誕生UX）。
//  Step 0: 相棒の紹介と3つのメリット
//  Step 1: 8つの質問（1問1画面・タップで自動進行）
//          相棒のタイプを決める4問 (印象・感覚・提案・話し方) + プロデュースのための4問
//          (服の数・月の金額・1着の最高額・好きなブランドの数。ファッション感度と予算に使う)
//  Step 2: 回答から誕生した相棒の発表・理由（4つの特徴）・最初の挨拶
//

import SwiftUI
import UIKit

// MARK: - 4問MECE定義

struct PartnerOnboardingOption: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
}

struct PartnerOnboardingQuestion: Identifiable {
    let index: Int
    let axis: String
    let axisBadge: String
    let questionText: String
    /// 質問の下の補足 (例: 「スーツ・制服は除く」)
    var hint: String? = nil
    let options: [PartnerOnboardingOption]

    var id: Int { index }

    static let all: [PartnerOnboardingQuestion] = [
        PartnerOnboardingQuestion(
            index: 0,
            axis: "impression",
            axisBadge: "なりたい印象",
            questionText: "周りから、どんな雰囲気の人に\n見られると嬉しい？",
            options: [
                .init(id: "soft", label: "優しくて、話しかけやすい", value: "soft"),
                .init(id: "refined", label: "大人っぽくて、落ち着いている", value: "refined"),
                .init(id: "unique", label: "おしゃれで、自分らしさがある", value: "unique"),
                .init(id: "clean", label: "きちんとしていて、清潔感がある", value: "clean")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 1,
            axis: "priority",
            axisBadge: "大事にしたい感覚",
            questionText: "服を着るとき、\nどっちを大事にしたい？",
            options: [
                .init(id: "F", label: "ラクに動けて、着心地がいいこと", value: "F"),
                .init(id: "A", label: "シルエットが綺麗で、気分が上がること", value: "A")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 2,
            axis: "range",
            axisBadge: "毎日の提案タイプ",
            questionText: "毎日のコーデ、\nどんなふうに提案してほしい？",
            options: [
                .init(id: "C", label: "手持ちの服で、安心できる着回し", value: "C"),
                .init(id: "T", label: "マンネリしない、新しい組み合わせ", value: "T")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 3,
            axis: "closet_size",
            axisBadge: "持っている服",
            questionText: "普段着は何着くらい\n持ってる？",
            hint: "トップス・ボトムス・アウターを合わせて。だいたいでOK",
            options: [
                .init(id: "lt20", label: "〜20 着", value: "lt20"),
                .init(id: "20_50", label: "20〜50 着", value: "20_50"),
                .init(id: "50_100", label: "50〜100 着", value: "50_100"),
                .init(id: "100p", label: "100 着以上", value: "100p")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 4,
            axis: "monthly_spend",
            axisBadge: "予算感",
            questionText: "服に使うのは、\n月にどのくらい？",
            hint: "ならした平均で",
            options: [
                .init(id: "lt3k", label: "ほぼ使わない（〜3 千円）", value: "lt3k"),
                .init(id: "3k_10k", label: "3 千〜1 万円", value: "3k_10k"),
                .init(id: "10k_30k", label: "1〜3 万円", value: "10k_30k"),
                .init(id: "30k_50k", label: "3〜5 万円", value: "30k_50k"),
                .init(id: "50kp", label: "5 万円以上", value: "50kp")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 5,
            axis: "max_price",
            axisBadge: "予算感",
            questionText: "普段着 1 着に払った\n最高額は？",
            hint: "スーツ・制服・式の服は除く",
            options: [
                .init(id: "lt3k", label: "〜3 千円", value: "lt3k"),
                .init(id: "3k_10k", label: "3 千〜1 万円", value: "3k_10k"),
                .init(id: "10k_25k", label: "1〜2.5 万円", value: "10k_25k"),
                .init(id: "25k_60k", label: "2.5〜6 万円", value: "25k_60k"),
                .init(id: "60kp", label: "6 万円以上", value: "60kp")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 6,
            axis: "brand_count",
            axisBadge: "好きなブランド",
            questionText: "好きなブランドは\nいくつある？",
            options: [
                .init(id: "none", label: "特にない", value: "none"),
                .init(id: "1_2", label: "1〜2", value: "1_2"),
                .init(id: "3_5", label: "3〜5", value: "3_5"),
                .init(id: "6p", label: "6 つ以上", value: "6p")
            ]
        ),
        PartnerOnboardingQuestion(
            index: 7,
            axis: "tone",
            axisBadge: "相棒の話し方",
            questionText: "最後に、相棒には\nどんな話し方がいい？",
            options: [
                .init(id: "gentle", label: "やさしく丁寧に", value: "gentle"),
                .init(id: "normal", label: "友達みたいにフランクに", value: "normal"),
                .init(id: "spicy", label: "本音でズバッと辛口に", value: "spicy"),
                .init(id: "cool", label: "要点だけシンプルに", value: "cool")
            ]
        )
    ]
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerOnboardingFlowViewModel {
    enum Step {
        case intro
        case question(Int)
        /// 4問に答えたあとの確認 (選んだだけでは送らない)
        case confirm
        case loading
        case birth(PartnerOnboardingResponse)
        /// ファッション感度が 70 点未満の人だけ: 誕生のあとに 3 枚の案内
        case beginnerGuide
    }

    var step: Step = .intro
    var impression: String = "soft"
    var priority: String = "F"
    var rangeVal: String = "C"
    var tone: String = "gentle"
    // プロデュースのための4問 (どれも1問1画面で選ぶので、送るときには必ず答えが入っている)
    var closetSize: String = "20_50"
    var monthlySpend: String = "3k_10k"
    var maxPrice: String = "3k_10k"
    var brandCount: String = "none"
    var selectedValueInCurrentStep: String? = nil

    /// 保存できなかったとき (確認画面に戻して知らせる)
    var saveErrorMessage: String? = nil

    private let partnerClient: PartnerClientProtocol

    // 失敗したときに仮の相棒で進めない (仮のタイプが端末に残り、サーバと食い違うため)。本物のクライアントだけを使う
    init(partnerClient: PartnerClientProtocol = PartnerClient()) {
        self.partnerClient = partnerClient
    }

    /// 確認画面に並べる「質問 → 選んだ答え」
    var answerSummary: [(index: Int, badge: String, label: String)] {
        PartnerOnboardingQuestion.all.map { q in
            let v = value(for: q.axis)
            return (q.index, q.axisBadge, q.options.first { $0.value == v }?.label ?? "未回答")
        }
    }

    private func value(for axis: String) -> String {
        switch axis {
        case "impression": return impression
        case "priority": return priority
        case "range": return rangeVal
        case "tone": return tone
        case "closet_size": return closetSize
        case "monthly_spend": return monthlySpend
        case "max_price": return maxPrice
        case "brand_count": return brandCount
        default: return ""
        }
    }

    /// サーバに送るプロデュースのための4問
    var profileAnswers: PartnerProfileAnswers {
        PartnerProfileAnswers(closet_size: closetSize, monthly_spend: monthlySpend,
                              max_price: maxPrice, brand_count: brandCount)
    }

    func jump(to index: Int) {
        Haptic.selection()
        withAnimation(.easeInOut(duration: 0.25)) { step = .question(index) }
    }

    func startQuestions() {
        Haptic.impact(.soft)
        withAnimation(.easeInOut(duration: 0.25)) {
            step = .question(0)
        }
    }

    func goBack() {
        Haptic.selection()
        switch step {
        case .intro:
            break
        case .question(let idx):
            withAnimation(.easeInOut(duration: 0.25)) {
                if idx == 0 {
                    step = .intro
                } else {
                    step = .question(idx - 1)
                }
            }
        case .confirm:
            withAnimation(.easeInOut(duration: 0.25)) {
                step = .question(PartnerOnboardingQuestion.all.count - 1)
            }
        case .loading, .birth, .beginnerGuide:
            break
        }
    }

    func selectOption(_ option: PartnerOnboardingOption, for question: PartnerOnboardingQuestion) {
        Haptic.selection()
        selectedValueInCurrentStep = option.value

        switch question.axis {
        case "impression":
            impression = option.value
        case "priority":
            priority = option.value
        case "range":
            rangeVal = option.value
        case "tone":
            tone = option.value
        case "closet_size":
            closetSize = option.value
        case "monthly_spend":
            monthlySpend = option.value
        case "max_price":
            maxPrice = option.value
        case "brand_count":
            brandCount = option.value
        default:
            break
        }

        let nextIdx = question.index + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.selectedValueInCurrentStep = nil
            if nextIdx < PartnerOnboardingQuestion.all.count {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.step = .question(nextIdx)
                }
            } else {
                // 最後の質問でも、選んだ瞬間には送らない (確認してから相棒を育てる)
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.step = .confirm
                }
            }
        }
    }

    /// mode: 会員登録の流れ (.registration) か、登録後に相棒画面から答え直す (.update) か。
    /// サーバでは別々の API (登録: 前のキャラの残りを消して始める / 更新: 消さずに相棒を育てる)
    func submitOnboarding(mode: PartnerAnswerMode) async {
        withAnimation(.easeInOut(duration: 0.2)) {
            step = .loading
        }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "guest-user"

        #if DEBUG
        // 動作確認用: 答えを本番に保存せず、相棒の誕生だけを見る (改善案 > オンボーディング で切替)。
        // 端末にも保存しない (保存すると、サーバの相棒と食い違って古いキャラに戻るため)
        if OnboardingDebug.dryRun {
            try? await Task.sleep(for: .seconds(1.2))
            var mock = PartnerOnboardingResponse.mock(impression: impression, priority: priority, rangeVal: rangeVal, tone: tone)
            // サーバと同じ式で感度だけ出す (初心者向けの案内の出方を確かめられるように)
            let closetPoints = ["lt20": 0, "20_50": 33, "50_100": 67, "100p": 100][closetSize] ?? 0
            let brandPoints = ["none": 0, "1_2": 33, "3_5": 67, "6p": 100][brandCount] ?? 0
            let score = Int((Double(closetPoints + brandPoints) / 2).rounded())
            mock.fashion_sense = FashionSense(answered: true, level: score < 70 ? "beginner" : "enthusiast",
                                              needs_beginner_guide: score < 70, visible: false, score: nil, budget_tier: nil)
            if mode == .registration { PartnerLocalMirror.markOnboardingCompleted() }
            Haptic.notify(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { step = .birth(mock) }
            return
        }
        #endif

        let result: Result<PartnerOnboardingResponse, HTTPError>?
        switch mode {
        case .registration:
            result = try? await partnerClient.saveOnboarding(userId: uid, impression: impression, priority: priority, rangeVal: rangeVal, tone: tone, profile: profileAnswers)
        case .update:
            result = try? await partnerClient.updatePartner(userId: uid, impression: impression, priority: priority, rangeVal: rangeVal, tone: tone, profile: profileAnswers)
        }
        guard case .success(let response)? = result else {
            Haptic.notify(.error)
            saveErrorMessage = "相棒を保存できませんでした。通信を確かめて、もう一度お試しください。"
            withAnimation(.easeInOut(duration: 0.2)) { step = .confirm }
            return
        }

        if mode == .registration {
            // 前に使っていた別アカウントのキャラ・3案・ホームの控えを消してから、新しい相棒を写す
            AccountLocalState.clearServerMirrors()
        }
        PartnerLocalMirror.apply(typeName: response.type_name)
        PartnerLocalMirror.markOnboardingCompleted()
        NotificationCenter.default.post(name: PartnerLocalMirror.didChange, object: nil)
        Haptic.notify(.success)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            step = .birth(response)
        }
    }

    static func loadPersistedResponse() -> PartnerOnboardingResponse? {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.partnerOnboardingResponse.rawValue) else {
            return nil
        }
        return try? JSONDecoder().decode(PartnerOnboardingResponse.self, from: data)
    }
}

/// 8つの質問の答えをどこに保存するか
enum PartnerAnswerMode {
    /// 会員登録の流れで初めて相棒が生まれる
    case registration
    /// 登録後に相棒画面から答え直す (データを消さず、相棒を育てるフィードバックとして扱う)
    case update
}

// MARK: - Main Flow View

struct PartnerOnboardingFlowView: View {
    var showCloseButton: Bool = false
    /// 会員登録の流れか、相棒画面からの更新か (保存先の API が違う)
    var mode: PartnerAnswerMode = .registration
    let onComplete: () -> Void

    @State private var viewModel = PartnerOnboardingFlowViewModel()
    /// 初心者向けの案内の3枚目で「定番を選ぶ」を押した
    @State private var showStandardItems = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.step {
            case .intro:
                if showCloseButton {
                    introStepView
                } else {
                    // 初回起動: IRODORI と相棒を3枚で伝えてから4つの質問へ
                    OnboardingWalkthroughView(onFinish: viewModel.startQuestions)
                }
            case .question(let index):
                questionStepView(question: PartnerOnboardingQuestion.all[index])
            case .confirm:
                confirmStepView
            case .loading:
                loadingStepView
            case .birth(let response):
                birthStepView(response: response)
            case .beginnerGuide:
                BeginnerGuideView(
                    onPickStandardItems: { showStandardItems = true },
                    onFinish: onComplete
                )
                .transition(.opacity)
            }
        }
        // 「定番を選ぶ」: 選び終わったら (閉じても) ホームへ
        .sheet(isPresented: $showStandardItems, onDismiss: onComplete) {
            NavigationStack {
                SelectStandardItemView(path: .constant([]), onComplete: { showStandardItems = false })
                    .navigationTitle("定番アイテムから追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showStandardItems = false }
                                .foregroundStyle(.black)
                        }
                    }
            }
        }
        .background(Color.white.ignoresSafeArea())
        #if DEBUG
        .overlay(alignment: .bottom) {
            if OnboardingDebug.dryRun {
                Text("確認用：答えを保存していません")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.8), in: Capsule())
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
        }
        #endif
        .alert("保存できませんでした", isPresented: Binding(
            get: { viewModel.saveErrorMessage != nil },
            set: { if !$0 { viewModel.saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage ?? "")
        }
    }

    /// すでに相棒がいる (オンボーディング済みで、アプリ内から開いた) ときの相棒アイコン
    private var existingPartnerIcon: String? {
        guard showCloseButton,
              let icon = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
              UIImage(named: icon) != nil else { return nil }
        return icon
    }

    // MARK: - 確認 (4問に答えたあと)

    private var confirmStepView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.goBack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("戻る").font(.system(size: 14))
                    }
                    .foregroundStyle(.black)
                    .frame(minHeight: 44)
                }
                Spacer()
                if showCloseButton { closeButton }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("この内容で相棒を育てます")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                    Text(existingPartnerIcon == nil
                         ? "変えたい答えはタップして選び直せます。"
                         : "今の相棒の話し方や提案の方向が、この答えに合わせて変わります。変えたい答えはタップして選び直せます。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 10) {
                        ForEach(viewModel.answerSummary, id: \.index) { row in
                            Button { viewModel.jump(to: row.index) } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.badge)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        Text(row.label)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.black)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Text("変更")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            Button {
                Task { await viewModel.submitOnboarding(mode: mode) }
            } label: {
                Text("この内容で相棒を育てる")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var closeButton: some View {
        CloseCircleButton(action: onComplete)
    }

    // MARK: - Step 0: 相棒の紹介カード

    private var introStepView: some View {
        VStack(spacing: 0) {
            if showCloseButton {
                HStack {
                    Spacer()
                    CloseCircleButton(action: onComplete)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            } else {
                Spacer().frame(height: 24)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 12)

                    if let icon = existingPartnerIcon {
                        // すでに相棒がいる人には、今の相棒を見せる (答え直す前提の説明にする)
                        VStack(spacing: 10) {
                            Image(icon)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                            Text("今の相棒")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("答え直すと、相棒の話し方や提案の方向が変わります")
                                .font(.system(size: 13))
                                .foregroundStyle(.black)
                        }
                    } else {
                    // まだ特徴のない相棒シルエット
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.08))
                                .frame(width: 96, height: 96)
                            Circle()
                                .strokeBorder(
                                    Color.gray.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                                .frame(width: 96, height: 96)
                            Image(systemName: "sparkles")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(Color.gray.opacity(0.55))
                        }

                        Text("まだ特徴のない相棒")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    }

                    // タイトル・説明
                    VStack(spacing: 10) {
                        Text("あなたのことを理解して\n次のコーデを決めてくれる「相棒」")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("IRODORIの中心にいるのは、あなた専属の相棒です。\n次に着る服を選ぶ迷いをなくしてくれます。")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)

                    // 相棒ができる3つのこと
                    VStack(alignment: .leading, spacing: 16) {
                        Text("相棒があなたにできること")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        benefitRow(
                            icon: "sun.max",
                            title: "天気や気温差に合わせて次に着る日の3案を提案",
                            subtitle: "朝晩の寒暖差や雨の日も、迷わず選べるコーデを用意します"
                        )
                        benefitRow(
                            icon: "tshirt",
                            title: "今持っている服を活かした着回しがわかる",
                            subtitle: "手持ちの服を教えるほど、クローゼットにある服で提案します"
                        )
                        benefitRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "使うほど、あなた好みに成長していく",
                            subtitle: "選んだコーデや好みを覚えて、提案の納得感が高まります"
                        )
                    }
                    .padding(20)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }

            // 下部CTA
            VStack(spacing: 10) {
                Text("まずは8つの質問で、相棒にあなたのことを教えてください")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button(action: {
                    viewModel.startQuestions()
                }) {
                    Text("8つの質問に答える（約1分）")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Step 1: 8つの質問（カード形式・1問1画面）

    private func questionStepView(question: PartnerOnboardingQuestion) -> some View {
        let total = PartnerOnboardingQuestion.all.count
        let progress = CGFloat(question.index + 1) / CGFloat(total)

        return VStack(spacing: 0) {
            // ナビゲーション & プログレス
            VStack(spacing: 12) {
                HStack {
                    Button(action: { viewModel.goBack() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("戻る")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(.black)
                        .frame(minHeight: 44)
                    }

                    Spacer()

                    Text("\(question.index + 1) / \(total)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if showCloseButton { closeButton }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.black)
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.easeInOut(duration: 0.25), value: progress)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 相棒の待機バナー（回答後に変化することを予告）
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(
                            Color.gray.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Text("8つの質問に答えると、あなたの好みを理解した相棒に変化します")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 18)

            // 質問見出し
            VStack(alignment: .leading, spacing: 10) {
                Text(question.axisBadge)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())

                Text(question.questionText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint = question.hint {
                    Text(hint)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            // 選択肢カード
            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    let isSelected = viewModel.selectedValueInCurrentStep == option.value
                    Button {
                        viewModel.selectOption(option, for: question)
                    } label: {
                        HStack(spacing: 12) {
                            Text(option.label)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .black)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Color.gray.opacity(0.45))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, question.options.count >= 5 ? 14 : 18)
                        .background(isSelected ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.black : Color.gray.opacity(0.22), lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, question.options.count >= 5 ? 18 : 24)

            Spacer()
        }
    }

    // MARK: - ローディング

    private var loadingStepView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
                .tint(.black)
            Text("あなたの回答から、相棒を準備しています...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 2: 相棒誕生 & 変化の理由カード

    private func birthStepView(response: PartnerOnboardingResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 16)

                    // 誕生した相棒アバター + タイプ名
                    VStack(spacing: 10) {
                        Text("あなたの相棒が誕生しました")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        partnerIllustration(typeName: response.type_name)

                        Text(response.type_name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)

                        Text(response.partner_subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)

                    // 相棒からの最初のひとこと（選んだ話し方で表示）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            PartnerIconImage(size: 26)
                            Text("相棒からのひとこと")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("話し方：\(response.speaking_style_label)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }

                        Text(response.birth_greeting)
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    // なぜこの相棒に変化したか（4つの特徴の内訳）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("相棒に反映されたあなたの特徴")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(response.traits) { trait in
                            HStack(alignment: .top, spacing: 12) {
                                Text(trait.axis_label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 96, alignment: .leading)

                                Text(trait.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            if trait.id != response.traits.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }

            // ホームへ進むCTA
            VStack(spacing: 10) {
                Button(action: {
                    Haptic.impact(.medium)
                    // 初めて相棒が生まれた人で、ファッション感度が 70 点未満なら、基本の案内を 3 枚はさむ
                    if mode == .registration, response.fashion_sense?.needs_beginner_guide == true {
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.step = .beginnerGuide }
                    } else {
                        onComplete()
                    }
                }) {
                    Text("相棒とコーデを見てみる")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func partnerIllustration(typeName: String) -> some View {
        if UIImage(named: typeName) != nil {
            Image(typeName)
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        } else {
            PartnerIconImage(size: 96)
        }
    }
}

#Preview {
    PartnerOnboardingFlowView(showCloseButton: true, onComplete: {})
}
