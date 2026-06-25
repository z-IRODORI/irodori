//
//  PartnerClient.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  相棒機能（/api/partner/*）のAPIクライアント。
//

import Foundation

protocol PartnerClientProtocol {
    func getHome(userId: String) async throws -> Result<PartnerHomeResponse, HTTPError>
    func getAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError>
    func regenerateAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError>
    func sendAdviceFeedback(userId: String, adviceId: String, reaction: String) async throws -> Result<PartnerAdviceFeedbackResponse, HTTPError>
    func getDailyQuestion(userId: String) async throws -> Result<PartnerDailyQuestionResponse, HTTPError>
    func answerDailyQuestion(userId: String, questionId: String, choice: String?, freeText: String?, skipped: Bool) async throws -> Result<PartnerAnswerResponse, HTTPError>
    func getInsightCards(userId: String, limit: Int) async throws -> Result<PartnerInsightCardsResponse, HTTPError>
    func reactToCard(userId: String, cardId: String, cardTitle: String?, reaction: String) async throws -> Result<PartnerCardReactionResponse, HTTPError>
    func getStyleQuiz(userId: String, gender: String, pairs: Int) async throws -> Result<PartnerStyleQuizResponse, HTTPError>
    func voteStyleQuiz(userId: String, pairId: String, choice: String, leftPoolId: String, rightPoolId: String) async throws -> Result<PartnerVoteResponse, HTTPError>
    func getHypotheses(userId: String) async throws -> Result<PartnerHypothesesResponse, HTTPError>
    func sendVerdict(userId: String, hypothesisId: String, verdict: String, comment: String?) async throws -> Result<PartnerVerdictResponse, HTTPError>
    func getNotebook(userId: String) async throws -> Result<PartnerNotebookResponse, HTTPError>
    func getGrowth(userId: String) async throws -> Result<PartnerGrowthResponse, HTTPError>
    func getSpeakingStyle(userId: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError>
    func setSpeakingStyle(userId: String, style: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError>
}

// MARK: - リクエストボディ

private struct AdviceFeedbackBody: Encodable {
    let user_id: String
    let advice_id: String
    let reaction: String
}

private struct AdviceRegenerateBody: Encodable {
    let user_id: String
}

private struct DailyQuestionAnswerBody: Encodable {
    let user_id: String
    let question_id: String
    let choice: String?
    let free_text: String?
    let skipped: Bool
}

private struct CardReactionBody: Encodable {
    let user_id: String
    let card_id: String
    let card_title: String?
    let reaction: String
}

private struct StyleQuizVoteBody: Encodable {
    let user_id: String
    let pair_id: String
    let choice: String
    let left_pool_id: String
    let right_pool_id: String
}

private struct HypothesisVerdictBody: Encodable {
    let user_id: String
    let hypothesis_id: String
    let verdict: String
    let comment: String?
}

private struct SpeakingStyleBody: Encodable {
    let user_id: String
    let style: String
}

// MARK: - 実装

final class PartnerClient: PartnerClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func getHome(userId: String) async throws -> Result<PartnerHomeResponse, HTTPError> {
        try await get(endpoint: "api/partner/home", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func getAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try await get(endpoint: "api/partner/advice", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func regenerateAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try await post(endpoint: "api/partner/advice/regenerate", body: AdviceRegenerateBody(user_id: userId))
    }

    func sendAdviceFeedback(userId: String, adviceId: String, reaction: String) async throws -> Result<PartnerAdviceFeedbackResponse, HTTPError> {
        try await post(
            endpoint: "api/partner/advice/feedback",
            body: AdviceFeedbackBody(user_id: userId, advice_id: adviceId, reaction: reaction)
        )
    }

    func getDailyQuestion(userId: String) async throws -> Result<PartnerDailyQuestionResponse, HTTPError> {
        try await get(endpoint: "api/partner/daily-question", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func answerDailyQuestion(userId: String, questionId: String, choice: String?, freeText: String?, skipped: Bool) async throws -> Result<PartnerAnswerResponse, HTTPError> {
        try await post(
            endpoint: "api/partner/daily-question/answer",
            body: DailyQuestionAnswerBody(user_id: userId, question_id: questionId, choice: choice, free_text: freeText, skipped: skipped)
        )
    }

    func getInsightCards(userId: String, limit: Int) async throws -> Result<PartnerInsightCardsResponse, HTTPError> {
        try await get(endpoint: "api/partner/insight-cards", queryItems: [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func reactToCard(userId: String, cardId: String, cardTitle: String?, reaction: String) async throws -> Result<PartnerCardReactionResponse, HTTPError> {
        try await post(
            endpoint: "api/partner/insight-cards/reaction",
            body: CardReactionBody(user_id: userId, card_id: cardId, card_title: cardTitle, reaction: reaction)
        )
    }

    func getStyleQuiz(userId: String, gender: String, pairs: Int) async throws -> Result<PartnerStyleQuizResponse, HTTPError> {
        try await get(endpoint: "api/partner/style-quiz", queryItems: [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "gender", value: gender),
            URLQueryItem(name: "pairs", value: String(pairs)),
        ])
    }

    func voteStyleQuiz(userId: String, pairId: String, choice: String, leftPoolId: String, rightPoolId: String) async throws -> Result<PartnerVoteResponse, HTTPError> {
        try await post(
            endpoint: "api/partner/style-quiz/vote",
            body: StyleQuizVoteBody(user_id: userId, pair_id: pairId, choice: choice, left_pool_id: leftPoolId, right_pool_id: rightPoolId)
        )
    }

    func getHypotheses(userId: String) async throws -> Result<PartnerHypothesesResponse, HTTPError> {
        try await get(endpoint: "api/partner/hypotheses", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func sendVerdict(userId: String, hypothesisId: String, verdict: String, comment: String?) async throws -> Result<PartnerVerdictResponse, HTTPError> {
        try await post(
            endpoint: "api/partner/hypotheses/verdict",
            body: HypothesisVerdictBody(user_id: userId, hypothesis_id: hypothesisId, verdict: verdict, comment: comment)
        )
    }

    func getNotebook(userId: String) async throws -> Result<PartnerNotebookResponse, HTTPError> {
        try await get(endpoint: "api/partner/notebook", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func getGrowth(userId: String) async throws -> Result<PartnerGrowthResponse, HTTPError> {
        try await get(endpoint: "api/partner/growth", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func getSpeakingStyle(userId: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        try await get(endpoint: "api/partner/speaking-style", queryItems: [URLQueryItem(name: "user_id", value: userId)])
    }

    func setSpeakingStyle(userId: String, style: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        try await post(endpoint: "api/partner/speaking-style", body: SpeakingStyleBody(user_id: userId, style: style))
    }

    // MARK: - 共通リクエスト処理

    private func get<Response: Decodable>(endpoint: String, queryItems: [URLQueryItem]) async throws -> Result<Response, HTTPError> {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await send(request)
    }

    private func post<Body: Encodable, Response: Decodable>(endpoint: String, body: Body) async throws -> Result<Response, HTTPError> {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Result<Response, HTTPError> {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.responseError)
            }

            if httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }

            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            return .success(decodedResponse)
        } catch is DecodingError {
            return .failure(.decodeError)
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockPartnerClient: PartnerClientProtocol {
    func getHome(userId: String) async throws -> Result<PartnerHomeResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return .success(.mock())
    }

    func getAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return .success(.mock())
    }

    func regenerateAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return .success(.mock())
    }

    func sendAdviceFeedback(userId: String, adviceId: String, reaction: String) async throws -> Result<PartnerAdviceFeedbackResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 250_000_000)
        return .success(.mock(reaction: reaction))
    }

    func getDailyQuestion(userId: String) async throws -> Result<PartnerDailyQuestionResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return .success(.mock())
    }

    func answerDailyQuestion(userId: String, questionId: String, choice: String?, freeText: String?, skipped: Bool) async throws -> Result<PartnerAnswerResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 300_000_000)
        if skipped {
            return .success(PartnerAnswerResponse(
                status: "success",
                reaction: "OK、今日はパス！それも大事な答えだよ。また明日きくね 🌷",
                exp_gained: 2,
                state: .mock(exp: 122)
            ))
        }
        let answer = freeText ?? choice ?? ""
        return .success(PartnerAnswerResponse(
            status: "success",
            reaction: "「\(answer)」かあ、いいね。あなたの「らしさ」のピースがまたひとつ集まったよ。",
            exp_gained: 10,
            state: .mock(exp: 130)
        ))
    }

    func getInsightCards(userId: String, limit: Int) async throws -> Result<PartnerInsightCardsResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return .success(.mock())
    }

    func reactToCard(userId: String, cardId: String, cardTitle: String?, reaction: String) async throws -> Result<PartnerCardReactionResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 250_000_000)
        return .success(.mock(reaction: reaction))
    }

    func getStyleQuiz(userId: String, gender: String, pairs: Int) async throws -> Result<PartnerStyleQuizResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return .success(.mock())
    }

    private var mockVotes = 12

    func voteStyleQuiz(userId: String, pairId: String, choice: String, leftPoolId: String, rightPoolId: String) async throws -> Result<PartnerVoteResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 200_000_000)
        mockVotes += 1
        return .success(.mock(votesTotal: mockVotes))
    }

    func getHypotheses(userId: String) async throws -> Result<PartnerHypothesesResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 350_000_000)
        return .success(.mock())
    }

    func sendVerdict(userId: String, hypothesisId: String, verdict: String, comment: String?) async throws -> Result<PartnerVerdictResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let hypothesis = PartnerHypothesis.mocks().first { $0.id == hypothesisId }
            ?? PartnerHypothesis(id: hypothesisId, text: "あなたらしさの仮説", source_hint: nil, status: "pending")
        return .success(.mock(verdict: verdict, hypothesis: hypothesis))
    }

    func getNotebook(userId: String) async throws -> Result<PartnerNotebookResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return .success(.mock())
    }

    func getGrowth(userId: String) async throws -> Result<PartnerGrowthResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return .success(.mock())
    }

    func getSpeakingStyle(userId: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        return .success(.mock())
    }

    func setSpeakingStyle(userId: String, style: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        return .success(.mock(selected: style))
    }
}

