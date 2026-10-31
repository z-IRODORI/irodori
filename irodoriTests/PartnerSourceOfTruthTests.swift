//
//  PartnerSourceOfTruthTests.swift
//  irodoriTests
//
//  相棒のタイプはサーバの値だけを端末に写す (PartnerLocalMirror) ことと、
//  4つの質問の保存が「登録」と「更新」で別の API を呼び、前のデータの扱いが違うことの回帰テスト。
//  端末の UserDefaults を使うので、このスイートの中は順番に流す。
//

import Foundation
import Testing
@testable import irodori

/// 呼ばれた API を数える偽のクライアント。4つの質問の保存と相棒ホームだけを差し替える
private final class RecordingPartnerClient: PartnerClientProtocol, @unchecked Sendable {
    private let base = MockPartnerClient()
    var saveCalls = 0
    var updateCalls = 0
    var fail = false
    var home: PartnerHomeResponse?

    private func answer(_ impression: String, _ priority: String, _ rangeVal: String, _ tone: String) -> Result<PartnerOnboardingResponse, HTTPError> {
        fail ? .failure(.responseError) : .success(.mock(impression: impression, priority: priority, rangeVal: rangeVal, tone: tone))
    }

    func saveOnboarding(userId: String, impression: String, priority: String, rangeVal: String, tone: String) async throws -> Result<PartnerOnboardingResponse, HTTPError> {
        saveCalls += 1
        return answer(impression, priority, rangeVal, tone)
    }
    func updatePartner(userId: String, impression: String, priority: String, rangeVal: String, tone: String) async throws -> Result<PartnerOnboardingResponse, HTTPError> {
        updateCalls += 1
        return answer(impression, priority, rangeVal, tone)
    }
    func getHome(userId: String) async throws -> Result<PartnerHomeResponse, HTTPError> {
        if let home { return .success(home) }
        return .failure(.responseError)
    }

    // ここから下は使わない (MockPartnerClient にそのまま任せる)
    func getAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> { try await base.getAdvice(userId: userId) }
    func regenerateAdvice(userId: String) async throws -> Result<PartnerAdviceResponse, HTTPError> { try await base.regenerateAdvice(userId: userId) }
    func sendAdviceFeedback(userId: String, adviceId: String, reaction: String) async throws -> Result<PartnerAdviceFeedbackResponse, HTTPError> { try await base.sendAdviceFeedback(userId: userId, adviceId: adviceId, reaction: reaction) }
    func getDailyQuestion(userId: String) async throws -> Result<PartnerDailyQuestionResponse, HTTPError> { try await base.getDailyQuestion(userId: userId) }
    func answerDailyQuestion(userId: String, questionId: String, choice: String?, freeText: String?, skipped: Bool) async throws -> Result<PartnerAnswerResponse, HTTPError> { try await base.answerDailyQuestion(userId: userId, questionId: questionId, choice: choice, freeText: freeText, skipped: skipped) }
    func getInsightCards(userId: String, limit: Int) async throws -> Result<PartnerInsightCardsResponse, HTTPError> { try await base.getInsightCards(userId: userId, limit: limit) }
    func reactToCard(userId: String, cardId: String, cardTitle: String?, reaction: String) async throws -> Result<PartnerCardReactionResponse, HTTPError> { try await base.reactToCard(userId: userId, cardId: cardId, cardTitle: cardTitle, reaction: reaction) }
    func getStyleQuiz(userId: String, gender: String, pairs: Int) async throws -> Result<PartnerStyleQuizResponse, HTTPError> { try await base.getStyleQuiz(userId: userId, gender: gender, pairs: pairs) }
    func voteStyleQuiz(userId: String, pairId: String, choice: String, leftPoolId: String, rightPoolId: String) async throws -> Result<PartnerVoteResponse, HTTPError> { try await base.voteStyleQuiz(userId: userId, pairId: pairId, choice: choice, leftPoolId: leftPoolId, rightPoolId: rightPoolId) }
    func getHypotheses(userId: String) async throws -> Result<PartnerHypothesesResponse, HTTPError> { try await base.getHypotheses(userId: userId) }
    func sendVerdict(userId: String, hypothesisId: String, verdict: String, comment: String?) async throws -> Result<PartnerVerdictResponse, HTTPError> { try await base.sendVerdict(userId: userId, hypothesisId: hypothesisId, verdict: verdict, comment: comment) }
    func getNotebook(userId: String) async throws -> Result<PartnerNotebookResponse, HTTPError> { try await base.getNotebook(userId: userId) }
    func getGrowth(userId: String) async throws -> Result<PartnerGrowthResponse, HTTPError> { try await base.getGrowth(userId: userId) }
    func getSpeakingStyle(userId: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> { try await base.getSpeakingStyle(userId: userId) }
    func setSpeakingStyle(userId: String, style: String) async throws -> Result<PartnerSpeakingStyleResponse, HTTPError> { try await base.setSpeakingStyle(userId: userId, style: style) }
    func proposeOutfitSuggestion(userId: String, gender: String, when: String, looks: [String], withWho: String?, whereText: String?, prefectureCode: String?) async throws -> Result<OutfitSuggestionResponse, HTTPError> { try await base.proposeOutfitSuggestion(userId: userId, gender: gender, when: when, looks: looks, withWho: withWho, whereText: whereText, prefectureCode: prefectureCode) }
}

private final class Flag: @unchecked Sendable { var value = false }

@MainActor
@Suite(.serialized)
struct PartnerSourceOfTruthTests {
    private let ud = UserDefaults.standard
    private let oldType = "トレンド・エディター"
    private let savedKey = "renewalHome.savedResponse"

