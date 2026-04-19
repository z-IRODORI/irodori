//
//  FashionTypeViewModel.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class FashionTypeViewModel {
    // MARK: - Properties

    // 状態管理
    var currentQuestionIndex: Int = 0
    var answers: [Int: Int] = [:]  // [questionId: score]
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var showError: Bool = false

    // 依存性注入
    private let apiClient: FashionTypeClientProtocol

    // MARK: - Computed Properties

    var progress: Double {
        Double(currentQuestionIndex + 1) / Double(FashionTypeQuestion.questions.count)
    }

    var isLastQuestion: Bool {
        currentQuestionIndex == FashionTypeQuestion.questions.count - 1
    }

    var canGoBack: Bool {
        currentQuestionIndex > 0
    }

    var currentQuestion: FashionTypeQuestion {
        FashionTypeQuestion.questions[currentQuestionIndex]
    }

    var selectedScore: Int? {
        answers[currentQuestion.id]
    }

    var canProceed: Bool {
        selectedScore != nil
    }

    var showCompleteButton: Bool {
        isLastQuestion && canProceed
    }

    // MARK: - Initialization

    init(apiClient: FashionTypeClientProtocol = MockFashionTypeClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Methods

    /// スコア選択
    func selectScore(_ score: Int) {
        answers[currentQuestion.id] = score
        triggerHaptic(count: 1)
    }

    /// 次の質問へ
    func goToNextQuestion() {
        guard !isLastQuestion else { return }
        triggerHaptic(count: 2)
        withAnimation(.easeInOut(duration: 0.3)) {
            currentQuestionIndex += 1
        }
    }

    /// 前の質問へ戻る
    func goToPreviousQuestion() {
        guard canGoBack else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentQuestionIndex -= 1
        }
    }

    /// Hapticフィードバック
    private func triggerHaptic(count: Int) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()

        for i in 0..<count {
            if i > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    generator.impactOccurred()
                }
            } else {
                generator.impactOccurred()
            }
        }
    }

    /// 完了ボタンタップ
    func complete() async -> FashionTypeResponse? {
        guard answers.count == FashionTypeQuestion.questions.count else {
            errorMessage = "すべての質問に回答してください"
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""

        let request = FashionTypeRequest(
            user_id: uid,
            Q1: answers[1] ?? 3,
            Q2: answers[2] ?? 3,
            Q3: answers[3] ?? 3,
            Q4: answers[4] ?? 3,
            Q5: answers[5] ?? 3,
            Q6: answers[6] ?? 3,
            Q7: answers[7] ?? 3,
            Q8: answers[8] ?? 3,
            Q9: answers[9] ?? 3,
            Q10: answers[10] ?? 3
        )

        do {
            let result = try await apiClient.post(request: request)

            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                errorMessage = error.errorDescription
                showError = true
                return nil
            }
        } catch {
            errorMessage = "診断結果の送信に失敗しました"
            showError = true
            return nil
        }
    }
}
