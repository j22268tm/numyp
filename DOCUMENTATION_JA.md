# Numyp ドキュメント（現状まとめ）

本書はNumyp プロジェクトの仕様・機能を日本語で整理したものです。フロントエンド（Flutter）とバックエンド（FastAPI）の構成、主な画面や API、環境設定方法を簡潔に確認できます。

## 全体概要
- ロケーションベースのスポット投稿アプリ。マップ上にユーザーが投稿したスポットを表示し、詳細閲覧や編集ができる。
- Flutter 製モバイルアプリがフロントエンド。バックエンドは FastAPI + SQLAlchemy で JWT 認証と Cloudflare R2 ストレージ連携を提供する。

## フロントエンド（Flutter）
- `lib/main.dart` で `env.json` を読み込み、API ベース URL や Google Maps API キーを参照する。ユーザー未ログイン時は認証画面、ログイン済みなら地図画面を表示。【F:numyp/lib/main.dart†L9-L25】【F:numyp/lib/config/constants.dart†L4-L32】
- マップ画面（`MapScreen`）
  - Google Map 上に API 取得したスポットのマーカーを描画し、下部にプレビューカード、選択時に詳細カードを表示。【F:numyp/lib/screens/map/map_screen.dart†L23-L215】
  - 画面下部のタブで「map / spots / mypage」を切り替え。リフレッシュや現在地ボタン、テーマ切り替えトグル、所持コイン・アイコン表示を備える。【F:numyp/lib/screens/map/map_screen.dart†L39-L215】
- 認証・ユーザー状態
  - `auth_provider.dart` でサインアップ/ログインを管理。成功時に `/auth/login` から取得したトークンで `/users/me` を呼び出し、ユーザー情報とコイン残高・アイコン URL を保持する。【F:numyp/lib/providers/auth_provider.dart†L1-L78】【F:numyp/lib/services/api_client.dart†L34-L76】
- API クライアント
  - `ApiClient` で `/spots` の取得・投稿・更新・削除、`/auth` 系認証、`/users/me` 取得をカプセル化。必要に応じて Bearer トークンヘッダーを付与する。【F:numyp/lib/services/api_client.dart†L1-L94】

## バックエンド（FastAPI）
- エントリーポイント `backend/main.py`。CORS 設定・JWT トークン生成・R2 画像アップロードヘルパーを定義し、各種エンドポイントを提供する。【F:backend/main.py†L1-L111】【F:backend/main.py†L171-L352】
- 認証
  - `/auth/signup` でユーザー新規作成（重複名は 400）。`/auth/login` はフォームデータを受け取り、HS256 JWT を返却する。【F:backend/main.py†L113-L261】
- スポット
  - `/spots` GET で全スポット一覧（軽量: description 省略）。POST で新規作成（base64 画像があれば R2 に保存）、PUT/DELETE で作成者のみ更新・削除。【F:backend/main.py†L263-L362】
  - `/spots/{spot_id}` GET で詳細を返す。レスポンスは `schemas.SpotResponse` で位置・コンテンツ・混雑度・評価・投稿者・スキン情報を含む。【F:backend/main.py†L308-L332】【F:backend/schemas.py†L43-L79】
- 画像アップロード
  - `/upload/image` で認証済みユーザーが画像ファイルを R2 にアップロード（JPEG/PNG/WebP/GIF、10MB まで）。【F:backend/main.py†L285-L320】
  - `/users/me/icon` でユーザーアイコンをアップロード（JPEG/PNG/WebP、5MB まで）。【F:backend/main.py†L364-L424】
- ユーザー情報
  - `/users/me` で JWT に紐づくユーザーを返却。所持コインと現在のスキン情報も含む。【F:backend/main.py†L334-L362】【F:backend/schemas.py†L83-L101】
- ショップ
  - `/shop/buy` でスキン購入。残高不足、未存在、重複購入などのエラーを返却し、成功時に残コインを返す。【F:backend/main.py†L426-L479】
- AI（Ollama）
  - `/ai/quest-draft` でクエスト作成のタイトル/説明文を下書き生成、`/ai/spot-draft` でスポット説明文を下書き生成（どちらも要JWT）。

## データモデル（SQLAlchemy）
- User: `username`、`hashed_password`、`icon_url`、`coins`、`current_skin_id` を持ち、投稿スポットと保有スキンに関連。【F:backend/models.py†L17-L42】
- Skin: スキン名・画像 URL・価格を保持。`UserSkin` とのリレーションで所有状況を管理。【F:backend/models.py†L44-L63】
- UserSkin: 中間テーブルとしてユーザーとスキンの多対多を表現。【F:backend/models.py†L65-L81】
- Spot: 緯度経度、タイトル、説明、画像 URL、混雑度、評価、作成日時を保持し、投稿者と適用スキンに紐づく。【F:backend/models.py†L83-L117】

## 環境設定
- フロントエンド: `numyp/env.json` を用意し、`API_BASE_URL` と `GMAP_API_KEY` を設定する。`flutter pub get` 後に `flutter run` で起動。【F:numyp/lib/config/constants.dart†L4-L32】
  - デバッグモード: `env.json` に `"DEBUG": true` を設定すると、ログイン画面をスキップして自動的にテストユーザー（testuser/testpass）でログインする。開発時のみ使用し、本番環境では必ず `false` にすること。
- バックエンド: `backend/.env` に DB 接続、JWT `SECRET_KEY`、Cloudflare R2 の各種キーを設定し、`pip install -r requirements.txt` で依存を導入する。必要に応じて `python test_r2.py` で R2 接続を検証。【F:backend/readme.md†L1-L48】
  - AI: `OLLAMA_BASE_URL` と `OLLAMA_MODEL` を設定すると、バックエンド経由でOllamaに接続できる。

## 現状のユースケース例
1. ユーザー登録 → `/auth/signup` → `/auth/login` で JWT を取得。
2. アプリにトークンを設定し `/users/me` でプロフィールを読み込む。マップ画面でスポット一覧を取得（`/spots`）。
3. スポット投稿時は位置・タイトル等とともに必要なら base64 画像を送信し、R2 に保存された画像 URL がレスポンスに含まれる。
4. ショップでスキンを購入するとコイン残高が更新され、以後のスポットにスキンが紐づく。
