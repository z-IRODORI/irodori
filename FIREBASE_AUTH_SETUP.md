# Firebase Authentication セットアップ手順

Firebase Storage の画像にアクセスするために、匿名認証を使用します。
ユーザーはメールアドレスやパスワードなど、何の情報も入力する必要がありません。

## 実装内容

### 1. AuthManager.swift（新規作成）
認証状態を管理するシングルトンクラス
- `isAuthenticated`: 認証状態を監視
- `currentUserID`: 現在のユーザーID
- `signInAnonymously()`: 匿名ログインを実行
- `signOut()`: ログアウト
- 認証状態の変更を自動的に監視

### 2. AppDelegate.swift（更新）
アプリ起動時に自動的に匿名ログインを実行
- `AuthManager.shared.signInAnonymously()` を使用
- 既にログイン済みの場合はスキップ
- エラーが発生してもアプリは継続

### 3. FirebaseStorageImage.swift（更新）
認証チェックとリトライ機能を追加
- 認証が完了するまで最大3回リトライ（各0.5秒待機）
- 認証されていない場合でも画像読み込みを試行
- エラー時にわかりやすいプレースホルダーを表示

### 4. irodoriApp.swift（更新）
AuthManagerをEnvironmentに追加
- `environment(AuthManager.shared)` で全画面からアクセス可能

## Firebase Console での設定

### 1. Authentication を有効化

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクト「irodori-e5c71」を選択
3. 左メニューから **Authentication** を選択
4. **始める** ボタンをクリック

### 2. 匿名認証を有効化

1. **Sign-in method** タブをクリック
2. 「匿名」の行を探してクリック
3. **有効にする** トグルをONにする
4. **保存** ボタンをクリック

### 3. Storage Rules を更新

1. 左メニューから **Storage** を選択
2. **Rules** タブをクリック
3. 以下のルールに変更:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // items フォルダ: 認証済みユーザーのみ読み取り可能、書き込みは禁止
    match /items/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // coordinates フォルダ: 認証済みユーザーのみ読み取り可能、書き込みは禁止
    match /coordinates/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // その他のファイル: 認証済みユーザーのみアクセス可能
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

4. **公開** ボタンをクリックして保存

## 動作確認

### 1. アプリをビルド・実行

### 2. Xcodeのコンソールで確認

以下のようなログが表示されれば成功:

```
Firebase Auth: 匿名ログイン成功 (UID: AbCdEf123456...)
```

または既にログイン済みの場合:

```
Firebase Auth: 既にログイン済み (UID: AbCdEf123456...)
```

### 3. 画像が表示されることを確認

「コーデを追加」ボタンをタップして、Firebase Storage から画像が正常に表示されることを確認してください。

## セキュリティについて

### 匿名認証の特徴

**メリット:**
- ユーザー登録不要
- メールアドレスやパスワード不要
- 自動的に認証される

**セキュリティ:**
- 認証済みユーザー（匿名含む）のみが Storage にアクセス可能
- 書き込みは完全に禁止（`allow write: if false`）
- 認証トークンがないと画像にアクセスできない

### 匿名ユーザーの永続性

- 匿名ユーザーIDはデバイスに保存されます
- アプリを削除するまで同じUIDが使用されます
- アプリを再インストールすると新しいUIDが発行されます

## トラブルシューティング

### エラー: "Permission denied (403)"

**原因:**
- Storage Rules が更新されていない
- Authentication が有効化されていない
- 匿名認証が有効化されていない

**解決方法:**
1. Firebase Console で Authentication > Sign-in method を確認
2. 「匿名」が有効になっているか確認
3. Storage Rules が正しく設定されているか確認

### エラー: "Failed to sign in anonymously"

**原因:**
- ネットワークエラー
- Firebase の設定ミス

**解決方法:**
1. インターネット接続を確認
2. `GoogleService-Info.plist` が正しく配置されているか確認
3. Firebase Console でプロジェクトが正しく設定されているか確認

### アプリ起動時にログインが遅い

**説明:**
匿名ログインは非同期で実行されるため、アプリ起動直後は認証が完了していない場合があります。
通常、1-2秒で完了します。

**対策（必要に応じて）:**
ログイン完了を待つ必要がある場合は、以下のように実装できます:

```swift
// 例: ViewModelで認証完了を待つ
@Published var isAuthenticated = false

init() {
    Auth.auth().addStateDidChangeListener { auth, user in
        self.isAuthenticated = (user != nil)
    }
}
```

## まとめ

1. ✅ `AppDelegate.swift` に匿名認証のコードを追加（実装済み）
2. ⬜ Firebase Console で匿名認証を有効化
3. ⬜ Storage Rules を更新
4. ⬜ アプリをビルドして動作確認

上記の手順を完了すれば、403エラーが解消され、画像が表示されます。
