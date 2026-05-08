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

    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isBirthdayComplete: Bool {
        guard let year = Int(birthYearText), let month = Int(birthMonthText), let day = Int(birthDayText) else { return false }
        return (1926...2030).contains(year) && (1...12).contains(month) && (1...31).contains(day)
    }

    private let userDefaults = UserDefaults.standard

    func okButtonTapped() async {
        let createUserClient: CreateUserClient = CreateUserClient()
        let uid = Auth.auth().currentUser?.uid ?? UUID().uuidString
        userDefaults.set(uid, forKey: UserDefaultsKey.userId.rawValue)

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

        do {
            let _ = try await createUserClient.post(createUserRequest: .init(id: uid, cognito_id: uid, user_name: username, year: year, month: month, day: day, gender: selectedGender.number))
        } catch {}

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
