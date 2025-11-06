import os
import io
import cv2
import numpy as np
import requests
from dotenv import load_dotenv
from ultralytics import YOLO
from fastapi import HTTPException, UploadFile, File, Form, APIRouter
from PIL import Image

router = APIRouter()
load_dotenv()

MODEL_PATH = os.getenv("CAR_DETECTION_PATH")
API_BASE_URL = os.getenv("API_BASE_URL")

model = None
if MODEL_PATH and os.path.exists(MODEL_PATH):
    print(f"Loading YOLO model from: {MODEL_PATH}")
    model = YOLO(MODEL_PATH)
    print("✅ YOLO model loaded successfully!")
else:
    print("⚠️ Model path not found or invalid:", MODEL_PATH)


@router.post("/car-detect")
async def detect_vehicle_route(
    file: UploadFile = File(...),
):
    """ตรวจจับรถจากภาพ -> ถ้าเจอส่ง 200 ถ้าไม่เจอส่ง 204"""
    if not model:
        raise RuntimeError("YOLO model not loaded")

    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)

    results = model(image_cv, conf=0.5)

    for result in results:
        for box in result.boxes:
            cls_name = model.names.get(int(box.cls[0]), "Unknown").lower()
            if cls_name == "car":
                print("✅พบรถ")
                return {"status": "car_detected"}

    print("😡ไม่พบรถ")
    raise HTTPException(status_code=204, detail="no_car")