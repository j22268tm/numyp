from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import List, Optional, Annotated
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
import schemas
import crud
import models
from database import engine, get_db
from uuid import uuid4, UUID
from jose import JWTError, jwt
import os
from dotenv import load_dotenv

# 環境変数を読み込み
load_dotenv()

# JWT設定
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# データベースのテーブルを作成
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Numyp API",
    description="API for Numyp",
    version="1.0.0"
)


# CORS
# ハッカソン用,開発環境のオリジンを許可
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:3000"],
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
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


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
        raise credentials_exception
    
    user = crud.get_user_by_id(db, UUID(user_id))
    if user is None:
        raise credentials_exception
    
    # AuthorInfo形式で返す
    return schemas.AuthorInfo(
        id=user.id,
        username=user.username,
        icon_url=user.icon_url
    )


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
    
    # ユーザーを作成
    new_user = crud.create_user(db, user)
    return {"message": f"User {new_user.username} created successfully"}

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
    
    # レスポンス形式に変換
    spots_response = []
    for spot in db_spots:
        # 軽量化のため description は None にする
        spots_response.append(schemas.SpotResponse(
            id=spot.id,
            created_at=spot.created_at,
            location=schemas.LocationInfo(lat=spot.latitude, lng=spot.longitude),
            content=schemas.ContentInfo(
                title=spot.title,
                description=None,  # 軽量化
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
        ))
    
    return spots_response


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
    
    # レスポンス形式に変換
    return schemas.SpotResponse(
        id=spot.id,
        created_at=spot.created_at,
        location=schemas.LocationInfo(lat=spot.latitude, lng=spot.longitude),
        content=schemas.ContentInfo(
            title=spot.title,
            description=spot.description,  # 詳細では description も含める
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

@app.post("/spots", response_model=schemas.SpotResponse)
def create_spot(
    spot: schemas.SpotCreate,
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    スポットを作成する。
    入力はフラット出力はネストされた構造にBackend側で変換して保存
    """
    # データベースにスポットを作成
    new_spot = crud.create_spot(db, spot, current_user.id)
    
    # レスポンス形式に変換
    return schemas.SpotResponse(
        id=new_spot.id,
        created_at=new_spot.created_at,
        location=schemas.LocationInfo(lat=new_spot.latitude, lng=new_spot.longitude),
        content=schemas.ContentInfo(
            title=new_spot.title,
            description=new_spot.description,
            image_url=new_spot.image_url,
        ),
        status=schemas.SpotStatus(
            crowd_level=schemas.CrowdLevel(new_spot.crowd_level.value),
            rating=new_spot.rating
        ),
        author=schemas.AuthorInfo(
            id=new_spot.author.id,
            username=new_spot.author.username,
            icon_url=new_spot.author.icon_url
        ),
        skin=schemas.SkinInfo(
            id=new_spot.skin.id,
            name=new_spot.skin.name,
            image_url=new_spot.skin.image_url
        )
    )


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
        
        if not skin:
            raise HTTPException(status_code=404, detail="Item not found")
        if crud.user_owns_skin(db, current_user.id, request.item_id):
            raise HTTPException(status_code=400, detail="Already owned")
        if user.coins < skin.price:
            raise HTTPException(status_code=400, detail="Not enough coins")
        
        raise HTTPException(status_code=400, detail="Purchase failed")
    
    # 更新後のコイン残高を取得
    user = crud.get_user_by_id(db, current_user.id)
    
    return {
        "success": True,
        "remaining_coins": user.coins,
        "message": f"Item {request.item_id} purchased!"
    }

# uvicorn main:app --reload