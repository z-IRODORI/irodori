# Firebase Storage セットアップ手順

coordinate-recommend APIから取得した画像パスをFirebase Storageから取得して表示するための実装が完了しました。

## 実装内容

### 1. FirebaseStorageClient.swift
Firebase Storageから画像URLを取得するクライアント
- `getDownloadURL(for path: String)`: 画像パスからダウンロードURLを取得
- `MockFirebaseStorageClient`: テスト用モッククライアント

### 2. FirebaseStorageImage.swift
Firebase Storageから画像を取得して表示するSwiftUIコンポーネント
- パスを指定すると自動的にFirebase StorageからURLを取得
- AsyncImageで画像を表示
- ローディング表示とエラーハンドリング

### 3. CoordinateRecommendResponse.swift
- `imageURLs` → `imagePaths` に変更
- APIから受け取った画像パス（例: `items/ワイドパンツ/00.png`）をそのまま保持

## セットアップ手順

### 1. Firebase Storage パッケージの追加

Xcodeで以下の手順を実行：

1. プロジェクトを開く
2. File > Add Package Dependencies...
3. 以下のURLを入力: `https://github.com/firebase/firebase-ios-sdk`
4. **FirebaseStorage** パッケージを選択して追加

### 2. Xcodeプロジェクトにファイルを追加

以下のファイルをXcodeプロジェクトに追加：

- `FirebaseStorageClient.swift`
- `FirebaseStorageImage.swift`
- `ItemCategory.swift`
- `CoordinateRecommendRequest.swift`
- `CoordinateRecommendResponse.swift`
- `CoordinateRecommendClient.swift`

### 3. Firebase Storageの設定

Firebase Consoleで以下を設定：

1. Firebase Console (https://console.firebase.google.com/) にアクセス
2. プロジェクトを選択
3. Storage > Get started をクリック
4. セキュリティルールを設定（例）:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /items/{allPaths=**} {
      allow read: if true;  // 読み取りは誰でも可能
      allow write: if request.auth != null;  // 書き込みは認証済みユーザーのみ
    }
  }
}
```

### 4. 画像のアップロード

Firebase Storageに画像をアップロード：

```
items/
├── ワイドパンツ/
│   ├── 00.png
│   ├── 01.png
│   └── ...
├── サンダル/
│   ├── 00.png
│   ├── 01.png
│   └── ...
└── ...
```

## 使用方法

### モック環境での動作確認

現在、`MockFirebaseStorageClient`を使用しているため、Firebase Storageの設定なしでも動作確認が可能です。
プレースホルダー画像（Lorem Picsum）が表示されます。

### 本番環境への切り替え

`FirebaseStorageImage.swift` の初期化を以下のように変更：

```swift
// 現在（モック）
FirebaseStorageImage(path: path)

// 本番環境
FirebaseStorageImage(path: path, storageClient: FirebaseStorageClient())
```

または、環境に応じて自動切り替え：

```swift
init(path: String) {
    self.path = path
    #if DEBUG
    self.storageClient = MockFirebaseStorageClient()
    #else
    self.storageClient = FirebaseStorageClient()
    #endif
}
```

## データフロー

1. ユーザーが「コーデを追加」ボタンをタップ
2. `coordinate-recommend` APIを呼び出し
3. レスポンスから画像パスを取得（例: `items/ワイドパンツ/00.png`）
4. `FirebaseStorageImage` コンポーネントが画像パスを受け取る
5. `FirebaseStorageClient` がFirebase StorageからダウンロードURLを取得
6. `AsyncImage` でダウンロードURLから画像を表示

## トラブルシューティング

### エラー: "No such module 'FirebaseStorage'"
→ Firebase Storage パッケージを追加してください（セットアップ手順1）

### 画像が表示されない
→ Firebase Storageに画像がアップロードされているか確認
→ セキュリティルールが正しく設定されているか確認
→ 画像パスが正しいか確認

### ビルドエラー
→ 新しく作成したファイルがXcodeプロジェクトに追加されているか確認
