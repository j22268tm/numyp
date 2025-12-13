from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
import os
import uuid
from typing import List
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas

router = APIRouter(prefix="/pins", tags=["pins"])

UPLOAD_DIR = "static/pins"

@router.post("/upload")
async def upload_pin_image(file: UploadFile = File(...)):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid.uuid4()}{ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as f:
        f.write(await file.read())

    return {
        "image_url": f"/static/pins/{filename}"
    }

@router.get("/", response_model=List[schemas.PinResponse])
def read_pins(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    pins = db.query(models.Pin).offset(skip).limit(limit).all()
    return pins

@router.post("/", response_model=schemas.PinResponse)
def create_pin(pin: schemas.PinCreate, db: Session = Depends(get_db)):
    db_pin = models.Pin(
        name=pin.name,
        description=pin.description,
        price=pin.price,
        image_url=pin.image_url
    )
    db.add(db_pin)
    db.commit()
    db.refresh(db_pin)
    return db_pin
