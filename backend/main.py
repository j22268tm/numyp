from fastapi import FastAPI, HTTPException, Depends, Query, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import List, Optional, Annotated
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timedelta, timezone
import schemas
import crud
import models
from database import engine, get_db
from uuid import uuid4, UUID
from jose import JWTError, jwt
import os
from dotenv import load_dotenv
from r2_storage import get_r2_storage
import base64
from io import BytesIO
import logging
import math
import json
import re
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
import socket

# 環境変数を読み込み
load_dotenv()

# ロガー設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# JWT設定
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY must be set in environment for security reasons")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30


app = FastAPI(
    title="Numyp API",
    description="API for Numyp",
    version="1.0.0"
)


# CORS
# ハッカソン用,開発環境のオリジンを許可
app.add_middleware(
    CORSMiddleware,
    # allow_origins=["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:3000"],
    allow_origins=["*"], # for debug
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 認証のための設定
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


# ヘルパー関数
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """JWTトークンを作成"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def _upload_image_from_base64(image_base64: str, folder: str = "spots") -> str:
    """
    base64文字列から画像をアップロードし、公開URLを返す。
    バリデーションエラーはHTTPExceptionで返却する。
    """
    # base64サイズ制限（約10MB相当）
    max_base64_size = 14 * 1024 * 1024
    if len(image_base64) > max_base64_size:
        raise HTTPException(status_code=400, detail="Image data is too large")

    try:
        # base64文字列から画像データを抽出
        # フォーマット: "data:image/jpeg;base64,/9j/4AAQ..." の場合
        if "," in image_base64:
            header, encoded = image_base64.split(",", 1)
            # Content-Typeを抽出（例: "image/jpeg"）
            content_type = header.split(":")[1].split(";")[0]
        else:
            encoded = image_base64
            content_type = "image/jpeg"  # デフォルト

        # base64デコード
        image_data = base64.b64decode(encoded)

        # ファイル拡張子を決定
        ext_map = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
            "image/gif": ".gif"
        }
        extension = ext_map.get(content_type, ".jpg")

        # R2にアップロード
        r2_storage = get_r2_storage()
        return r2_storage.upload_file(
            file_data=BytesIO(image_data),
            filename=f"spot_{uuid4()}{extension}",
            content_type=content_type,
            folder=folder
        )
    except (ValueError, base64.binascii.Error):
        # base64フォーマット不正などクライアント側の問題
        raise HTTPException(status_code=400, detail="Invalid image data") from None
    except HTTPException:
        # すでにHTTPExceptionに変換済みの場合はそのまま流す
        raise
    except Exception:
        logger.exception("Failed to upload spot image")
        raise HTTPException(status_code=500, detail="Failed to upload image") from None


def _haversine_distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    """2座標間の距離(メートル)を計算"""
    r = 6371000  # 地球半径(m)
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return int(r * c)


def _ollama_base_url() -> str:
    return os.getenv("OLLAMA_BASE_URL", "http://100.99.165.61:11434").rstrip("/")


def _ollama_model() -> str:
    return os.getenv("OLLAMA_MODEL", "gemma3:12b")


def _extract_json_object(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```[a-zA-Z0-9_-]*\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
        cleaned = cleaned.strip()

    try:
        obj = json.loads(cleaned)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object found in model output")
    return json.loads(cleaned[start : end + 1])


def _ollama_chat(messages: list[dict], *, temperature: float = 0.7) -> str:
    payload = {
        "model": _ollama_model(),
        "messages": messages,
        "stream": False,
        "options": {"temperature": temperature},
    }
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = Request(
        f"{_ollama_base_url()}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(req, timeout=45) as resp:
            raw = resp.read().decode("utf-8")
    except HTTPError as e:
        detail = e.read().decode("utf-8", errors="ignore") if hasattr(e, "read") else str(e)
        raise HTTPException(status_code=502, detail=f"Ollama error: {detail}") from None
    except URLError as e:
        raise HTTPException(status_code=502, detail=f"Ollama unreachable: {e.reason}") from None
    except (TimeoutError, socket.timeout):
        raise HTTPException(status_code=504, detail="Ollama timeout") from None

    try:
        parsed = json.loads(raw)
        return (parsed.get("message") or {}).get("content") or ""
    except Exception:
        raise HTTPException(status_code=502, detail="Invalid response from Ollama") from None


def _spot_to_response(spot: models.Spot, include_description: bool = True) -> schemas.SpotResponse:
    """モデルからレスポンスモデルを生成"""
    return schemas.SpotResponse(
        id=spot.id,
        created_at=spot.created_at,
        location=schemas.LocationInfo(lat=spot.latitude, lng=spot.longitude),
        content=schemas.ContentInfo(
            title=spot.title,
            description=spot.description if include_description else None,
            image_url=spot.image_url,
        ),
        status=schemas.SpotStatus(
            crowd_level=schemas.CrowdLevel(spot.crowd_level.value),
            rating=spot.rating
        ),
        author=schemas.AuthorInfo(
            id=spot.author.id,
            username=spot.author.username,
            icon_url=spot.author.icon_url
        ),
        skin=schemas.SkinInfo(
            id=spot.skin.id,
            name=spot.skin.name,
            image_url=spot.skin.image_url
        )
    )


def _participant_to_response(participant: models.QuestParticipant) -> schemas.QuestParticipantResponse:
    """クエスト参加者のレスポンスモデル変換"""
    return schemas.QuestParticipantResponse(
        id=participant.id,
        status=schemas.QuestParticipantStatus(participant.status.value),
        walker=schemas.AuthorInfo(
            id=participant.walker.id,
            username=participant.walker.username,
            icon_url=participant.walker.icon_url,
        ),
        accepted_at=participant.accepted_at,
        reported_at=participant.reported_at,
        reward_paid_at=participant.reward_paid_at,
        distance_at_accept_m=participant.distance_at_accept_m,
        photo_url=participant.photo_url,
        comment=participant.comment,
        report_latitude=participant.report_latitude,
        report_longitude=participant.report_longitude,
    )


def _quest_to_response(quest: models.Quest) -> schemas.QuestResponse:
    """クエストモデルをレスポンス用に整形"""
    return schemas.QuestResponse(
        id=quest.id,
        status=schemas.QuestStatus(quest.status.value),
        created_at=quest.created_at,
        expires_at=quest.expires_at,
        accepted_at=quest.accepted_at,
        completed_at=quest.completed_at,
        expired_at=quest.expired_at,
        location=schemas.LocationInfo(lat=quest.latitude, lng=quest.longitude),
        radius_meters=quest.radius_meters,
        title=quest.title,
        description=quest.description,
        bounty_coins=quest.bounty_coins,
        locked_bounty_coins=quest.locked_bounty_coins,
        requester=schemas.AuthorInfo(
            id=quest.requester.id,
            username=quest.requester.username,
            icon_url=quest.requester.icon_url,
        ),
        active_participant_id=quest.active_participant_id,
        participants=[_participant_to_response(p) for p in quest.participants],
    )


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """現在のユーザーを取得"""
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception from None
    
    user = crud.get_user_by_id(db, UUID(user_id))
    if user is None:
        raise credentials_exception
    
    # AuthorInfo形式で返す
    return schemas.AuthorInfo(
        id=user.id,
        username=user.username,
        icon_url=user.icon_url
    )


def get_current_user_model(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> models.User:
    """モデルのUserを返す版（クエスト系などで利用）"""
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception from None

    user = crud.get_user_by_id(db, UUID(user_id))
    if user is None:
        raise credentials_exception
    return user


# Endpoints
@app.get("/")
def read_root():
    return {"message": "Welcome to Numyp API! Go to /docs to see Swagger UI."}

# Auth
@app.post("/auth/signup")
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    """新規ユーザー登録"""
    # 既存のユーザー名をチェック
    db_user = crud.get_user_by_username(db, username=user.username)
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    try:
        # ユーザーを作成
        new_user = crud.create_user(db, user)
        return {"message": f"User {new_user.username} created successfully"}
    except IntegrityError:
        # レースコンディションによる一意制約違反をハンドリング
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Username already registered"
        )
    except Exception:
        # その他のデータベースエラー
        db.rollback()
        logger.exception("Failed to create user")
        raise HTTPException(
            status_code=500,
            detail="Failed to create user"
        )

@app.post("/auth/login", response_model=schemas.Token)
def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()], db: Session = Depends(get_db)):
    """ログイン"""
    # ユーザーを取得
    user = crud.get_user_by_username(db, username=form_data.username)
    if not user or not crud.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # JWTトークンを作成
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


# Spots
@app.get("/spots", response_model=List[schemas.SpotResponse])
def get_spots(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius: Optional[float] = None,
    db: Session = Depends(get_db)
):
    """
    Map表示用 スポット一覧を返す あえて情報量は少なめにしてます
    (lat, lng, radiusパラメータは将来の検索機能用に予約)
    """
    # データベースからスポットを取得
    db_spots = crud.get_spots(db, lat=lat, lng=lng, radius=radius)
    
    # レスポンス形式に変換（軽量化のため description は None にする）
    return [_spot_to_response(spot, include_description=False) for spot in db_spots]


@app.post("/upload/image")
async def upload_image(
    _current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    file: UploadFile = File(...),
    folder: str = Query("images", description="Folder name in R2 bucket")
):
    """
    画像ファイルをR2にアップロードする
    
    Args:
        file: アップロードする画像ファイル
        folder: R2バケット内のフォルダ名（デフォルト: images）
    
    Returns:
        アップロードされた画像の公開 URL
    """
    # ファイルタイプの検証
    allowed_types = ["image/jpeg", "image/png", "image/webp", "image/gif"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed types: {', '.join(allowed_types)}"
        )
    
    # ファイルサイズの検証（10MB制限）
    max_size = 10 * 1024 * 1024  # 10MB
    file_content = await file.read()
    
    if len(file_content) > max_size:
        raise HTTPException(status_code=400, detail="File size exceeds 10MB limit")
    
    try:
        # R2にアップロード
        r2_storage = get_r2_storage()
        image_url = r2_storage.upload_file(
            file_data=BytesIO(file_content),
            filename=file.filename,
            content_type=file.content_type,
            folder=folder
        )
        
        return {
            "success": True,
            "image_url": image_url,
            "filename": file.filename,
            "content_type": file.content_type,
            "size": len(file_content)
        }
        
    except Exception:
        # TODO: ログに例外を記録 (logger.exception("Failed to upload image"))
        raise HTTPException(status_code=500, detail="Failed to upload image")


@app.get("/spots/{spot_id}", response_model=schemas.SpotResponse)
def get_spot_detail(spot_id: UUID, db: Session = Depends(get_db)):
    """
    詳細表示用 特定のスポットの全情報を返す。
    ピンをタップした後に呼ばれるAPI。
    """
    # データベースからスポットを取得
    spot = crud.get_spot_by_id(db, spot_id)
    if not spot:
        raise HTTPException(status_code=404, detail="Spot not found")
    
    return _spot_to_response(spot, include_description=True)

@app.post("/spots", response_model=schemas.SpotResponse)
def create_spot(
    spot: schemas.SpotCreate,
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    スポットを作成する。
    入力はフラット出力はネストされた構造にBackend側で変換して保存
    画像がbase64で送られた場合はR2にアップロードする
    """
    image_url = _upload_image_from_base64(spot.image_base64, folder="spots") if spot.image_base64 else None
    
    # データベースにスポットを作成（image_urlを含む）
    new_spot = crud.create_spot(db, spot, current_user.id, image_url=image_url)
    
    return _spot_to_response(new_spot, include_description=True)


@app.put("/spots/{spot_id}", response_model=schemas.SpotResponse)
def update_spot(
    spot_id: UUID,
    spot_update: schemas.SpotUpdate,
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    スポットを更新（作成者のみ）。
    """
    image_url = _upload_image_from_base64(spot_update.image_base64, folder="spots") if spot_update.image_base64 else None
    try:
        updated_spot = crud.update_spot(
            db,
            spot_id,
            current_user.id,
            spot_update,
            image_url=image_url
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Spot not found") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden") from None

    return _spot_to_response(updated_spot, include_description=True)


@app.delete("/spots/{spot_id}")
def delete_spot(
    spot_id: UUID,
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    スポットを削除（作成者のみ）。
    """
    try:
        crud.delete_spot(db, spot_id, current_user.id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Spot not found") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden") from None

    return {"success": True, "id": str(spot_id)}


# Users
@app.get("/users/me", response_model=schemas.UserResponse)
def read_users_me(
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """現在のユーザー情報を取得"""
    user = crud.get_user_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 現在のスキン情報を取得
    current_skin = user.current_skin if user.current_skin else crud.get_or_create_default_skin(db)
    
    return schemas.UserResponse(
        id=user.id,
        username=user.username,
        icon_url=user.icon_url,
        wallet=schemas.UserWallet(coins=user.coins),
        current_skin=schemas.SkinInfo(
            id=current_skin.id,
            name=current_skin.name,
            image_url=current_skin.image_url
        )
    )

@app.post("/users/me/icon")
async def update_user_icon(
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db),
    file: UploadFile = File(...)
):
    """
    ユーザーのアイコン画像を更新する
    
    Args:
        file: アップロードするアイコン画像ファイル
    
    Returns:
        更新されたアイコンのURL
    """
    # ファイルタイプの検証
    allowed_types = ["image/jpeg", "image/png", "image/webp"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed types: {', '.join(allowed_types)}"
        )
    
    # ファイルサイズの検証（5MB制限）
    max_size = 5 * 1024 * 1024  # 5MB
    file_content = await file.read()
    
    if len(file_content) > max_size:
        raise HTTPException(status_code=400, detail="File size exceeds 5MB limit")
    
    try:
        # R2にアップロード
        r2_storage = get_r2_storage()
        
        # content_typeから拡張子を決定する（安全な方法）
        ext_map = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
        extension = ext_map.get(file.content_type, "jpg")
        
        icon_url = r2_storage.upload_file(
            file_data=BytesIO(file_content),
            filename=f"user_icon_{current_user.id}.{extension}",
            content_type=file.content_type,
            folder="user_icons"
        )
        
        # データベースを更新
        user = crud.get_user_by_id(db, current_user.id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")

        # TODO: 古いアイコンの削除を実装（ストレージ容量の節約）
        # if user.icon_url and not user.icon_url.startswith("defaults/"):
        #     try:
        #         r2_storage.delete_file(user.icon_url)
        #     except Exception:
        #         logger.warning("Failed to delete old icon, continuing anyway")
        
        user.icon_url = icon_url
        db.commit()
        
        return {
            "success": True,
            "icon_url": icon_url,
            "message": "User icon updated successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update icon")
        raise HTTPException(status_code=500, detail="Failed to update icon") from e

@app.post("/shop/buy")
def buy_item(
    request: schemas.BuyItemRequest,
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """アイテム（スキン）を購入"""
    # スキンを購入
    success = crud.purchase_skin(db, current_user.id, request.item_id)
    
    if not success:
        user = crud.get_user_by_id(db, current_user.id)
        skin = crud.get_skin_by_id(db, request.item_id)
        
        # ユーザーの存在チェック
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        if not skin:
            raise HTTPException(status_code=404, detail="Item not found")
        if crud.user_owns_skin(db, current_user.id, request.item_id):
            raise HTTPException(status_code=400, detail="Already owned")
        if user.coins < skin.price:
            raise HTTPException(status_code=400, detail="Not enough coins")
        
        raise HTTPException(status_code=400, detail="Purchase failed")
    
    # 更新後のコイン残高を取得
    user = crud.get_user_by_id(db, current_user.id)
    if not user:
        # 購入は成功したがユーザー取得に失敗（理論上は発生しない）
        return {"success": True, "message": f"Item {request.item_id} purchased!"}
    
    return {
        "success": True,
        "remaining_coins": user.coins,
        "message": f"Item {request.item_id} purchased!"
    }


# Quests
@app.get("/quests", response_model=List[schemas.QuestResponse])
def list_quests(
    _current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    """クエスト一覧を取得"""
    quests = crud.list_quests(db)
    return [_quest_to_response(q) for q in quests]


@app.post("/quests", response_model=schemas.QuestResponse)
def create_quest(
    payload: schemas.QuestCreate,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
):
    """新規クエストを作成"""
    try:
        quest = crud.create_quest(db, current_user.id, payload)
        return _quest_to_response(quest)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from None
    except Exception:
        logger.exception("Failed to create quest")
        raise HTTPException(status_code=500, detail="Failed to create quest") from None


@app.post("/quests/{quest_id}/accept", response_model=schemas.QuestResponse)
def accept_quest(
    quest_id: UUID,
    payload: schemas.QuestAcceptRequest,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
):
    """クエストを受ける"""
    distance = None
    if payload.lat is not None and payload.lng is not None:
        quest_for_distance = crud.get_quest_by_id(db, quest_id)
        if quest_for_distance:
            distance = _haversine_distance_m(
                payload.lat,
                payload.lng,
                quest_for_distance.latitude,
                quest_for_distance.longitude,
            )

    try:
        quest = crud.accept_quest(
            db,
            quest_id=quest_id,
            walker_id=current_user.id,
            distance_at_accept_m=distance,
        )
        return _quest_to_response(quest)
    except ValueError:
        raise HTTPException(status_code=404, detail="Quest not found") from None
    except Exception:
        logger.exception("Failed to accept quest")
        raise HTTPException(status_code=500, detail="Failed to accept quest") from None


@app.post("/quests/{quest_id}/report", response_model=schemas.QuestResponse)
def report_quest(
    quest_id: UUID,
    payload: schemas.QuestReportPayload,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
):
    """ウォーカーの報告を登録"""
    try:
        if payload.image_base64:
            uploaded_url = _upload_image_from_base64(payload.image_base64, folder="quest_reports")
            payload = schemas.QuestReportPayload(
                photo_url=uploaded_url,
                comment=payload.comment,
                latitude=payload.latitude,
                longitude=payload.longitude,
            )
        quest = crud.submit_quest_report(
            db,
            quest_id=quest_id,
            walker_id=current_user.id,
            payload=payload,
        )
        return _quest_to_response(quest)
    except ValueError:
        raise HTTPException(status_code=404, detail="Quest not found") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="This quest was not accepted by this user") from None
    except Exception:
        logger.exception("Failed to submit quest report")
        raise HTTPException(status_code=500, detail="Failed to submit report") from None


@app.get("/quests/{quest_id}/completion-report", response_model=schemas.QuestCompletionReportResponse)
def get_quest_completion_report(
    quest_id: UUID,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
):
    """発注者向け: クエスト成果報告画面用データを取得"""
    try:
        quest, participant = crud.get_quest_completion_report(db, quest_id=quest_id, requester_id=current_user.id)
        report_location = None
        if participant and participant.report_latitude is not None and participant.report_longitude is not None:
            report_location = schemas.LocationInfo(lat=participant.report_latitude, lng=participant.report_longitude)

        return schemas.QuestCompletionReportResponse(
            quest_id=quest.id,
            title=quest.title,
            completed_at=quest.completed_at,
            requester=schemas.AuthorInfo(
                id=quest.requester.id,
                username=quest.requester.username,
                icon_url=quest.requester.icon_url,
            ),
            walker=(
                schemas.AuthorInfo(
                    id=participant.walker.id,
                    username=participant.walker.username,
                    icon_url=participant.walker.icon_url,
                )
                if participant and participant.walker
                else None
            ),
            photo_url=participant.photo_url if participant else None,
            comment=participant.comment if participant else None,
            reported_at=participant.reported_at if participant else None,
            report_location=report_location,
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Quest not found") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden") from None
    except Exception:
        logger.exception("Failed to get quest completion report")
        raise HTTPException(status_code=500, detail="Failed to get completion report") from None


@app.get("/notifications", response_model=List[schemas.NotificationResponse])
def list_notifications(
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
    unread_only: bool = Query(False),
    limit: int = Query(100, ge=1, le=200),
):
    """ユーザーの通知一覧を取得（クエスト完了通知など）"""
    notifications = crud.list_notifications(db, user_id=current_user.id, limit=limit, unread_only=unread_only)
    return [
        schemas.NotificationResponse(
            id=n.id,
            type=schemas.NotificationType(n.type.value),
            title=n.title,
            body=n.body,
            quest_id=n.quest_id,
            created_at=n.created_at,
            read_at=n.read_at,
        )
        for n in notifications
    ]


@app.post("/notifications/{notification_id}/read", response_model=schemas.NotificationResponse)
def mark_notification_read(
    notification_id: UUID,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
    db: Session = Depends(get_db),
):
    """通知を既読にする"""
    try:
        n = crud.mark_notification_read(db, notification_id=notification_id, user_id=current_user.id)
        return schemas.NotificationResponse(
            id=n.id,
            type=schemas.NotificationType(n.type.value),
            title=n.title,
            body=n.body,
            quest_id=n.quest_id,
            created_at=n.created_at,
            read_at=n.read_at,
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Notification not found") from None
    except Exception:
        logger.exception("Failed to mark notification read")
        raise HTTPException(status_code=500, detail="Failed to update notification") from None


@app.post("/ai/quest-draft", response_model=schemas.AiQuestDraftResponse)
def ai_quest_draft(
    payload: schemas.AiQuestDraftRequest,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
):
    """クエスト作成のタイトル/説明文をAIで下書き生成"""
    system = (
        "あなたは『Numyp』という地図アプリのAIアシスタントです。"
        "ユーザーが作成する『調査依頼(クエスト)』のタイトルと説明文を日本語で下書きします。"
        "出力は必ずJSONのみで、他の文章は一切出さないでください。"
        'フォーマット: {"title":"...","description":"..."}。'
        "titleは80文字以内、descriptionは500文字以内。"
        "現地の状況確認を依頼する文脈で、丁寧で具体的に。"
        "緯度経度から住所や個人情報を推測しない。"
    )

    hint = payload.hint or ""
    current_title = payload.current_title or ""
    current_description = payload.current_description or ""
    user = (
        f"位置: lat={payload.lat}, lng={payload.lng}\n"
        f"ユーザーのヒント: {hint}\n"
        f"現在入力されているタイトル: {current_title}\n"
        f"現在入力されている説明: {current_description}\n"
        "上記を踏まえて、短く分かりやすい下書きを作って。"
    )

    content = _ollama_chat(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.6,
    )

    try:
        obj = _extract_json_object(content)
        title = str(obj.get("title") or "").strip()
        description = str(obj.get("description") or "").strip()
        if not title or not description:
            raise ValueError("Missing title/description")
        return schemas.AiQuestDraftResponse(title=title, description=description)
    except Exception:
        logger.info("AI quest draft parse failed: %s", content)
        raise HTTPException(status_code=502, detail="Failed to parse AI response") from None


@app.post("/ai/spot-draft", response_model=schemas.AiSpotDraftResponse)
def ai_spot_draft(
    payload: schemas.AiSpotDraftRequest,
    current_user: Annotated[models.User, Depends(get_current_user_model)],
):
    """スポット説明文をAIで下書き生成"""
    system = (
        "あなたは『Numyp』という地図アプリのAIアシスタントです。"
        "ユーザーが作成する『スポット』の説明文を日本語で下書きします。"
        "出力は必ずJSONのみで、他の文章は一切出さないでください。"
        'フォーマット: {"description":"..."}。'
        "descriptionは200文字以内。"
        "誇張しすぎず、行く価値が分かる要点を1〜3文で。"
        "緯度経度から住所や個人情報を推測しない。"
    )

    hint = payload.hint or ""
    current_description = payload.current_description or ""
    user = (
        f"スポット名(タイトル): {payload.title}\n"
        f"位置: lat={payload.lat}, lng={payload.lng}\n"
        f"ユーザーのヒント: {hint}\n"
        f"現在の説明: {current_description}\n"
        "上記を踏まえて、短い説明文の下書きを作って。"
    )

    content = _ollama_chat(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.6,
    )

    try:
        obj = _extract_json_object(content)
        description = str(obj.get("description") or "").strip()
        if not description:
            raise ValueError("Missing description")
        return schemas.AiSpotDraftResponse(description=description)
    except Exception:
        logger.info("AI spot draft parse failed: %s", content)
        raise HTTPException(status_code=502, detail="Failed to parse AI response") from None

# uvicorn main:app --reload
# uvicorn main:app --host 0.0.0.0 --port 8000
