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


class QuestStatus(str, Enum):
    OPEN = "open"
    ACCEPTED = "accepted"
    COMPLETED = "completed"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class QuestParticipantStatus(str, Enum):
    INVITED = "invited"
    ACCEPTED = "accepted"
    REPORTED = "reported"
    SETTLED = "settled"
    EXPIRED = "expired"
    DECLINED = "declined"


class NotificationType(str, Enum):
    QUEST_COMPLETED = "quest_completed"


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


class SpotUpdate(BaseModel):
    """スポット更新用モデル(部分更新も許容)"""
    lat: Optional[float] = None
    lng: Optional[float] = None
    title: Optional[str] = Field(None, min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=200)
    image_base64: Optional[str] = Field(None, description="Base64 encoded image string")
    crowd_level: Optional[CrowdLevel] = None
    rating: Optional[int] = Field(None, ge=1, le=5, description="1 to 5 stars")

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


# Quest feature
class QuestReportPayload(BaseModel):
    photo_url: Optional[str] = None
    image_base64: Optional[str] = Field(None, description="Base64 encoded image string (quest report photo)")
    comment: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class QuestAcceptRequest(BaseModel):
    lat: Optional[float] = None
    lng: Optional[float] = None


class QuestParticipantResponse(BaseModel):
    id: UUID
    status: QuestParticipantStatus
    walker: AuthorInfo
    accepted_at: datetime
    reported_at: Optional[datetime] = None
    reward_paid_at: Optional[datetime] = None
    distance_at_accept_m: Optional[int] = None
    photo_url: Optional[str] = None
    comment: Optional[str] = None
    report_latitude: Optional[float] = None
    report_longitude: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


class QuestCreate(BaseModel):
    lat: float
    lng: float
    radius_meters: int = Field(200, gt=0, description="Meters from the quest pin to be considered nearby")
    title: str = Field(..., min_length=1, max_length=80)
    description: Optional[str] = Field(None, max_length=500)
    bounty_coins: int = Field(..., ge=1, description="Coins to lock as bounty")
    expires_at: Optional[datetime] = None


class QuestResponse(BaseModel):
    id: UUID
    status: QuestStatus
    created_at: datetime
    expires_at: Optional[datetime] = None
    accepted_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    expired_at: Optional[datetime] = None

    # Grouping
    location: LocationInfo
    radius_meters: int
    title: str
    description: Optional[str] = None
    bounty_coins: int
    locked_bounty_coins: int
    requester: AuthorInfo
    active_participant_id: Optional[UUID] = None
    participants: List[QuestParticipantResponse] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    token_type: str


class NotificationResponse(BaseModel):
    id: UUID
    type: NotificationType
    title: str
    body: str
    quest_id: Optional[UUID] = None
    created_at: datetime
    read_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class QuestCompletionReportResponse(BaseModel):
    quest_id: UUID
    title: str
    completed_at: Optional[datetime] = None

    requester: AuthorInfo
    walker: Optional[AuthorInfo] = None

    photo_url: Optional[str] = None
    comment: Optional[str] = None
    reported_at: Optional[datetime] = None
    report_location: Optional[LocationInfo] = None
