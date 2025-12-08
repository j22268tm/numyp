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