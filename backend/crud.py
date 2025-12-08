from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import Optional, List
import models
import schemas
from uuid import UUID
from passlib.context import CryptContext

# パスワードハッシュ化
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ===== User CRUD =====
def get_user_by_username(db: Session, username: str) -> Optional[models.User]:
    """ユーザー名でユーザーを取得"""
    return db.query(models.User).filter(models.User.username == username).first()


def get_user_by_id(db: Session, user_id: UUID) -> Optional[models.User]:
    """IDでユーザーを取得"""
    return db.query(models.User).filter(models.User.id == user_id).first()


def create_user(db: Session, user: schemas.UserCreate) -> models.User:
    """新規ユーザーを作成"""
    hashed_password = pwd_context.hash(user.password)
    
    # デフォルトスキンを取得または作成
    default_skin = get_or_create_default_skin(db)
    
    db_user = models.User(
        username=user.username,
        hashed_password=hashed_password,
        coins=0,
        current_skin_id=default_skin.id
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # デフォルトスキンを所有スキンに追加
    user_skin = models.UserSkin(
        user_id=db_user.id,
        skin_id=default_skin.id
    )
    db.add(user_skin)
    db.commit()
    
    return db_user


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """パスワードを検証"""
    return pwd_context.verify(plain_password, hashed_password)


def update_user_coins(db: Session, user_id: UUID, coin_delta: int) -> models.User:
    """ユーザーのコインを更新"""
    user = get_user_by_id(db, user_id)
    if user:
        user.coins += coin_delta
        db.commit()
        db.refresh(user)
    return user


# ===== Skin CRUD =====
def get_or_create_default_skin(db: Session) -> models.Skin:
    """デフォルトスキンを取得または作成"""
    default_skin = db.query(models.Skin).filter(models.Skin.name == "Default Pin").first()
    if not default_skin:
        default_skin = models.Skin(
            name="Default Pin",
            image_url="https://via.placeholder.com/50",
            price=0
        )
        db.add(default_skin)
        db.commit()
        db.refresh(default_skin)
    return default_skin


def get_skin_by_id(db: Session, skin_id: UUID) -> Optional[models.Skin]:
    """IDでスキンを取得"""
    return db.query(models.Skin).filter(models.Skin.id == skin_id).first()


def get_all_skins(db: Session) -> List[models.Skin]:
    """全スキンを取得"""
    return db.query(models.Skin).all()


def user_owns_skin(db: Session, user_id: UUID, skin_id: UUID) -> bool:
    """ユーザーがスキンを所有しているか確認"""
    return db.query(models.UserSkin).filter(
        and_(
            models.UserSkin.user_id == user_id,
            models.UserSkin.skin_id == skin_id
        )
    ).first() is not None


def purchase_skin(db: Session, user_id: UUID, skin_id: UUID) -> bool:
    """スキンを購入"""
    user = get_user_by_id(db, user_id)
    skin = get_skin_by_id(db, skin_id)
    
    if not user or not skin:
        return False
    
    # すでに所有している場合
    if user_owns_skin(db, user_id, skin_id):
        return False
    
    # コインが足りない場合
    if user.coins < skin.price:
        return False
    
    # コインを減らす
    user.coins -= skin.price
    
    # 所有スキンに追加
    user_skin = models.UserSkin(user_id=user_id, skin_id=skin_id)
    db.add(user_skin)
    db.commit()
    
    return True


# ===== Spot CRUD =====
def get_spots(
    db: Session,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius: Optional[float] = None,
    limit: int = 100
) -> List[models.Spot]:
    """スポット一覧を取得（将来的に位置情報フィルタリング実装可能）"""
    query = db.query(models.Spot).order_by(models.Spot.created_at.desc())
    
    return query.limit(limit).all()


def get_spot_by_id(db: Session, spot_id: UUID) -> Optional[models.Spot]:
    """IDでスポットを取得"""
    return db.query(models.Spot).filter(models.Spot.id == spot_id).first()


def create_spot(db: Session, spot: schemas.SpotCreate, user_id: UUID) -> models.Spot:
    """新規スポットを作成"""
    user = get_user_by_id(db, user_id)
    
    # ユーザーの現在のスキンを使用
    skin_id = user.current_skin_id if user.current_skin_id else get_or_create_default_skin(db).id
    
    db_spot = models.Spot(
        author_id=user_id,
        skin_id=skin_id,
        latitude=spot.lat,
        longitude=spot.lng,
        title=spot.title,
        description=spot.description,
        image_url="https://via.placeholder.com/300" if not spot.image_base64 else "https://via.placeholder.com/300",  # TODO: 画像アップロード実装
        crowd_level=spot.crowd_level if spot.crowd_level else models.CrowdLevelEnum.MEDIUM,
        rating=spot.rating if spot.rating else 3
    )
    
    db.add(db_spot)
    db.commit()
    db.refresh(db_spot)
    
    # 投稿報酬としてコインを付与
    update_user_coins(db, user_id, 10)
    
    return db_spot
