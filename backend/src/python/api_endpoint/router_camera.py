import os
import io
import cv2
import numpy as np
import requests
from dotenv import load_dotenv
from ultralytics import YOLO
from fastapi import UploadFile, File, Form, APIRouter
from PIL import Image

router = APIRouter()
load_dotenv()

MODEL_PATH = os.getenv("CET_DETECTION_PATH")
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
    location_id: str = Form(...),
    model_id: str = Form(...),
    direction: str = Form("in"),
):
    """ตรวจจับรถจากภาพ และส่งต่อไปยัง /detect เฉพาะเมื่อเจอ car"""
    if not model:
        raise RuntimeError("YOLO model not loaded")

    print("location_id",location_id)
    print("model_id",model_id)
    print("direction",direction)
    
    
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)

    results = model(image_cv, conf=0.5)
    detections = []
    for result in results:
        for box in result.boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])
            bbox = box.xyxy[0].tolist()
            cls_name = model.names.get(cls_id, "Unknown")
            detections.append({
                "class": cls_id,
                "class_name": cls_name,
                "confidence": conf,
                "bbox": bbox,
            })

    cars = [d for d in detections if d["class_name"].lower() == "car"]
    if cars:
        print(f"🚗 [car-detect] พบ {len(cars)} car: {[c['class_name'] for c in cars]} จาก {file.filename}")
        if API_BASE_URL:
            try:
                response = requests.post(
                    f"{API_BASE_URL}/detect",
                    data={
                        "location_id": location_id,
                        "model_id": model_id,
                        "direction": direction,
                    },
                    files={"file": (file.filename, image_bytes, "image/jpeg")},
                    timeout=300,
                )
                if response.status_code == 200:
                    print("✅ ส่งภาพไปยัง /detect สำเร็จ")
                else:
                    print(f"⚠️ ส่งภาพไปยัง /detect ไม่สำเร็จ: {response.status_code}")
            except Exception as e:
                print(f"❌ Error calling /detect: {e}")
        else:
            print("⚠️ API_BASE_URL ไม่ได้ตั้งค่า. ข้ามการส่งไป /detect")
    else:
        pass

    return {
        "success": True,
        "detections": detections,
        "count": len(detections),
    }
