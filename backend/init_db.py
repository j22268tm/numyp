# データベースの初期化用スクリプト

from database import engine, Base
import models
from sqlalchemy import inspect
from sqlalchemy.exc import SQLAlchemyError

def init_db():
    print("既存のテーブルを削除しています...")
    
    try:
        # Metadataを使用してテーブルを削除
        Base.metadata.drop_all(bind=engine)
    except SQLAlchemyError as e:
        # 既存DBが「名前なしFK」「循環参照」「既存constraint名の差異」などだと drop_all が失敗するので強制削除する
        print(f"drop_all が失敗したためフォールバックします: {e.__class__.__name__}")
        with engine.begin() as conn:
            insp = inspect(conn)
            preparer = conn.dialect.identifier_preparer
            existing_tables = set(insp.get_table_names())
            managed_tables = set(Base.metadata.tables.keys())
            table_names = [t for t in existing_tables if t in managed_tables]

            if conn.dialect.name == "sqlite":
                conn.exec_driver_sql("PRAGMA foreign_keys=OFF")
                for table_name in table_names:
                    quoted = preparer.quote(table_name)
                    conn.exec_driver_sql(f"DROP TABLE IF EXISTS {quoted}")
                conn.exec_driver_sql("PRAGMA foreign_keys=ON")
            else:
                for table_name in table_names:
                    quoted = preparer.quote(table_name)
                    conn.exec_driver_sql(f"DROP TABLE IF EXISTS {quoted} CASCADE")
    
    print("新しいテーブルを作成しています...")
    Base.metadata.create_all(bind=engine)
    
    print("データベースの初期化が完了しました！")

if __name__ == "__main__":
    init_db()
