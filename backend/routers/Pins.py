from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Query
import os
import uuid
from typing import List, Annotated, Optional
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
import crud
from jose import JWTError, jwt
from fastapi.security import OAuth2PasswordBearer
from dotenv import load_dotenv
from io import BytesIO
from r2_storage import get_r2_storage

load_dotenv()

# --- Auth Helper Duplication Start ---
# Duplicated from main.py to avoid circular imports and file creation restrictions.
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        if not SECRET_KEY:
             raise RuntimeError("SECRET_KEY must be set in environment")
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception from None
    
    user = crud.get_user_by_id(db, uuid.UUID(user_id))
    if user is None:
        raise credentials_exception
    
    return schemas.AuthorInfo(
        id=user.id,
        username=user.username,
        icon_url=user.icon_url
    )
# --- Auth Helper Duplication End ---


router = APIRouter(prefix="/pins", tags=["pins"])

@router.post("/upload")
async def upload_pin_image(
    current_user: Annotated[schemas.AuthorInfo, Depends(get_current_user)],
    file: UploadFile = File(...),
):
    if not file.filename:
         raise HTTPException(status_code=400, detail="Filename is missing")

    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/webp", "image/gif"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed types: {', '.join(allowed_types)}"
        )

    # Validate file size (10MB limit)
    max_size = 10 * 1024 * 1024
    try:
        file_content = await file.read()
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to read file")

    if len(file_content) > max_size:
        raise HTTPException(status_code=400, detail="File size exceeds 10MB limit")

    try:
        r2_storage = get_r2_storage()
        # Use UUID to ensure safe filename
        ext = os.path.splitext(file.filename)[1]
        if not ext:
            # Fallback extension from content-type if missing
            ext_map = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "image/gif": ".gif"}
            ext = ext_map.get(file.content_type, ".jpg")
            
        safe_filename = f"{uuid.uuid4()}{ext}"
        
        image_url = r2_storage.upload_file(
            file_data=BytesIO(file_content),
            filename=safe_filename,
            content_type=file.content_type,
            folder="pins"
        )
        
        return {
            "image_url": image_url
        }
    except Exception as e:
        # logging.exception("Failed to upload pin image") # logger not setup here, skipping
        raise HTTPException(status_code=500, detail="Failed to upload image")

@router.get("/", response_model=List[schemas.PinResponse])
def read_pins(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    pins = db.query(models.Pin).offset(skip).limit(limit).all()
    return pins

@router.post("/", response_model=schemas.PinResponse)
def create_pin(pin: schemas.PinCreate, db: Session = Depends(get_db)):
    try:
        db_pin = models.Pin(
            name=pin.name,
            description=pin.description,
            pricd=pin.price,
            image_url=pin.image_url
        )
        db.add(db_pin)
        db.commit()
        db.refresh(db_pin)
        return db_pin
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create pin")
    
