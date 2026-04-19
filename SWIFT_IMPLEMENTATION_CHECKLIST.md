# Swift実装チェックリスト

Firebase匿名認証とFirebase Storageの画像表示機能の実装が完了しました。

## 実装済みファイル

### 新規作成
✅ `Core/Auth/AuthManager.swift` - 認証状態管理

### 更新済み
✅ `AppDelegate.swift` - 匿名認証の実行
✅ `Core/Component/FirebaseStorageImage.swift` - 認証チェックとリトライ
✅ `irodoriApp.swift` - AuthManagerのEnvironment追加

## Xcodeでの作業（必須）

### 1. 新規ファイルをプロジェクトに追加

以下のファイルをXcodeプロジェクトに追加してください:

**認証関連:**
- ✅ `irodori/Core/Auth/AuthManager.swift`

**Firebase Storage関連（既存）:**
- ✅ `irodori/Data/FirebaseStorage/FirebaseStorageClient.swift`
- ✅ `irodori/Core/Component/FirebaseStorageImage.swift`

**coordinate-recommend API関連（既存）:**
- ✅ `irodori/Entity/ItemCategory.swift`
- ✅ `irodori/Data/APIClient/Request/CoordinateRecommendRequest.swift`
- ✅ `irodori/Data/APIClient/Response/CoordinateRecommendResponse.swift`
- ✅ `irodori/Data/APIClient/CoordinateRecommendClient.swift`

**追加方法:**
1. Xcodeの左側ナビゲーターで適切なフォルダを右クリック
2. "Add Files to irodori..." を選択
3. ファイルを選択して追加
4. "Copy items if needed" にチェックを入れる

### 2. Firebase SDKの確認

以下のパッケージが追加されているか確認:
- ✅ FirebaseCore（インストール済み）
- ✅ FirebaseStorage（インストール済み）
- ⬜ **FirebaseAuth**（要追加）

**FirebaseAuthの追加方法:**
1. Xcode > File > Add Package Dependencies
2. 既にfirebase-ios-sdkが追加されている場合は、パッケージを選択
3. Target > irodori > Frameworks > + ボタン
4. **FirebaseAuth** を選択して追加

または、新規追加する場合:
1. URL: `https://github.com/firebase/firebase-ios-sdk`
2. **FirebaseAuth** パッケージを選択

### 3. ビルドエラーの解消

以下のエラーが出る場合の対処:

**"No such module 'FirebaseAuth'"**
→ FirebaseAuthパッケージを追加（上記参照）

**"Cannot find 'AuthManager' in scope"**
→ AuthManager.swiftをプロジェクトに追加

## Firebase Consoleでの作業（必須）

### 1. Authentication を有効化

1. [Firebase Console](https://console.firebase.google.com/)
2. プロジェクト「irodori-e5c71」を選択
3. Authentication > 始める

### 2. 匿名認証を有効化

1. Sign-in method タブ
2. 「匿名」をクリック
3. 有効にする → 保存

### 3. Storage Rules を更新

Storage > Rules タブ:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /items/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /coordinates/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

公開ボタンをクリック

## 動作確認

### 1. アプリをビルド・実行

### 2. Xcodeコンソールで確認

以下のログが表示されることを確認:

```
AppDelegate: 既にログイン済み
または
AuthManager: 匿名ログイン成功 (UID: ...)
```

### 3. 画像表示の確認

1. ホーム画面を開く
2. 「コーデを追加」ボタンをタップ
3. 2x2グリッドで画像が表示されることを確認

## トラブルシューティング

### ビルドエラー: "No such module"

**原因:** パッケージが追加されていない、またはファイルがプロジェクトに追加されていない

**解決:**
1. Package Dependencies を確認
2. 新規作成したファイルがXcodeプロジェクトに追加されているか確認

### 403エラーが続く

**原因:** 認証が完了していない、またはStorage Rulesが更新されていない

**解決:**
1. Xcodeコンソールで「匿名ログイン成功」が表示されているか確認
2. Firebase Console で Authentication > Users にユーザーが表示されているか確認
3. Storage Rules が正しく設定されているか確認

### 画像が表示されない

**原因:** Firebase Storageに画像がアップロードされていない

**解決:**
1. Firebase Console > Storage を開く
2. `items/` フォルダを確認
3. 画像がアップロードされているか確認

## 完了チェック

- [ ] AuthManager.swift をXcodeプロジェクトに追加
- [ ] FirebaseAuth パッケージを追加
- [ ] プロジェクトがビルド成功
- [ ] Firebase Console で匿名認証を有効化
- [ ] Storage Rules を更新
- [ ] アプリ起動時に認証ログが表示される
- [ ] 「コーデを追加」で画像が表示される

すべて完了したら、403エラーが解消され、Firebase Storageから画像が正常に表示されます。
