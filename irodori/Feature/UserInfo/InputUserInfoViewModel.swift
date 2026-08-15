//
//  InputUserInfoViewModel.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import SwiftUI
import FirebaseAuth

@Observable
@MainActor
final class InputUserInfoViewModel {
    var username: String = ""
    var selectedGender: Gender = .male
    var birthYearText: String = ""
    var birthMonthText: String = ""
    var birthDayText: String = ""
    var selectedPrefectureCode: String = Prefecture.default.code

    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedPrefectureName: String {
        Prefecture.find(byCode: selectedPrefectureCode)?.name ?? Prefecture.default.name
    }

    var isBirthdayComplete: Bool {
        guard let year = Int(birthYearText), let month = Int(birthMonthText), let day = Int(birthDayText) else { return false }
        return (1926...2030).contains(year) && (1...12).contains(month) && (1...31).contains(day)
    }

    private let userDefaults = UserDefaults.standard
    private let prefectureClient: UpdateUserPrefectureClientProtocol

    init(prefectureClient: UpdateUserPrefectureClientProtocol = UpdateUserPrefectureClient()) {
        self.prefectureClient = prefectureClient
    }

    func okButtonTapped() async {
        let firebaseUID = Auth.auth().currentUser?.uid
        if firebaseUID == nil {
            // 認証必須化後は到達しない想定。発生したら計測で検知する
            AnalyticsLogger.shared.log(error: .userIdFallback, parameters: ["context": "input_user_info"])
        }
        // 既に userId がある場合は上書きしない (userId 不変の不変条件)。
        // 機種変更復元 (紐付け表から旧UUIDを復元済み) でプロフィール再入力に来たとき、
        // Firebase UID で上書きすると旧データに到達できなくなるため
        let existingUserId = userDefaults.string(forKey: UserDefaultsKey.userId.rawValue)
        let uid = existingUserId ?? firebaseUID ?? UUID().uuidString
        userDefaults.set(uid, forKey: UserDefaultsKey.userId.rawValue)

        // 居住地を UD に先行保存し、サーバへ送信 (失敗してもオンボーディングは進める)
        userDefaults.set(selectedPrefectureCode, forKey: UserDefaultsKey.prefectureCode.rawValue)
        _ = try? await prefectureClient.put(uid: uid, prefectureCode: selectedPrefectureCode)

        let year = Int(birthYearText) ?? 0
        let month = Int(birthMonthText) ?? 0
        let day = Int(birthDayText) ?? 0

        let user = User(username: username, birthday: BirthDay(year: birthYearText, month: birthMonthText, day: birthDayText), gender: selectedGender)
        // API の成否に関わらずローカルに先行保存する
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: UserDefaultsKey.userInfo.rawValue)
            userDefaults.set(selectedGender.apiValue, forKey: UserDefaultsKey.gender.rawValue)
            userDefaults.set(true, forKey: UserDefaultsKey.hasCompletedUserInfo.rawValue)
        }

        // 生年月日をUserDefaultsに保存（入力済みの場合）
        if isBirthdayComplete {
            userDefaults.set(year, forKey: UserDefaultsKey.birthYear.rawValue)
            userDefaults.set(month, forKey: UserDefaultsKey.birthMonth.rawValue)
            userDefaults.set(day, forKey: UserDefaultsKey.birthDay.rawValue)
        }

        // 生年月日が入力済みの場合、動物占いAPIを呼び出す
        if isBirthdayComplete {
            await callAnimalFortune(userId: uid, year: year, month: month, day: day)
        }
    }

    private func callAnimalFortune(userId: String, year: Int, month: Int, day: Int) async {
        struct AnimalFortuneReq: Encodable {
            let user_id: String
            let year: Int
            let month: Int
            let day: Int
        }
        guard let url = URL(string: "https://irodori-api.onrender.com/api/animal-fortune") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(AnimalFortuneReq(user_id: userId, year: year, month: month, day: day))
        _ = try? await URLSession.shared.data(for: req)
    }
}
