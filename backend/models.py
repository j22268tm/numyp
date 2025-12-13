from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Enum as SQLEnum, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import uuid
import enum

from database import Base


# Enums
class CrowdLevelEnum(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class QuestStatusEnum(str, enum.Enum):
    OPEN = "open"
    ACCEPTED = "accepted"
    COMPLETED = "completed"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class QuestParticipantStatusEnum(str, enum.Enum):
    INVITED = "invited"
    ACCEPTED = "accepted"
    REPORTED = "reported"
    SETTLED = "settled"
    EXPIRED = "expired"
    DECLINED = "declined"


class NotificationTypeEnum(str, enum.Enum):
    QUEST_COMPLETED = "quest_completed"


# Models
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    icon_url = Column(String(500), nullable=True)
    coins = Column(Integer, default=0, nullable=False)
    current_skin_id = Column(UUID(as_uuid=True), ForeignKey("skins.id"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    current_skin = relationship("Skin", foreign_keys=[current_skin_id])
    spots = relationship("Spot", back_populates="author")
    owned_skins = relationship("UserSkin", back_populates="user")
    requested_quests = relationship("Quest", back_populates="requester", foreign_keys="Quest.requester_id")
    active_walks = relationship("QuestParticipant", back_populates="walker", foreign_keys="QuestParticipant.walker_id")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")


class Skin(Base):
    __tablename__ = "skins"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(50), nullable=False)
    image_url = Column(String(500), nullable=False)
    price = Column(Integer, default=100, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user_skins = relationship("UserSkin", back_populates="skin")


class UserSkin(Base):
    """ユーザーが所有しているスキンの中間テーブル"""
    __tablename__ = "user_skins"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    skin_id = Column(UUID(as_uuid=True), ForeignKey("skins.id"), nullable=False)
    purchased_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("User", back_populates="owned_skins")
    skin = relationship("Skin", back_populates="user_skins")


class Spot(Base):
    __tablename__ = "spots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    skin_id = Column(UUID(as_uuid=True), ForeignKey("skins.id"), nullable=False)
    
    # Location
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)
    
    # Content
    title = Column(String(50), nullable=False)
    description = Column(String(200), nullable=True)
    image_url = Column(String(500), nullable=True)
    
    # Status
    crowd_level = Column(SQLEnum(CrowdLevelEnum), default=CrowdLevelEnum.MEDIUM, nullable=False)
    rating = Column(Integer, default=3, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    author = relationship("User", back_populates="spots")
    skin = relationship("Skin")


class Quest(Base):
    __tablename__ = "quests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    requester_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    active_participant_id = Column(
        UUID(as_uuid=True),
        ForeignKey(
            "quest_participants.id",
            name="fk_quests_active_participant_id",
            use_alter=True,
        ),
        nullable=True,
    )

    # Location
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)
    radius_meters = Column(Integer, default=200, nullable=False)

    # Content and reward
    title = Column(String(80), nullable=False)
    description = Column(String(500), nullable=True)
    bounty_coins = Column(Integer, nullable=False)
    locked_bounty_coins = Column(Integer, default=0, nullable=False)

    # Status and lifecycle
    status = Column(SQLEnum(QuestStatusEnum), default=QuestStatusEnum.OPEN, nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    expires_at = Column(DateTime, nullable=True, index=True)
    accepted_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    expired_at = Column(DateTime, nullable=True)

    # Relationships
    requester = relationship("User", back_populates="requested_quests", foreign_keys=[requester_id])
    active_participant = relationship("QuestParticipant", foreign_keys=[active_participant_id], post_update=True)
    # Explicit foreign_keys avoids ambiguity with active_participant_id -> quest_participants.id
    participants = relationship(
        "QuestParticipant",
        back_populates="quest",
        cascade="all, delete-orphan",
        foreign_keys="QuestParticipant.quest_id",
    )


class QuestParticipant(Base):
    __tablename__ = "quest_participants"
    __table_args__ = (UniqueConstraint("quest_id", "walker_id", name="uq_quest_walker"),)

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    quest_id = Column(
        UUID(as_uuid=True),
        ForeignKey("quests.id", name="fk_quest_participants_quest_id"),
        nullable=False,
    )
    walker_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    status = Column(SQLEnum(QuestParticipantStatusEnum), default=QuestParticipantStatusEnum.ACCEPTED, nullable=False, index=True)
    accepted_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    reported_at = Column(DateTime, nullable=True)
    reward_paid_at = Column(DateTime, nullable=True)
    distance_at_accept_m = Column(Integer, nullable=True)

    # Report payload
    photo_url = Column(String(500), nullable=True)
    comment = Column(String(500), nullable=True)
    report_latitude = Column(Float, nullable=True)
    report_longitude = Column(Float, nullable=True)

    # Relationships
    quest = relationship("Quest", back_populates="participants", foreign_keys=[quest_id])
    walker = relationship("User", back_populates="active_walks", foreign_keys=[walker_id])


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    quest_id = Column(UUID(as_uuid=True), ForeignKey("quests.id"), nullable=True, index=True)

    type = Column(SQLEnum(NotificationTypeEnum), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    body = Column(String(500), nullable=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    read_at = Column(DateTime, nullable=True, index=True)

    user = relationship("User", back_populates="notifications", foreign_keys=[user_id])
    quest = relationship("Quest", foreign_keys=[quest_id])
