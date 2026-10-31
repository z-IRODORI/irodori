//
//  AccountResolver.swift
//  irodori
//
//  「誰のアカウントか」は電話番号 (Firebase Auth) だけで決める。
//  ログイン直後 (と、サインイン済みなのに端末の情報が足りないとき) に1回呼び、
//  サーバ (GET /api/user/account) から user_id・プロフィール・相棒の状態を受け取って端末に書く。
//
//  - 端末に別の人の user_id が残っていたら、端末のアカウント状態を消してから書く (人をまたいで混ざらない)
//  - サーバにプロフィールがあれば入力画面を出さない、相棒がいればオンボーディングを出さない
//    (別の端末・再インストールでも、同じ電話番号なら同じ続きから始まる)
//  - 通信できないときは、端末に user_id が無ければ Firebase uid を使う (従来どおり)
//

import FirebaseAuth
import Foundation

struct AccountResponse: Decodable {
    struct Profile: Decodable {
        let username: String?
        let gender: String?
        let birth_year: String?
        let birth_month: String?
        let birth_day: String?
    }
    let user_id: String
    let profile: Profile?
    let prefecture_code: String?
    let onboarding_completed: Bool
    let partner_type_name: String?
}

@MainActor
enum AccountResolver {
    private static var baseURL: String { PartnerProfileClient.defaultBaseURL }

    /// 結果: サーバから取れたか (false でも端末は使える状態にしてある)
    @discardableResult
    static func resolve() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        let defaults = UserDefaults.standard
        guard let token = try? await user.getIDToken(),
              let account = await fetch(token: token) else {
            // 通信できない: 端末に user_id が無ければ Firebase uid で始める (新世代と同じ)
            if (defaults.string(forKey: UserDefaultsKey.userId.rawValue) ?? "").isEmpty {
                defaults.set(user.uid, forKey: UserDefaultsKey.userId.rawValue)
            }
            return false
        }

        // 端末に別の人のアカウントが残っていたら消す (同じ端末を複数人で使ったとき)
        let local = defaults.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        if !local.isEmpty && local != account.user_id {
            AccountLocalState.resetForNewRegistration()
        }
        defaults.set(account.user_id, forKey: UserDefaultsKey.userId.rawValue)
        defaults.set(account.user_id, forKey: UserDefaultsKey.phoneLinkSyncedUserId.rawValue)

        // プロフィール: サーバにあれば端末へ (入力画面を出さない)
        if defaults.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil,
           let p = account.profile, let name = p.username, !name.isEmpty {
            let gender = Gender.fromWithDefault(p.gender)
            let user = User(username: name,
                            birthday: BirthDay(year: p.birth_year ?? "", month: p.birth_month ?? "", day: p.birth_day ?? ""),
                            gender: gender)
            if let data = try? JSONEncoder().encode(user) {
                defaults.set(data, forKey: UserDefaultsKey.userInfo.rawValue)
                defaults.set(gender.apiValue, forKey: UserDefaultsKey.gender.rawValue)
                defaults.set(true, forKey: UserDefaultsKey.hasCompletedUserInfo.rawValue)
            }
            if let y = Int(p.birth_year ?? ""), let m = Int(p.birth_month ?? ""), let d = Int(p.birth_day ?? "") {
                defaults.set(y, forKey: UserDefaultsKey.birthYear.rawValue)
                defaults.set(m, forKey: UserDefaultsKey.birthMonth.rawValue)
                defaults.set(d, forKey: UserDefaultsKey.birthDay.rawValue)
            }
        }
        if let code = account.prefecture_code, !code.isEmpty,
           defaults.string(forKey: UserDefaultsKey.prefectureCode.rawValue) == nil {
            defaults.set(code, forKey: UserDefaultsKey.prefectureCode.rawValue)
        }

        // 相棒: 誕生済みならオンボーディングを出さない
        if account.onboarding_completed {
            defaults.set(true, forKey: UserDefaultsKey.hasOnboarding.rawValue)
            defaults.set(true, forKey: UserDefaultsKey.hasPartnerOnboardingCompleted.rawValue)
            defaults.set(true, forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue)
            defaults.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
            if let type = account.partner_type_name, !type.isEmpty {
                defaults.set(type, forKey: UserDefaultsKey.partnerImage.rawValue)
                defaults.set("\(type)_icon", forKey: UserDefaultsKey.partnerIconImage.rawValue)
            }
        }
        return true
    }

    /// プロフィール入力のあとに呼ぶ (別の端末でログインしたとき入力し直さずに済むように)
    static func saveProfile(_ user: User) async {
        guard let firebaseUser = Auth.auth().currentUser,
              let token = try? await firebaseUser.getIDToken(),
              let url = URL(string: "\(baseURL)/api/user/account/profile") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let body: [String: String] = [
            "username": user.username,
            "gender": user.gender.apiValue,
            "birth_year": user.birthday.year,
            "birth_month": user.birthday.month,
            "birth_day": user.birthday.day,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    private static func fetch(token: String) async -> AccountResponse? {
        guard let url = URL(string: "\(baseURL)/api/user/account") else { return nil }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30   // Render のコールドスタートを考慮
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400 else { return nil }
        return try? JSONDecoder().decode(AccountResponse.self, from: data)
    }
}
