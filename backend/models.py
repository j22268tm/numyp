from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Enum as SQLEnum
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

class Pin(Base):
    __tablename__ = "pins"
    id = Column(Integer, primary_key=True)
    name = Column(String)
    description = Column(String, nullable=True)
    price = Column(Integer)
    image_url = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

