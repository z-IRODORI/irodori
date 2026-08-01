//
//  UserDefaultsKey.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import Foundation

enum UserDefaultsKey: String {
    case hasAgreedToTermsOfService
    case userId
    case gender
    case userInfo
    case profileInfo
    case hasCompletedUserInfo
    case signUpDate
    case hasOnboarding
    case hasFashionTypeDiagnosis
    case coordinateChats
    case finishedFirstTakePhoto
    case lastDismissedFirstTakePhotoDate
    case homePlannerCache
    case partnerImage
    case partnerIconImage
    case hasSelectedStandardItems
    case generalChatConversationId
    case birthYear
    case birthMonth
    case birthDay
    case prefectureCode
    case prefectureLastChangedAt
    case additionalPrefectureCodes
    case outfitWithWhoHistory
    case outfitWhereHistory
    /// 「これにする」決定の記録 (対象日 yyyy-MM-dd → pool_id の辞書。翌朝は日付が変わり自然リセット)
    case dailyDecisionRecord
    /// 朝いち演出を再生した JST 日付 (1日1回だけ再生)
    case dailyRitualPlayedDate
    /// 通知許可の文脈付きプリプロンプトを表示済みか (見送り画面で1回だけ出す)
    case notificationPromptShown
}
