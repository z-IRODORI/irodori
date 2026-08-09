# Firebase 電話番号認証 (Phone Auth) セットアップガイド

IRODORI の会員登録・ログインは **電話番号 (SMS認証) のみ** です。
このドキュメントは、実装の全体像と、Firebase / Apple Developer コンソールで必要な手作業をまとめたものです。

- Firebase プロジェクト: `irodori-e5c71`
- Bundle ID: `com.gmail.yuukirinnma.irodori`
- Apple Developer Team ID: `BR3T8YBB5L`

---

## 1. 実装概要 (コード側・対応済み)

| 役割 | ファイル |
|---|---|
| 認証マネージャ (送信/サインイン/ログアウト) | `irodori/Core/Auth/AuthManager.swift` |
| 電話番号入力 + SMS 6桁コード入力 UI | `irodori/Feature/Auth/PhoneAuthView.swift` |
| 認証の状態管理 (整形・再送60秒・エラー日本語化) | `irodori/Feature/Auth/PhoneAuthViewModel.swift` |
| ログイン入口 | `irodori/Feature/Auth/LoginView.swift` |
| 起動時の認証ゲート (**全ユーザー必須**) | `irodori/Feature/Splash/SplashViewModel.swift` |
| ログアウト (確認アラート付き) | `irodori/Feature/Profile/ProfileEditView.swift` |
| APNs トークン連携 / reCAPTCHA リダイレクト | `irodori/AppDelegate.swift` |

### フロー

```
起動 → 利用規約 → [未サインインなら] ログイン画面
  → 電話番号入力 → SMS送信 → 6桁コード検証 → サインイン完了
  → (新規のみ) ユーザー情報入力 → オンボーディング → ホーム
```

- 既存ユーザー (userInfo 保持者) はサインイン後、ユーザー情報入力をスキップしてホームへ直行。
  **UserDefaults の `userId` は変更しない**ため、既存データ (クローゼット・コーデ等) はそのまま。
- ログアウトは Firebase のサインアウトのみで、UserDefaults は消さない。
  同じ電話番号で再ログインすれば同じ Firebase UID に戻り、データも引き継がれる。

### アプリ検証の経路 (SMS を送ってよい正規アプリかの確認)

1. **実機**: APNs サイレントプッシュ (無音・通知許可不要) — 下記 §3 の設定が完了していれば reCAPTCHA は出ない
2. **シミュレータ / APNs 未設定**: reCAPTCHA (SFSafariViewController) に自動フォールバック。
   Info.plist の URL scheme `app-1-816472842049-ios-85f57fcd9a9019d8a04bc0` (Encoded App ID) で復帰する

> ⚠️ `Auth.auth().settings.isAppVerificationDisabledForTesting = true` は使わないこと。
> このフラグは Firebase Console に**事前登録したテスト番号でしか動かず**、
> 未登録番号では `ERROR_MISSING_CLIENT_IDENTIFIER` で必ず失敗する (NoMuu で踏んだ罠)。

---

## 2. Firebase Console — Phone プロバイダ (必須・初回のみ)

