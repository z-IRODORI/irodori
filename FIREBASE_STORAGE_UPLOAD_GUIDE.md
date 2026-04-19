# Firebase Storage 画像アップロード手順

現在、Firebase Storageに画像がアップロードされていないため、エラーが発生しています。

## エラーの原因

```
Firebase Storage error for path items/ボトムス_ワイドパンツ_ブラック/00.png: Object
```

このエラーは、指定されたパスに画像ファイルが存在しないことを示しています。

## 解決方法: Firebase Consoleで画像をアップロード

### 方法1: Firebase Consoleから手動でアップロード

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクト「**irodori-e5c71**」を選択
3. 左メニューから **Storage** を選択
4. **Files** タブを開く

5. フォルダ構造を作成:
   ```
   items/
   ├── ボトムス_ワイドパンツ_ブラック/
   │   ├── 00.png
   │   ├── 01.png
   │   └── ...
   ├── シューズ_サンダル_ブラック/
   │   ├── 00.png
   │   └── ...
   └── アクセサリー_ネックレス_ゴールド/
       ├── 00.png
       └── ...
   ```

6. 画像をアップロード:
   - 「Upload file」または「Upload folder」ボタンをクリック
   - 画像ファイルを選択してアップロード

### 方法2: gsutil コマンドラインツールを使用（一括アップロード）

#### 1. Google Cloud SDKをインストール

```bash
# macOS
brew install --cask google-cloud-sdk

# または公式インストーラー
https://cloud.google.com/sdk/docs/install
```

#### 2. 認証

```bash
gcloud auth login
gcloud config set project irodori-e5c71
```

#### 3. 画像を一括アップロード

ローカルに画像フォルダがある場合:

```bash
# items フォルダ全体をアップロード
gsutil -m cp -r ./items gs://irodori-e5c71.firebasestorage.app/items

# 特定のフォルダのみアップロード
gsutil -m cp -r ./items/ボトムス_ワイドパンツ_ブラック gs://irodori-e5c71.firebasestorage.app/items/ボトムス_ワイドパンツ_ブラック
```

### 方法3: Firebase Admin SDK（サーバー側から自動アップロード）

Node.js などのサーバー側で画像を生成してアップロードする場合:

```javascript
const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp();
const bucket = admin.storage().bucket();

async function uploadImage(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: {
      contentType: 'image/png',
    },
  });
  console.log(`Uploaded: ${storagePath}`);
}

// 例: ローカルの画像をアップロード
uploadImage(
  './local-images/wide-pants-00.png',
  'items/ボトムス_ワイドパンツ_ブラック/00.png'
);
```

## 必要な画像（APIレスポンスから）

以下の画像をアップロードする必要があります:

### アウター
- `items/アウター_ミリタリーコート_カーキ/00.png` ~ 09.png

### ボトムス
- `items/ボトムス_ワイドパンツ_ブラック/00.png` ~ 09.png
- `items/ボトムス_ジーンズ_ブルー/00.png` ~ 09.png

### シューズ
- `items/シューズ_サンダル_ブラック/00.png` ~ 09.png
- `items/シューズ_厚底シューズ_ブラック/00.png` ~ 09.png
- `items/シューズ_サンダル_ホワイト/00.png` ~ 09.png

### アクセサリー
- `items/アクセサリー_ネックレス_ゴールド/00.png` ~ 09.png
- `items/アクセサリー_サングラス_ベージュ/00.png` ~ 09.png
- `items/アクセサリー_ハンドバッグ_ブラウン/00.png` ~ 09.png

### コーディネート全体画像
- `coordinates/google/071248eb61c5083d4537f4e973652b0d.png`
- `coordinates/google/146099eb0a01e021db9853286b9e5825.png`
- `coordinates/google/14bccd39640e64629b4d9bf32d20874a.png`

## 画像の準備方法

### オプション1: テスト用のプレースホルダー画像を作成

Pythonスクリプトで簡単に作成できます:

```python
from PIL import Image, ImageDraw, ImageFont
import os

def create_placeholder(text, filename, size=(400, 400)):
    # 画像を作成
    img = Image.new('RGB', size, color='#f0f0f0')
    draw = ImageDraw.Draw(img)

    # テキストを中央に配置
    text_bbox = draw.textbbox((0, 0), text)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    position = ((size[0] - text_width) / 2, (size[1] - text_height) / 2)

    draw.text(position, text, fill='#666666')

    # 保存
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    img.save(filename)
    print(f"Created: {filename}")

# 例: ワイドパンツの画像を作成
for i in range(10):
    create_placeholder(
        f"ワイドパンツ\n{i:02d}",
        f"items/ボトムス_ワイドパンツ_ブラック/{i:02d}.png"
    )
```

### オプション2: 実際の商品画像を使用

coordinate-recommend APIから返される画像パスに対応する実際の商品画像を用意します。

## アップロード後の確認

1. Firebase Console > Storage で画像が表示されることを確認
2. アプリを再起動
3. 「コーデを追加」ボタンをタップ
4. 画像が表示されることを確認

## トラブルシューティング

### アップロードしたのにエラーが出る

**確認事項:**
- パスが完全に一致しているか（大文字小文字、スペース、アンダースコアなど）
- ファイル名が正しいか（00.png, 01.png など）
- Storage Rules で読み取りが許可されているか

### 一部の画像だけ表示されない

**原因:**
- その画像ファイルがアップロードされていない
- ファイル名やパスが間違っている

**解決:**
詳細なエラーログを確認して、どのパスの画像が見つからないか特定してください。

## まとめ

1. Firebase Console > Storage を開く
2. 必要な画像をアップロード（手動 or gsutil）
3. パスとファイル名が API レスポンスと一致していることを確認
4. アプリを再起動して動作確認