// MARK: - フォールバック付きクライアント

/// 本番APIを優先し、失敗時（API未デプロイ・オフライン等）はMockデータで画面を成立させる。
/// 5パターンのデザイン検討中でもAPIなしで全画面を確認できるようにするための実装。
final class FallbackPartnerClient: PartnerClientProtocol {
    private let real: PartnerClientProtocol
    private let mock: PartnerClientProtocol

    init(real: PartnerClientProtocol = PartnerClient(), mock: PartnerClientProtocol = MockPartnerClient()) {
        self.real = real
        self.mock = mock
    }

    private func withFallback<T>(
        _ realCall: () async throws -> Result<T, HTTPError>,
        _ mockCall: () async throws -> Result<T, HTTPError>
    ) async throws -> Result<T, HTTPError> {
        do {
            let result = try await realCall()
            if case .success = result {
                return result
            }
            return try await mockCall()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await mockCall()
        }
    }

    func getHome(userId: String) async throws -> Result<PartnerHomeResponse, HTTPError> {
        try await withFallback({ try await real.getHome(userId: userId) }, { try await mock.getHome(userId: userId) })
    }

    func getAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try await withFallback({ try await real.getAdvice(userId: userId) }, { try await mock.getAdvice(userId: userId) })
    }

    func regenerateAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> {
        try await withFallback({ try await real.regenerateAdvice(userId: userId) }, { try await mock.regenerateAdvice(userId: userId) })
    }

    func sendAdviceFeedback(userId: String, adviceId: String, reaction: String) async throws -> Result<PartnerAdviceFeedbackResponse, HTTPError> {
        try await withFallback(
            { try await real.sendAdviceFeedback(userId: userId, adviceId: adviceId, reaction: reaction) },
            { try await mock.sendAdviceFeedback(userId: userId, adviceId: adviceId, reaction: reaction) }
        )
    }

    func getDailyQuestion(userId: String) async throws -> Result<PartnerDailyQuestionResponse, HTTPError> {
        try await withFallback({ try await real.getDailyQuestion(userId: userId) }, { try await mock.getDailyQuestion(userId: userId) })
    }

    func answerDailyQuestion(userId: String, questionId: String, choice: String?, freeText: String?, skipped: Bool) async throws -> Result<PartnerAnswerResponse, HTTPError> {
        try await withFallback(
            { try await real.answerDailyQuestion(userId: userId, questionId: questionId, choice: choice, freeText: freeText, skipped: skipped) },
            { try await mock.answerDailyQuestion(userId: userId, questionId: questionId, choice: choice, freeText: freeText, skipped: skipped) }
        )
    }

    func getInsightCards(userId: String, limit: Int) async throws -> Result<PartnerInsightCardsResponse, HTTPError> {
        try await withFallback({ try await real.getInsightCards(userId: userId, limit: limit) }, { try await mock.getInsightCards(userId: userId, limit: limit) })
    }

    func reactToCard(userId: String, cardId: String, cardTitle: String?, reaction: String) async throws -> Result<PartnerCardReactionResponse, HTTPError> {
        try await withFallback(
            { try await real.reactToCard(userId: userId, cardId: cardId, cardTitle: cardTitle, reaction: reaction) },
            { try await mock.reactToCard(userId: userId, cardId: cardId, cardTitle: cardTitle, reaction: reaction) }
        )
    }

    func getStyleQuiz(userId: String, gender: String, pairs: Int) async throws -> Result<PartnerStyleQuizResponse, HTTPError> {
        try await withFallback(
            { try await real.getStyleQuiz(userId: userId, gender: gender, pairs: pairs) },
            { try await mock.getStyleQuiz(userId: userId, gender: gender, pairs: pairs) }
        )
    }

    func voteStyleQuiz(userId: String, pairId: String, choice: String, leftPoolId: String, rightPoolId: String) async throws -> Result<PartnerVoteResponse, HTTPError> {
        try await withFallback(
            { try await real.voteStyleQuiz(userId: userId, pairId: pairId, choice: choice, leftPoolId: leftPoolId, rightPoolId: rightPoolId) },
            { try await mock.voteStyleQuiz(userId: userId, pairId: pairId, choice: choice, leftPoolId: leftPoolId, rightPoolId: rightPoolId) }
        )
    }

    func getHypotheses(userId: String) async throws -> Result<PartnerHypothesesResponse, HTTPError> {
        try await withFallback({ try await real.getHypotheses(userId: userId) }, { try await mock.getHypotheses(userId: userId) })
    }

    func sendVerdict(userId: String, hypothesisId: String, verdict: String, comment: String?) async throws -> Result<PartnerVerdictResponse, HTTPError> {
        try await withFallback(
            { try await real.sendVerdict(userId: userId, hypothesisId: hypothesisId, verdict: verdict, comment: comment) },
            { try await mock.sendVerdict(userId: userId, hypothesisId: hypothesisId, verdict: verdict, comment: comment) }
        )
    }

    func getNotebook(userId: String) async throws -> Result<PartnerNotebookResponse, HTTPError> {
        try await withFallback({ try await real.getNotebook(userId: userId) }, { try await mock.getNotebook(userId: userId) })
    }

    func getGrowth(userId: String) async throws -> Result<PartnerGrowthResponse, HTTPError> {
        try await withFallback({ try await real.getGrowth(userId: userId) }, { try await mock.getGrowth(userId: userId) })
    }

    func getSpeakingStyle(userId: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        try await withFallback({ try await real.getSpeakingStyle(userId: userId) }, { try await mock.getSpeakingStyle(userId: userId) })
    }

    func setSpeakingStyle(userId: String, style: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> {
        try await withFallback({ try await real.setSpeakingStyle(userId: userId, style: style) }, { try await mock.setSpeakingStyle(userId: userId, style: style) })
    }
}
