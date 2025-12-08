# データベースの初期化用スクリプト

from database import engine, Base
from sqlalchemy import text
import models

def init_db():
    print("既存のテーブルを削除しています...")
    
    # 既存のテーブルをCASCADEで削除
    with engine.connect() as conn:
        existing_tables = ['user_items', 'user_skins', 'spots', 'users', 'skins']
        
        for table_name in existing_tables:
            try:
                print(f"  削除中: {table_name}")
                conn.execute(text(f"DROP TABLE IF EXISTS {table_name} CASCADE"))
                conn.commit()
            except Exception as e:
                print(f"  {table_name} の削除をスキップ: {e}")
    
    print("新しいテーブルを作成しています...")
    Base.metadata.create_all(bind=engine)
    
    print("データベースの初期化が完了しました！")

if __name__ == "__main__":
    init_db()
