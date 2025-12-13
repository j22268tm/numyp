# setup

1. /numyp/env.json.exampleをenv.jsonに名前変更orCopyしてリネーム
2. env.jsonのapiキーを書き換える
3. flutter pub get && flutter runで起動できるはず...

## デバッグモード

開発を容易にするため、env.jsonにDEBUGフラグを設定することで、ログイン画面をスキップして自動的にテストユーザーでログインできます。

```json
{
  "API_BASE_URL": "http://localhost:8000",
  "GMAP_API_KEY": "your-api-key",
  "DEBUG": true
}
```

DEBUGをtrueにすると、以下のテストユーザーで自動ログインします：
- ユーザー名: `testuser`
- パスワード: `testpass`

**注意**: 本番環境では必ず `DEBUG: false` に設定してください。
