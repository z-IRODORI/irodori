//
//  RenewalOnboardingView.swift
//  irodori - Sandbox
//
//  初回オンボーディング (onboarding_and_data_flow_design.md)
//   Step 0: 相棒の価値 (3つのメリット) を伝える導入
//   Step 1: MECE な4問をチャット形式で (印象 / 感覚 / 提案の幅 / 話し方)
//   Step 2: 無色の相棒に色と口調が宿り、「4つの回答から作られた指針」を提示
//  Lv・EXP・クエスト等のゲーム用語は使わない。
//

import SwiftUI

struct RenewalOnboardingView: View {
    enum Mode { case first, edit }

    let store: RenewalStore
    var mode: Mode = .first
    var onFinish: () -> Void

    private enum Step: Equatable { case intro, questions, birthing, born }

    @State private var step: Step = .intro
    @State private var answers = RenewalAnswers()
    /// 画面に出した質問の数 (1〜4)
    @State private var revealedCount = 1
    /// 回答済みの質問 (選び直しても後続は消さない)
    @State private var answered: Set<Int> = []
    /// 画面上部へスクロールさせたい質問
    @State private var focusIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RenewalTokens.ground.ignoresSafeArea()
            switch step {
            case .intro: intro
            case .questions: questions
            case .birthing, .born: birth
            }
        }
        .onAppear {
            if mode == .edit {
                answers = store.answers
                step = .questions
            }
        }
    }

    // MARK: - Step 0

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RenewalPartnerIllustration(typeName: "クリーン・スタンダード", height: 150, colorless: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("あなたのことを一番理解し、\n次のコーデを決めてくれる「相棒」")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("IRODORI の中心にいるのは、あなた専属の相棒です。あなたの価値観や手持ちの服を記憶し、使うほどあなた好みに育っていきます。")
                        .font(.system(size: 14))
                        .foregroundStyle(RenewalTokens.muted)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    benefit(1, "毎朝の「何を着よう」に納得の答え", "気温差や昨日着た服を踏まえ、理由とセットで3案を出します。")
                    Divider().overlay(RenewalTokens.rule)
                    benefit(2, "手持ちの服を最大限に活かす", "クローゼットを覚え、今ある服をベースに着回しを組み立てます。")
                    Divider().overlay(RenewalTokens.rule)
                    benefit(3, "使うほど、あなた専用に", "選んだ服や登録した服から、似合う・心地いいを学んでいきます。")
                }
                .renewalCard()

                Button("4つの質問で、相棒をカスタマイズする (約30秒)") {
                    Haptic.impact(.soft)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { step = .questions }
                }
                .buttonStyle(RenewalPrimaryButtonStyle())
                .padding(.bottom, 24)
            }
            .padding(.horizontal, RenewalTokens.edge)
        }
    }

    private func benefit(_ n: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(RenewalTokens.ink)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(RenewalTokens.controlBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
                Text(body).font(.system(size: 13)).foregroundStyle(RenewalTokens.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Step 1 (チャット形式の4問)

    private struct Option: Identifiable {
        let id: String
        let label: String
        let sub: String
    }

    private struct Question {
        let axis: String
        let text: String
        let options: [Option]
    }

    private var questionList: [Question] {
        [
            Question(axis: "外向きの印象",
                     text: "人と会うとき、周りから「どんな印象の人」に見られると嬉しいですか？",
                     options: RenewalImpression.allCases.map { Option(id: $0.rawValue, label: $0.label, sub: $0.sub) }),
            Question(axis: "内向きの感覚",
                     text: "1日を過ごすとき、自分の感覚としてどちらを優先したいですか？",
                     options: RenewalPriority.allCases.map { Option(id: $0.rawValue, label: $0.label, sub: $0.sub) }),
            Question(axis: "提案の振れ幅",
                     text: "相棒からの日々のコーデ提案には、どちらの役割をより期待しますか？",
                     options: RenewalRange.allCases.map { Option(id: $0.rawValue, label: $0.label, sub: $0.sub) }),
            Question(axis: "話し方",
                     text: "毎日やりとりする相棒には、どんな話し方で伴走してほしいですか？",
                     options: RenewalTone.allCases.map { Option(id: $0.rawValue, label: $0.label, sub: $0.character) }),
        ]
    }

    private func selectedValue(_ index: Int) -> String {
        switch index {
        case 0: return answers.impression.rawValue
        case 1: return answers.priority.rawValue
        case 2: return answers.range.rawValue
        default: return answers.tone.rawValue
        }
    }

    /// 1問ずつチャットで出し、新しい質問は画面上部までスクロールして見せる。
    /// 回答済みの質問はスクロールで戻って選び直せる (後続の回答は消さない)。
    private var questions: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                progressHeader(proxy)
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(0..<revealedCount, id: \.self) { i in
                            // 上部へ移動したとき、ヘッダーとの間に余白が残るよう id の内側に余白を持たせる
                            questionBlock(i)
                                .padding(.top, 16)
                                .id(i)
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity))
                        }
                        // 最後の質問も画面上部まで上げられるよう、下に余白を取る
                        Color.clear
                            .frame(height: 1)
                            .containerRelativeFrame(.vertical) { h, _ in h * 0.6 }
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, RenewalTokens.edge)
                    .padding(.top, 4)
                }
                .scrollDismissesKeyboard(.never)
            }
            .safeAreaInset(edge: .bottom) {
                if answered.count == 4 { finishBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .onChange(of: focusIndex) {
                guard let target = focusIndex else { return }
                // 挿入アニメーションの後に、質問を画面上部へ移動させる
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 120))
                    withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.9)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    focusIndex = nil
                }
            }
        }
        .onAppear {
            if mode == .edit {
                revealedCount = 4
                answered = [0, 1, 2, 3]
            }
        }
    }

    private func progressHeader(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(mode == .edit ? "4問の回答を変更" : "相棒をカスタマイズ")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(answered.count) / 4 回答")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(RenewalTokens.muted)
            }
            // 各セグメントをタップすると、その質問へ戻れる
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Button {
                        guard i < revealedCount else { return }
                        Haptic.selection()
                        focusIndex = i
                    } label: {
                        Capsule()
                            .fill(answered.contains(i) ? RenewalTokens.ink : RenewalTokens.border)
                            .frame(height: 3)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(i >= revealedCount)
                    .accessibilityLabel("Q\(i + 1) \(questionList[i].axis)へ移動")
                }
            }
        }
        .padding(.horizontal, RenewalTokens.edge)
        .padding(.top, 12)
        .background(RenewalTokens.surface)
        .overlay(alignment: .bottom) { Divider().overlay(RenewalTokens.rule) }
    }

    private func questionBlock(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            partnerBubble(questionList[i].text, axis: "Q\(i + 1) \(questionList[i].axis)")
            options(for: i)
        }
    }

    private func partnerBubble(_ text: String, axis: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 誕生前はタイプを明かさないよう、固定の無色シルエットにする
            RenewalPartnerAvatar(typeName: "クリーン・スタンダード", size: 32, colorless: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(axis)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .renewalCard()
            Spacer(minLength: 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// 選択肢は画面幅いっぱい。選んだものは「自分の発言」と同じ濃い色で示す
    private func options(for index: Int) -> some View {
        VStack(spacing: 8) {
            ForEach(questionList[index].options) { opt in
                let on = answered.contains(index) && selectedValue(index) == opt.id
                Button {
                    select(index: index, value: opt.id)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opt.label)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(on ? .white : RenewalTokens.ink)
                            Text(opt.sub)
                                .font(.system(size: 12))
                                .foregroundStyle(on ? .white.opacity(0.82) : RenewalTokens.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(on ? RenewalTokens.primaryFill : RenewalTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
                    .overlay(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius)
                        .stroke(on ? Color.clear : RenewalTokens.border, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var finishBar: some View {
        VStack(spacing: 6) {
            Text("回答はスクロールで戻って変更できます")
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
            Button(mode == .edit ? "この回答で保存" : "この4つの回答で相棒をつくる") { finish() }
                .buttonStyle(RenewalPrimaryButtonStyle())
        }
        .padding(.horizontal, RenewalTokens.edge)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(RenewalTokens.surface.shadow(.drop(color: .black.opacity(0.06), radius: 6, y: -2)))
    }

    private func select(index: Int, value: String) {
        Haptic.selection()
        let isChange = answered.contains(index)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            switch index {
            case 0: answers.impression = RenewalImpression(rawValue: value) ?? .soft
            case 1: answers.priority = RenewalPriority(rawValue: value) ?? .F
            case 2: answers.range = RenewalRange(rawValue: value) ?? .C
            default: answers.tone = RenewalTone(rawValue: value) ?? .gentle
            }
            answered.insert(index)
        }
        // 過去の質問の選び直しでは、画面を動かさない
        guard !isChange, index == revealedCount - 1, revealedCount < 4 else { return }
        Task { @MainActor in
            // 選んだ選択肢を一瞬見せてから次の質問を出す
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 220))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { revealedCount += 1 }
            focusIndex = revealedCount - 1
        }
    }

    private func finish() {
        if mode == .edit {
            store.updateAnswers(answers)
            store.showToast(RenewalCopy.toneChanged(answers.tone))
            onFinish()
            return
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { step = .birthing }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1400))
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                step = .born
            }
            Haptic.notify(.success)
        }
    }

    // MARK: - Step 2 (相棒の誕生)

    private var birth: some View {
        let born = step == .born
        return ScrollView {
            VStack(spacing: 20) {
                RenewalPartnerIllustration(typeName: answers.typeName, height: 200, colorless: !born)
                    .padding(.top, 28)
                    .scaleEffect(born || reduceMotion ? 1 : 0.94)

                if !born {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("4つの回答から、あなた専属の相棒を形づくっています")
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                } else {
                    VStack(spacing: 6) {
                        Text(answers.typeName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(RenewalTokens.ink)
                        Text("話し方: \(answers.tone.label)")
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.muted)
                    }

                    let greeting = RenewalCopy.birthGreeting(answers)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RenewalTokens.ink)
                            .lineSpacing(3)
                        if store.showCharCount { RenewalCharCountBadge(text: greeting) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .renewalCard()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("あなたの回答から作られた相棒の指針")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(14)
                        Divider().overlay(RenewalTokens.rule)
                        principle("目指す印象", answers.impression.label)
                        principle("服選びの基準", answers.priority.label)
                        principle("提案のスタンス", answers.range.stance)
                        principle("話し方", answers.tone.label)
                    }
                    .renewalCard()

                    Button("ホームへ") {
                        store.completeOnboarding(answers)
                        onFinish()
                    }
                    .buttonStyle(RenewalPrimaryButtonStyle())
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, RenewalTokens.edge)
        }
    }

    private func principle(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
