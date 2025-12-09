## セットアップ

### 環境変数の設定

`.env`ファイルに以下を設定:

```env
DATABASE_URL=cockroachdb://...
SECRET_KEY=your-secret-key
R2_ACCESS_KEY_ID=your-r2-access-key-id
R2_SECRET_ACCESS_KEY=your-r2-secret-access-key
R2_BUCKET_NAME=numyp
R2_ENDPOINT_URL=https://629fe30a093677c64b0a0705ff4d90ce.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://s3.korucha.com
```

### SECRET_KEYの生成

.envのSECRET_KEYはJWTの署名用秘密鍵です

```bash
# Python標準ライブラリを使用
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

もしくは

```bash
# OpenSSLを使用（インストールされている場合）
openssl rand -hex 32
```

で発行できます。

### 依存パッケージのインストール

```bash
pip install -r requirements.txt
```

### R2接続のテスト

```bash
python test_r2.py
```

## Cloudflare R2 画像アップロード機能

### APIエンドポイント

#### 1. 汎用画像アップロード
```http
POST /upload/image
Authorization: Bearer <token>
Content-Type: multipart/form-data

file: (画像ファイル)
folder: (オプション) R2内のフォルダ名
```

**レスポンス:**
```json
{
  "success": true,
  "image_url": "https://s3.korucha.com/images/xxx.jpg",
  "filename": "image.jpg",
  "content_type": "image/jpeg",
  "size": 12345
}
```

#### 2. スポット投稿（画像含む）
```http
POST /spots
Authorization: Bearer <token>
Content-Type: application/json

{
  "lat": 35.6812,
  "lng": 139.7671,
  "title": "渋谷スクランブル交差点",
  "description": "賑やかな場所です",
  "image_base64": "data:image/jpeg;base64,/9j/4AAQ...",
  "crowd_level": "high",
  "rating": 4
}
```

**画像形式:** Base64エンコードされた画像データ
**対応形式:** JPEG, PNG, WebP, GIF
**サイズ制限:** 10MB

#### 3. ユーザーアイコン更新
```http
POST /users/me/icon
Authorization: Bearer <token>
Content-Type: multipart/form-data

file: (アイコン画像ファイル)
```

**対応形式:** JPEG, PNG, WebP
**サイズ制限:** 5MB

### 画像の表示

アップロードされた画像は以下のURLで公開アクセス可能:
```
https://s3.korucha.com/spots/xxx.jpg
https://s3.korucha.com/user_icons/xxx.jpg
https://s3.korucha.com/images/xxx.jpg
```

### R2ストレージの構造

```
numyp (bucket)
├── spots/          # スポット投稿画像
├── user_icons/     # ユーザーアイコン
├── images/         # その他の画像
└── test/           # テスト用
```