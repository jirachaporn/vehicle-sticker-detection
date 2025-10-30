# api_service/camera.py
import os
import cv2
import numpy as np
from dotenv import load_dotenv
from ultralytics import YOLO
from fastapi import UploadFile
from PIL import Image
import io

# โหลดตัวแปรจาก .env
load_dotenv()

MODEL_PATH = os.getenv("CET_DETECTION_PATH")
CAMERAS = {}

# โหลดโมเดล YOLO สำหรับ /car-detect
model = None
if MODEL_PATH and os.path.exists(MODEL_PATH):
    print(f"Loading YOLO model from: {MODEL_PATH}")
    model = YOLO(MODEL_PATH)
    print("✅ YOLO model loaded successfully!")
else:
    print("⚠️ Model path not found or invalid:", MODEL_PATH)


async def detect_vehicle(file: UploadFile):
    """ตรวจจับยานพาหนะจากไฟล์ภาพ UploadFile"""
    if not model:
        raise RuntimeError("YOLO model not loaded")

    print(f"🚗 [detect_vehicle] รับภาพมาจาก Flutter แล้ว: {file.filename}")

    # อ่านภาพจาก UploadFile
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)

    # ตรวจจับด้วย YOLO
    results = model(image_cv, conf=0.5)

    detections = []
    for result in results:
        boxes = result.boxes
        for box in boxes:
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

    # log สรุปผลลัพธ์
    if detections:
        print(f"✅ พบ {len(detections)} วัตถุ: {[d['class_name'] for d in detections]}")
    else:
        print("❌ ไม่พบวัตถุในภาพนี้")

    return {
        "success": True,
        "filename": file.filename,
        "detections": detections,
        "count": len(detections),
    }


def stream_camera(camera_id: int):
    """Generator สำหรับ StreamingResponse ของ FastAPI"""
    if camera_id not in CAMERAS:
        cap = cv2.VideoCapture(camera_id)
        if not cap.isOpened():
            return None
        CAMERAS[camera_id] = cap
    else:
        cap = CAMERAS[camera_id]

    def gen():
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            ret, buffer = cv2.imencode('.jpg', frame)
            frame_bytes = buffer.tobytes()
            yield (
                b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n'
            )

    return gen()


def check_available_cameras():
    """ตรวจสอบกล้องที่เชื่อมต่อและเปิดได้"""
    available = []
    for i in range(5):  # ลองเช็คกล้อง 0-4
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            available.append({"camera_id": i})
            cap.release()
    return available if available else None
