"""
Cloudflare R2接続テストスクリプト
"""
import sys
from pathlib import Path
from io import BytesIO

# プロジェクトのルートディレクトリをパスに追加
sys.path.insert(0, str(Path(__file__).parent))

from r2_storage import get_r2_storage


def test_r2_connection():
    """R2接続をテスト"""
    print("=== Cloudflare R2 Connection Test ===\n")
    
    try:
        # R2ストレージインスタンスを取得
        r2 = get_r2_storage()
        print("✓ R2 Storage client initialized successfully")
        print(f"  - Bucket: {r2.bucket_name}")
        print(f"  - Endpoint: {r2.endpoint_url}")
        print(f"  - Public URL: {r2.public_url}\n")
        
        # テストファイルを作成
        test_content = b"Hello from Numyp! This is a test file."
        test_file = BytesIO(test_content)
        
        print("Uploading test file...")
        file_url = r2.upload_file(
            file_data=test_file,
            filename="test.txt",
            content_type="text/plain",
            folder="test"
        )
        print(f"✓ File uploaded successfully!")
        print(f"  - URL: {file_url}\n")
        
        # ファイルの存在確認
        print("Checking if file exists...")
        exists = r2.file_exists(file_url)
        print(f"✓ File exists: {exists}\n")
        
        # ファイル削除
        print("Deleting test file...")
        deleted = r2.delete_file(file_url)
        print(f"✓ File deleted: {deleted}\n")
        
        # 削除後の存在確認
        print("Checking if file exists after deletion...")
        exists_after = r2.file_exists(file_url)
        print(f"✓ File exists after deletion: {exists_after}\n")
        
        print("=== All tests passed! ===")
        return True
        
    except Exception as e:
        print(f"✗ Test failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_r2_connection()
    sys.exit(0 if success else 1)
