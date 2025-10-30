# api_service/camera.py
import os
import base64
import cv2
import numpy as np
from dotenv import load_dotenv
from ultralytics import YOLO

# โหลดตัวแปรจาก .env
load_dotenv()

MODEL_PATH = os.getenv("CET_DETECTION_PATH")

# โหลดโมเดล YOLO สำหรับ /car-detect
model = None
if MODEL_PATH and os.path.exists(MODEL_PATH):
    print(f"Loading YOLO model from: {MODEL_PATH}")
    model = YOLO(MODEL_PATH)
    print("✅ YOLO model loaded successfully!")
else:
    print("⚠️ Model path not found or invalid:", MODEL_PATH)

def detect_vehicle(image_base64: str):
    """ตรวจจับยานพาหนะจาก base64"""
    if not model:
        raise RuntimeError("YOLO model not loaded")

    image_data = base64.b64decode(image_base64.split(",")[1] if "," in image_base64 else image_base64)
    nparr = np.frombuffer(image_data, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    results = model(image, conf=0.5)

    detections = []
    for result in results:
        boxes = result.boxes
        for box in boxes:
            detections.append({
                "class": int(box.cls[0]),
                "confidence": float(box.conf[0]),
                "bbox": box.xyxy[0].tolist(), 
            })

    return {
        "success": True,
        "detections": detections,
        "count": len(detections),
    }


# Streaming กล้องปกติ
CAMERAS = {}

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
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

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
