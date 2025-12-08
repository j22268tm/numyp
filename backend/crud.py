from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import Optional, List
import models
import schemas
from uuid import UUID
from passlib.context import CryptContext
from enum import Enum

# パスワードハッシュ化
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ===== Purchase Result =====
class PurchaseResult(Enum):
    """スキン購入結果"""
    SUCCESS = "success"
    USER_NOT_FOUND = "user_not_found"
    SKIN_NOT_FOUND = "skin_not_found"
    ALREADY_OWNED = "already_owned"
    INSUFFICIENT_COINS = "insufficient_coins"


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
    
    # デフォルトアイコンURLを取得
    default_icon_url = get_default_user_icon_url()
    
    db_user = models.User(
        username=user.username,
        hashed_password=hashed_password,
        coins=0,
        current_skin_id=default_skin.id,
        icon_url=default_icon_url
    )
    db.add(db_user)
    db.flush()  # ID採番を明示

    # デフォルトスキンを所有スキンに追加
    user_skin = models.UserSkin(
        user_id=db_user.id,
        skin_id=default_skin.id,
    )
    db.add(user_skin)

    db.commit()
    db.refresh(db_user)
    return db_user


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """パスワードを検証"""
    return pwd_context.verify(plain_password, hashed_password)


def update_user_coins(db: Session, user_id: UUID, coin_delta: int) -> models.User:
    """
    ユーザーのコインを更新
    """
    user = get_user_by_id(db, user_id)
    if not user:
        raise ValueError(f"user {user_id} not found")

    new_balance = user.coins + coin_delta
    if new_balance < 0:
        raise ValueError("coin balance must not be negative")

    user.coins = new_balance
    # 呼び出し元でコミットを管理するため、ここではコミットしない
    db.flush()
    return user


# ===== Default Assets =====
def get_default_user_icon_url() -> Optional[str]:
    """デフォルトユーザーアイコンのURLを取得（R2にアップロード、既存の場合は再利用）"""
    from r2_storage import get_r2_storage
    from pathlib import Path
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        r2 = get_r2_storage()
        static_dir = Path(__file__).parent / "static"
        default_icon_path = static_dir / "default_user_icon.png"
        
        # R2にアップロード（既に存在する場合はスキップ）
        return r2.upload_static_file(
            file_path=default_icon_path,
            object_key="defaults/default_user_icon.png",
            content_type="image/png"
        )
    except Exception:
        # R2アップロードに失敗した場合、ログを記録してNoneを返す
        logger.exception("Failed to upload default user icon to R2")
        return None


# ===== Skin CRUD =====
def get_or_create_default_skin(db: Session) -> models.Skin:
    """デフォルトスキンを取得または作成"""
    from r2_storage import get_r2_storage
    from pathlib import Path
    import logging
    
    logger = logging.getLogger(__name__)
    
    default_skin = db.query(models.Skin).filter(models.Skin.name == "Default Pin").first()
    if not default_skin:
        # デフォルトスキン画像をR2にアップロード（既に存在する場合はスキップ）
        r2 = get_r2_storage()
        static_dir = Path(__file__).parent / "static"
        default_icon_path = static_dir / "default_user_icon.png"
        
        try:
            image_url = r2.upload_static_file(
                file_path=default_icon_path,
                object_key="defaults/default_user_icon.png",
                content_type="image/png"
            )
        except Exception as e:
            # R2アップロードに失敗した場合、ログを記録して例外を再発生
            logger.exception("Failed to upload default skin image to R2")
            raise RuntimeError(f"Cannot initialize default skin without R2 storage: {str(e)}") from e
        
        default_skin = models.Skin(
            name="Default Pin",
            image_url=image_url,
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


def purchase_skin(db: Session, user_id: UUID, skin_id: UUID) -> PurchaseResult:
    """スキンを購入"""
    user = get_user_by_id(db, user_id)
    if not user:
        return PurchaseResult.USER_NOT_FOUND
    
    skin = get_skin_by_id(db, skin_id)
    if not skin:
        return PurchaseResult.SKIN_NOT_FOUND
    
    # すでに所有している場合
    if user_owns_skin(db, user_id, skin_id):
        return PurchaseResult.ALREADY_OWNED
    
    # コインが足りない場合
    if user.coins < skin.price:
        return PurchaseResult.INSUFFICIENT_COINS
    
    # コインを減らす
    user.coins -= skin.price
    
    # 所有スキンに追加
    user_skin = models.UserSkin(user_id=user_id, skin_id=skin_id)
    db.add(user_skin)
    db.commit()
    
    return PurchaseResult.SUCCESS


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
    
    # 位置情報パラメータは将来のフィルタ用に予約
    _ = (lat, lng, radius)
    
    return query.limit(limit).all()


def get_spot_by_id(db: Session, spot_id: UUID) -> Optional[models.Spot]:
    """IDでスポットを取得"""
    return db.query(models.Spot).filter(models.Spot.id == spot_id).first()


def create_spot(db: Session, spot: schemas.SpotCreate, user_id: UUID, image_url: Optional[str] = None) -> models.Spot:
    """新規スポットを作成"""
    user = get_user_by_id(db, user_id)
    if user is None:
        raise ValueError(f"user {user_id} not found")

    # ユーザーの現在のスキンを使用
    skin_id = user.current_skin_id or get_or_create_default_skin(db).id

    db_spot = models.Spot(
        author_id=user_id,
        skin_id=skin_id,
        latitude=spot.lat,
        longitude=spot.lng,
        title=spot.title,
        description=spot.description,
        image_url=image_url,  # R2からのURLまたはNone
        crowd_level=spot.crowd_level if spot.crowd_level else models.CrowdLevelEnum.MEDIUM,
        rating=spot.rating if spot.rating is not None else 3,
    )

    try:
        db.add(db_spot)
        db.flush()  # IDを取得するためflushを実行
        
        # 投稿報酬としてコインを付与（同一トランザクション内）
        update_user_coins(db, user_id, 10)
        
        # 両方成功した場合のみコミット
        db.commit()
        db.refresh(db_spot)
    except Exception:
        db.rollback()
        raise

    return db_spot
