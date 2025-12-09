# データベースの初期化用スクリプト

from database import engine, Base
import models

def init_db():
    print("既存のテーブルを削除しています...")
    
    # Metadataを使用してテーブルを削除
    Base.metadata.drop_all(bind=engine)
    
    print("新しいテーブルを作成しています...")
    Base.metadata.create_all(bind=engine)
    
    print("データベースの初期化が完了しました！")

if __name__ == "__main__":
    init_db()