1. [Firebase Console](https://console.firebase.google.com/) → `irodori-e5c71` → **Authentication → Sign-in method**
2. 「電話番号」プロバイダを **有効化**
3. 同ページ下部「**テスト用の電話番号**」に検証用の架空番号を登録する (シミュレータ検証・App Store 審査用):
   - 例: 電話番号 `+81 90 0000 0001` / 確認コード `123456`
   - テスト番号には実SMSは送信されず、登録したコードで常にサインインできる

---

## 3. APNs サイレント検証の有効化 (実機で reCAPTCHA を出さないために必要)

> 🔥 **NoMuu 本番障害の教訓**: この登録を忘れると、コード側が完璧でもサイレント検証は永遠に効かず、
> 全ユーザーに毎回 reCAPTCHA の Web 画面が表示され続ける。

### 3-1. Apple Developer — APNs 認証キー (.p8)

1. [Apple Developer](https://developer.apple.com/account/) → **Certificates, Identifiers & Profiles → Keys**
2. 既存の APNs キーがあればそれを使う (**NoMuu で作成したチーム共通キーを流用可** — APNs キーはチーム内全アプリで共有される)
3. 無ければ「+」→ 名前入力 → **Apple Push Notifications service (APNs)** にチェック → 作成 → `.p8` をダウンロード
   (ダウンロードは1回きり。**Key ID** を控える)

### 3-2. Firebase Console — キーのアップロード

1. `irodori-e5c71` → ⚙️ **プロジェクトの設定 → Cloud Messaging** タブ
2. 「Apple アプリの構成」→ iOS アプリ (`com.gmail.yuukirinnma.irodori`) の **APNs 認証キー** にアップロード
3. `.p8` ファイル + **Key ID** + **Team ID (`BR3T8YBB5L`)** を入力して保存

### 3-3. Xcode 側 (対応済み・確認のみ)

- `irodori/irodori.entitlements`: `aps-environment = development`
  (Archive → App Store 配布時は Xcode が自動で `production` に差し替える)
- `irodori/Info.plist`: `UIBackgroundModes = [remote-notification]`
- `AppDelegate`: 起動時に `registerForRemoteNotifications()` を無条件呼び出し (許可ダイアログは出ない) →
  `didRegisterForRemoteNotificationsWithDeviceToken` で `Auth.auth().setAPNSToken(_:type: .unknown)`
- Signing は Automatic のため、実機ビルド時に Xcode が App ID へ Push Notifications capability を自動追加する。
  初回実機ビルドで署名エラーが出た場合は Xcode → Signing & Capabilities で Team を選び直す

---

## 4. SMS の日本語化 (対応済み)

`AppDelegate` で `Auth.auth().languageCode = "ja"` を設定済み。
これが無いと認証SMSが英語文面で届く。

---

## 5. 動作確認

### シミュレータ

- APNs が使えないため reCAPTCHA 経路になる。**§2 のテスト番号を使うのが最速**
  (実番号を使うと reCAPTCHA → 実SMS 送信となり、クォータを消費する)
- 確認事項: 電話番号入力 → コード入力 → サインイン → ホーム到達

### 実機 (§3 完了後)

- 実番号で SMS 送信時に **reCAPTCHA が表示されない**こと
- SMS が**日本語**で届くこと
- Xcode コンソールに `🔴 [APNs] register failed` が出ないこと

### 回帰確認 (認証必須化まわり)

1. 新規: アプリ削除 → 起動 → 規約 → ログイン → 認証 → ユーザー情報入力 → ホーム
2. 既存ユーザー: ログアウト → ログイン画面に「認証が必要になりました」の文言 → 再認証 → ユーザー情報入力を**スキップして**ホーム
3. ログアウト前後で `userId` (UserDefaults) が変わらないこと

---

## 6. トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| 常に reCAPTCHA が出る (実機) | §3 の APNs キー未登録が最有力。次に entitlements / UIBackgroundModes の欠落、通知の Capability 不整合を確認 |
| `ERROR_MISSING_CLIENT_IDENTIFIER` (17993) | reCAPTCHA トークンも APNs も検証できていない。URL scheme (Encoded App ID) が Info.plist にあるか、GoogleService-Info.plist が最新か確認 |
| エラーコード 17999 / internal error | Firebase Console で Phone プロバイダが無効のまま、または App ID/APNs 設定の不整合 |
| SMS が英語で届く | `Auth.auth().languageCode = "ja"` が呼ばれていない (AppDelegate を確認) |
| `tooManyRequests` / `quotaExceeded` | 同一番号・同一IPへの送信超過。時間を置く。開発中はテスト番号を使う |
| コード入力後 `sessionExpired` | verificationID の期限切れ。再送信ボタンから新しいコードを取得 |
| シミュレータで reCAPTCHA 後に戻らない | URL scheme の欠落。Info.plist の `app-1-816472842049-ios-85f57fcd9a9019d8a04bc0` を確認 |

---

## 7. App Store 審査時の注意

- 審査員は日本のSMSを受信できないため、**App Review 情報に §2 のテスト番号と確認コードを記載**すること
  (例: 「Test phone number: +81 90 0000 0001 / Verification code: 123456」)
- アカウント作成があるため、Apple は原則アプリ内の**アカウント削除機能** (5.1.1(v)) を求める。
  現状は未実装 (今後の課題)。指摘された場合はサーバ側のデータ削除 API と合わせて対応する