    /// 前のアカウントのキャラと 3案の控えが端末に残っている状態にする
    private func seedPreviousAccount(uid: String) {
        ud.set(uid, forKey: UserDefaultsKey.userId.rawValue)
        ud.set(false, forKey: OnboardingDebug.dryRunKey)
        ud.set(oldType, forKey: UserDefaultsKey.partnerImage.rawValue)
        ud.set("\(oldType)_icon", forKey: UserDefaultsKey.partnerIconImage.rawValue)
        ud.set(Data("old".utf8), forKey: savedKey)
        ud.removeObject(forKey: UserDefaultsKey.hasOnboarding.rawValue)
    }

    private func answerQuestions(_ vm: PartnerOnboardingFlowViewModel) {
        vm.impression = "soft"; vm.priority = "F"; vm.rangeVal = "C"; vm.tone = "gentle"   // → エッセンシャル・ワーカー
    }

    private func observeDidChange() -> (Flag, NSObjectProtocol) {
        let flag = Flag()
        let token = NotificationCenter.default.addObserver(forName: PartnerLocalMirror.didChange, object: nil, queue: nil) { _ in flag.value = true }
        return (flag, token)
    }

    @Test("登録: 登録用の API を呼び、前のアカウントの控えを消して新しい相棒を写す")
    func registrationClearsPreviousAndMirrorsNew() async {
        seedPreviousAccount(uid: "uid-reg")
        let client = RecordingPartnerClient()
        let vm = PartnerOnboardingFlowViewModel(partnerClient: client)
        answerQuestions(vm)
        let (changed, token) = observeDidChange()
        defer { NotificationCenter.default.removeObserver(token) }

        await vm.submitOnboarding(mode: .registration)

        #expect(client.saveCalls == 1 && client.updateCalls == 0)
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == "エッセンシャル・ワーカー")
        #expect(ud.string(forKey: UserDefaultsKey.partnerIconImage.rawValue) == "エッセンシャル・ワーカー_icon")
        #expect(ud.object(forKey: savedKey) == nil)                       // 前の 3案の控えは消える
        #expect(ud.string(forKey: UserDefaultsKey.userId.rawValue) == "uid-reg")   // アカウントは残る
        #expect(ud.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))
        #expect(changed.value)
        if case .birth = vm.step {} else { Issue.record("誕生の画面に進んでいない") }
    }

    @Test("更新: 更新用の API を呼び、控えは消さずに新しい相棒を写す")
    func updateKeepsCachesAndMirrorsNew() async {
        seedPreviousAccount(uid: "uid-upd")
        let client = RecordingPartnerClient()
        let vm = PartnerOnboardingFlowViewModel(partnerClient: client)
        answerQuestions(vm)
        let (changed, token) = observeDidChange()
        defer { NotificationCenter.default.removeObserver(token) }

        await vm.submitOnboarding(mode: .update)

        #expect(client.updateCalls == 1 && client.saveCalls == 0)
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == "エッセンシャル・ワーカー")
        #expect(ud.object(forKey: savedKey) != nil)                       // 控えは消さない (取り直しで差し替える)
        #expect(changed.value)                                             // ホームに取り直しを知らせる
    }

    @Test("保存に失敗: 仮の相棒で進まず、端末の相棒も変えず、確認画面に戻して知らせる")
    func failureDoesNotMirrorMock() async {
        seedPreviousAccount(uid: "uid-fail")
        let client = RecordingPartnerClient()
        client.fail = true
        let vm = PartnerOnboardingFlowViewModel(partnerClient: client)
        answerQuestions(vm)
        let (changed, token) = observeDidChange()
        defer { NotificationCenter.default.removeObserver(token) }

        await vm.submitOnboarding(mode: .registration)

        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == oldType)
        #expect(!ud.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))
        #expect(ud.object(forKey: savedKey) != nil)
        #expect(vm.saveErrorMessage != nil)
        #expect(!changed.value)
        if case .confirm = vm.step {} else { Issue.record("確認の画面に戻っていない") }
    }

    @Test("dry-run の既定はオフ (何も設定していなければ答えをサーバに保存する)")
    func dryRunDefaultsOff() {
        ud.removeObject(forKey: OnboardingDebug.dryRunKey)
        #expect(OnboardingDebug.dryRun == false)
    }

    @Test("ホーム: 通信失敗時の仮のデータは写さない。本物のデータは写し、誕生済みの印もそろえる")
    func homeMirrorsOnlyRealResponse() async {
        seedPreviousAccount(uid: "uid-home")
        let client = RecordingPartnerClient()
        let vm = HomeViewModel(partnerClient: client)

        client.home = .mock()   // user_id = "mock-user" (FallbackPartnerClient が失敗時に返すもの)
        await vm.loadPartnerHomeSection(uid: "uid-home")
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == oldType)
        #expect(!ud.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))

        client.home = PartnerHomeResponse(status: "success", user_id: "uid-home", greeting: "", sub_greeting: nil,
                                          state: .mock(), type_name: "モテ・プランナー", has_completed_onboarding: true)
        await vm.loadPartnerHomeSection(uid: "uid-home")
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == "モテ・プランナー")
        #expect(ud.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))
    }
}
