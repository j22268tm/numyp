from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import List, Optional
from datetime import datetime
import schemas

app = FastAPI(
    title="Numyp API",
    description="API for Numyp",
    version="1.0.0"
)


# CORS
# ハッカソン用なので全許可 ("*") 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Dummy Data fakedb
fake_spots_db = []
fake_user_db = {
    "username": "walker_tk",
    "coins": 1500,
    "skin_id": 1
}

# 認証のフリをするための設定（実際は何もチェックしない）
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# 共通処理
def get_current_user(token: str = Depends(oauth2_scheme)):
    # 本来はJWTトークンを解析してユーザーIDを取り出す
    # ダミーユーザーを返す
    return schemas.AuthorInfo(
        id=42,
        username=fake_user_db["username"],
        icon_url="https://via.placeholder.com/150"
    )


# Endpoints
@app.get("/")
def read_root():
    return {"message": "Welcome to Numyp API! Go to /docs to see Swagger UI."}

# Auth
@app.post("/auth/signup")
def signup(user: schemas.UserCreate):
    return {"message": f"User {user.username} created successfully"}

@app.post("/auth/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    # パスワードチェックは省略
    return {
        "access_token": "fake-jwt-token-for-hackathon",
        "token_type": "bearer"
    }


# Spots
@app.get("/spots", response_model=List[schemas.SpotResponse])
def get_spots(lat: Optional[float] = None, lng: Optional[float] = None, radius: Optional[float] = None):
    """
    Map表示用 スポット一覧を返す あえて情報量は少なめにしてます
    """
    # dummy data
    if not fake_spots_db:
        return [
            schemas.SpotResponse(
                id=101,
                created_at=datetime.now(),
                location=schemas.LocationInfo(lat=35.6895, lng=139.6917),
                content=schemas.ContentInfo(title="ハチ公前", description=None, image_url="https://via.placeholder.com/50"),
                status=schemas.SpotStatus(crowd_level=schemas.CrowdLevel.HIGH, rating=3),
                author=schemas.AuthorInfo(id=99, username="admin"),
                skin=schemas.SkinInfo(id=1, name="Default Pin", image_url="https://via.placeholder.com/50")
            )
        ]
    
    # 実際はSQLで必要なカラムだけSELECTするのが正解
    lightweight_spots = []
    for spot in fake_spots_db:
        # Pydanticのcopyメソッドを使ってオブジェクトを複製し、重いフィールドを削ぐ
        spot_lite = spot.model_copy(update={
            "content": spot.content.model_copy(update={"description": None}) 
        })
        lightweight_spots.append(spot_lite)
        
    return lightweight_spots

@app.get("/spots/{spot_id}", response_model=schemas.SpotResponse)
def get_spot_detail(spot_id: int):
    """
    詳細表示用 特定のスポットの全情報を返す。
    ピンをタップした後に呼ばれるAPI。
    """
    # dummy data
    if spot_id == 101 and not fake_spots_db:
         return schemas.SpotResponse(
                id=101,
                created_at=datetime.now(),
                location=schemas.LocationInfo(lat=35.6895, lng=139.6917),
                content=schemas.ContentInfo(
                    title="ハチ公前", 
                    description="ここは詳細画面なので、長文の説明や高解像度の画像URLが含まれます。", 
                    image_url="https://via.placeholder.com/300"
                ),
                status=schemas.SpotStatus(crowd_level=schemas.CrowdLevel.HIGH, rating=3),
                author=schemas.AuthorInfo(id=99, username="admin"),
                skin=schemas.SkinInfo(id=1, name="Default Pin", image_url="https://via.placeholder.com/50")
            )

    # from memory DB
    found_spot = next((s for s in fake_spots_db if s.id == spot_id), None)
    if not found_spot:
        raise HTTPException(status_code=404, detail="Spot not found")
    
    return found_spot

@app.post("/spots", response_model=schemas.SpotResponse)
def create_spot(
    spot: schemas.SpotCreate,
    current_user: schemas.AuthorInfo = Depends(get_current_user)
):
    """
    スポットを作成する。
    入力はフラット出力はネストされた構造にBackend側で変換して保存
    """
    new_spot = schemas.SpotResponse(
        id=len(fake_spots_db) + 102,
        created_at=datetime.now(),
        
        location=schemas.LocationInfo(
            lat=spot.lat, 
            lng=spot.lng
        ),
        content=schemas.ContentInfo(
            title=spot.title, 
            description=spot.description,
            image_url="https://via.placeholder.com/300"
        ),
        status=schemas.SpotStatus(
            crowd_level=spot.crowd_level, 
            rating=spot.rating
        ),
        author=current_user,
        skin=schemas.SkinInfo(
            id=fake_user_db["skin_id"], 
            name="My Current Skin", 
            image_url="https://via.placeholder.com/50"
        )
    )

    # save to memory DB
    fake_spots_db.append(new_spot)

    # otamesi
    fake_user_db["coins"] += 10

    return new_spot


# Users
@app.get("/users/me", response_model=schemas.UserResponse)
def read_users_me(current_user: schemas.AuthorInfo = Depends(get_current_user)):
    return schemas.UserResponse(
        id=current_user.id,
        username=current_user.username,
        icon_url=current_user.icon_url,
        wallet=schemas.UserWallet(coins=fake_user_db["coins"]),
        current_skin=schemas.SkinInfo(id=1, name="Default Pin", image_url="https://via.placeholder.com/50")
    )

@app.post("/shop/buy")
def buy_item(request: schemas.BuyItemRequest, current_user: schemas.AuthorInfo = Depends(get_current_user)):
    item_price = 100
    if fake_user_db["coins"] < item_price:
        raise HTTPException(status_code=400, detail="Not enough coins")
    
    fake_user_db["coins"] -= item_price
    return {"success": True, "remaining_coins": fake_user_db["coins"], "message": f"Item {request.item_id} purchased!"}

# uvicorn main:app --reload