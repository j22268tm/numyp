from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from datetime import datetime
from enum import Enum
from uuid import UUID


# 定数定義
class CrowdLevel(str, Enum):
    LOW = "low"       # 空いてる
    MEDIUM = "medium" # 普通
    HIGH = "high"     # 混んでる


# ネスト用 拡張性優先のためclass乱立してます
class LocationInfo(BaseModel):
    lat: float = Field(..., description="Latitude")
    lng: float = Field(..., description="Longitude")
    # address: Optional[str] = None

class ContentInfo(BaseModel):
    title: str = Field(..., min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=200)
    image_url: Optional[str] = None
    # tags: List[str] = []

class SpotStatus(BaseModel):
    crowd_level: CrowdLevel = CrowdLevel.MEDIUM
    rating: int = Field(3, ge=1, le=5, description="1 to 5 stars")
    # likes_count: int = 0

class SkinInfo(BaseModel):
    id: UUID
    name: str
    image_url: str

class AuthorInfo(BaseModel):
    id: UUID
    username: str
    icon_url: Optional[str] = None


# API Request Models クライアント→サーバー
class SpotCreate(BaseModel):
    """スポット投稿用モデル 入力はフラット"""
    lat: float
    lng: float
    title: str
    description: Optional[str] = None
    image_base64: Optional[str] = Field(None, description="Base64 encoded image string")
    crowd_level: Optional[CrowdLevel] = CrowdLevel.MEDIUM
    rating: Optional[int] = 3

class UserCreate(BaseModel):
    username: str
    password: str

class LoginRequest(BaseModel):
    username: str
    password: str

class BuyItemRequest(BaseModel):
    item_id: UUID


# API Response Models サーバー→クライアント
class SpotResponse(BaseModel):
    """スポット取得用モデル"""
    id: UUID
    created_at: datetime
    
    # Grouping
    location: LocationInfo
    content: ContentInfo
    status: SpotStatus
    author: AuthorInfo
    skin: SkinInfo

    model_config = ConfigDict(from_attributes=True)

class UserWallet(BaseModel):
    coins: int

class UserResponse(BaseModel):
    """ユーザー情報レスポンス"""
    id: UUID
    username: str
    icon_url: Optional[str] = None
    
    # Grouping
    wallet: UserWallet
    current_skin: SkinInfo

    model_config = ConfigDict(from_attributes=True)

class CheckinResponse(BaseModel):
    message: str
    earned_coins: int
    current_balance: int

class Token(BaseModel):
    access_token: str
    token_type: str