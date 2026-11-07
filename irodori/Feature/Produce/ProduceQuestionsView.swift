//
//  ProduceQuestionsView.swift
//  irodori
//
//  すでに相棒がいる人が、プロデュースを初めて開いたときに答える 4 問
//  (服の数・月の金額・1 着の最高額・好きなブランドの数)。
//  質問の中身と見た目は初回オンボーディングの 8 問と同じ (PartnerOnboardingQuestion を使い回す)。
//  答え終わったら POST api/partner/profile-answers で保存する (相棒のタイプは変わらない)。
//

import SwiftUI

struct ProduceQuestionsView: View {
    let onFinished: () -> Void

    private static let axes = ["closet_size", "monthly_spend", "max_price", "brand_count"]
    private let questions = PartnerOnboardingQuestion.all.filter { ProduceQuestionsView.axes.contains($0.axis) }

    @State private var index = 0
    @State private var answers: [String: String] = [:]
    @State private var picked: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if index > 0 {
                        Button {
                            Haptic.selection()
                            withAnimation { index -= 1 }
                        } label: {
                            Label("戻る", systemImage: "chevron.left")
                                .font(.system(size: 14))
                                .foregroundStyle(.black)
                                .frame(minHeight: 44)
                        }
                    }
                    Spacer()
                    Text("\(index + 1) / \(questions.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15)).frame(height: 4)
                        Capsule().fill(Color.black)
                            .frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(max(questions.count, 1)), height: 4)
                    }
                }
                .frame(height: 4)
                Text("あと \(questions.count - index) 問で、合うブランド・服・コーデを提案するよ")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if let q = questions[safe: index] {
                VStack(alignment: .leading, spacing: 10) {
                    Text(q.axisBadge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1), in: Capsule())
                    Text(q.questionText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    if let hint = q.hint {
                        Text(hint).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(q.options) { option in
                        let isSelected = picked == option.value
                        Button { select(option, for: q) } label: {
                            HStack {
                                Text(option.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : .black)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : Color.gray.opacity(0.45))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, q.options.count >= 5 ? 14 : 18)
                            .background(isSelected ? Color.black : Color.white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.black : Color.gray.opacity(0.22), lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            if isSaving {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func select(_ option: PartnerOnboardingOption, for q: PartnerOnboardingQuestion) {
        Haptic.selection()
        picked = option.value
        answers[q.axis] = option.value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            picked = nil
            if index + 1 < questions.count {
                withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
            } else {
                Task { await save() }
            }
        }
    }

    private func save() async {
        guard let c = answers["closet_size"], let m = answers["monthly_spend"],
              let p = answers["max_price"], let b = answers["brand_count"] else { return }
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        isSaving = true
        errorMessage = nil
        let result = try? await PartnerClient().saveProfileAnswers(
            userId: uid, answers: PartnerProfileAnswers(closet_size: c, monthly_spend: m, max_price: p, brand_count: b))
        isSaving = false
        if case .success = result {
            Haptic.notify(.success)
            onFinished()
        } else {
            Haptic.notify(.error)
            errorMessage = "保存できませんでした。通信を確かめて、もう一度選んでください。"
        }
    }
}
