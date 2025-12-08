import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
import os
from typing import Optional, BinaryIO
from datetime import datetime
import uuid
from pathlib import Path
from dotenv import load_dotenv
import logging

load_dotenv()

logger = logging.getLogger(__name__)


class R2Storage:    
    def __init__(self):
        """R2クライアントの初期化"""
        self.access_key_id = os.getenv("R2_ACCESS_KEY_ID")
        self.secret_access_key = os.getenv("R2_SECRET_ACCESS_KEY")
        self.bucket_name = os.getenv("R2_BUCKET_NAME")
        self.endpoint_url = os.getenv("R2_ENDPOINT_URL")
        self.public_url = os.getenv("R2_PUBLIC_URL")
        
        # 設定チェック
        if not all([self.access_key_id, self.secret_access_key, self.bucket_name, self.endpoint_url]):
            raise ValueError("R2 configuration is incomplete. Please check your .env file.")
        
        self.s3_client = boto3.client(
            's3',
            endpoint_url=self.endpoint_url,
            aws_access_key_id=self.access_key_id,
            aws_secret_access_key=self.secret_access_key,
            config=Config(signature_version='s3v4'),
            region_name='auto'  # R2では'auto'を使用
        )
    
    def upload_file(
        self,
        file_data: BinaryIO,
        filename: str,
        content_type: Optional[str] = None,
        folder: str = "images",
        public: bool = True
    ) -> str:
        """
        ファイルをR2にアップロードする
        
        Args:
            file_data: アップロードするファイルのバイナリデータ
            filename: オリジナルのファイル名
            content_type: ファイルのMIMEタイプ（例: 'image/jpeg'）
            folder: R2バケット内のフォルダ名
            public: 公開アクセスを許可するかどうか（デフォルト: True）
        
        Returns:
            アップロードされたファイルの公開URL
        """
        try:
            # ユニークなファイル名を生成（拡張子は保持）
            file_extension = Path(filename).suffix
            unique_filename = f"{uuid.uuid4()}{file_extension}"
            
            # R2内のキー（パス）を生成
            object_key = f"{folder}/{unique_filename}"
            
            # アップロード時のメタデータ
            extra_args = {}
            if content_type:
                extra_args['ContentType'] = content_type
            
            # ACLをpublic-readに設定（公開アクセス可能にする）
            if public:
                extra_args['ACL'] = 'public-read'
            
            # ファイルをアップロード
            self.s3_client.upload_fileobj(
                file_data,
                self.bucket_name,
                object_key,
                ExtraArgs=extra_args
            )
            
            # 公開URLを生成
            public_url = self._generate_public_url(object_key)
            
            return public_url
            
        except ClientError as e:
            raise Exception(f"Failed to upload file to R2: {str(e)}")
    
    def delete_file(self, file_url: str) -> bool:
        """
        R2からファイルを削除する
        
        Args:
            file_url: 削除するファイルの公開URL
        
        Returns:
            削除が成功したかどうか
        """
        try:
            # URLからオブジェクトキーを抽出
            object_key = self._extract_object_key(file_url)
            
            if not object_key:
                return False
            
            # ファイルを削除
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=object_key
            )
            
            return True
            
        except ClientError as e:
            logger.error(f"Failed to delete file from R2: {str(e)}")
            return False
    
    def file_exists(self, file_url: str) -> bool:
        """
        ファイルがR2に存在するか確認する
        
        Args:
            file_url: 確認するファイルの公開URL
        
        Returns:
            ファイルが存在するかどうか
        """
        try:
            object_key = self._extract_object_key(file_url)
            
            if not object_key:
                return False
            
            self.s3_client.head_object(
                Bucket=self.bucket_name,
                Key=object_key
            )
            
            return True
            
        except ClientError:
            return False
    
    def _generate_public_url(self, object_key: str) -> str:
        """
        オブジェクトキーから公開URLを生成する
        
        Args:
            object_key: R2内のオブジェクトキー
        
        Returns:
            公開URL
        """
        if self.public_url:
            # カスタムドメインが設定されている場合
            return f"{self.public_url.rstrip('/')}/{object_key}"
        else:
            # デフォルトのR2 URLを使用
            return f"{self.endpoint_url.rstrip('/')}/{self.bucket_name}/{object_key}"
    
    def _extract_object_key(self, file_url: str) -> Optional[str]:
        """
        URLからオブジェクトキーを抽出する
        
        Args:
            file_url: ファイルの公開URL
        
        Returns:
            オブジェクトキー（抽出できない場合はNone）
        """
        try:
            # カスタムドメインの場合
            if self.public_url and file_url.startswith(self.public_url):
                return file_url.replace(f"{self.public_url.rstrip('/')}/", "")
            
            # デフォルトURLの場合
            if self.endpoint_url in file_url:
                parts = file_url.split(f"{self.bucket_name}/")
                if len(parts) > 1:
                    return parts[1]
            
            return None
            
        except Exception:
            return None


# シングルトンインスタンス
_r2_storage = None


def get_r2_storage() -> R2Storage:
    """R2Storageのシングルトンインスタンスを取得"""
    global _r2_storage
    if _r2_storage is None:
        _r2_storage = R2Storage()
    return _r2_storage
