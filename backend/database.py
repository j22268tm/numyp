from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool
from dotenv import load_dotenv
import os

# 環境変数を読み込み
load_dotenv()

# CockroachDB接続URL
DATABASE_URL = os.getenv("DATABASE_URL")

# CockroachDB用のエンジン作成
# NullPoolを使用してコネクションプーリングを無効化（CockroachDBの推奨設定）
engine = create_engine(
    DATABASE_URL,
    poolclass=NullPool,
    connect_args={"connect_timeout": 10}
)

# セッションローカルの作成
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Baseクラスの作成
Base = declarative_base()


# 依存性注入用のDB取得関数
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
