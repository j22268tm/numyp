from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os

# 環境変数を読み込み
load_dotenv()

# CockroachDB接続URL
DATABASE_URL = os.getenv("DATABASE_URL")

# CockroachDB用のエンジン作成
# QueuePool
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=0,
    pool_recycle=300,
    pool_timeout=20,
    pool_pre_ping=True,
    connect_args={"connect_timeout": 10}
)

# セッションローカルの作成
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Baseクラスの作成
naming_convention = {
    "ix": "ix_%(table_name)s_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}
Base = declarative_base(metadata=MetaData(naming_convention=naming_convention))


# 依存性注入用のDB取得関数
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
