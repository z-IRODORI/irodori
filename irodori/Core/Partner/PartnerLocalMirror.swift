//
//  PartnerLocalMirror.swift
//  irodori
//
//  相棒のタイプの正はサーバ (partner_state)。端末の partnerImage / partnerIconImage はその写しで、
//  タブのアイコンなどをすぐ描くためだけに持つ。書き込むのは、サーバの答えを受け取ったときのここだけ。
//  (以前はオンボーディング・ログイン時の照合・ホーム・相棒画面がそれぞれ書いていて、
//   古いキャラで上書きされることがあった)
//

import UIKit

enum PartnerLocalMirror {
    /// 相棒が変わった (登録・更新) ことを知らせる。ホームは古い表示を残したまま取り直す
    static let didChange = Notification.Name("partner.didChange")

    /// サーバが返したタイプ名を写す。アプリに絵が無いタイプ名は写さない (別の既定キャラが出ないように)
    static func apply(typeName: String?) {
        guard let typeName, !typeName.isEmpty else { return }
        let defaults = UserDefaults.standard
        if UIImage(named: typeName) != nil {
            defaults.set(typeName, forKey: UserDefaultsKey.partnerImage.rawValue)
        }
        let iconName = "\(typeName)_icon"
        if UIImage(named: iconName) != nil {
            defaults.set(iconName, forKey: UserDefaultsKey.partnerIconImage.rawValue)
        }
    }

    /// サーバで相棒が生まれていると分かったとき (4つの質問をもう出さない)
    static func markOnboardingCompleted() {
        let defaults = UserDefaults.standard
        for key: UserDefaultsKey in [.hasOnboarding, .hasPartnerOnboardingCompleted, .hasFashionTypeDiagnosis, .hasSelectedStandardItems] {
            defaults.set(true, forKey: key.rawValue)
        }
    }
}
