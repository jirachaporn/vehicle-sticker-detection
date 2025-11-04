# router_camera.py  — memory-only capture (no disk writes)
import os
import io
import cv2
import time
import uuid
import numpy as np
import requests
from typing import List, Dict, Any
from dotenv import load_dotenv
from ultralytics import YOLO
from fastapi import APIRouter, Form, HTTPException

router = APIRouter()
load_dotenv()

# === ENV / CONFIG ===
MODEL_PATH = os.getenv("CAR_DETECTION_PATH")
API_BASE_URL = (os.getenv("API_BASE_URL") or "").rstrip("/")
CAR_CONF = float(os.getenv("CAR_DETECTION_CONF", "0.50"))
IOU_MATCH = float(os.getenv("CAR_TRACK_IOU", "0.30"))
CAPTURE_DELAY = float(os.getenv("CAR_CAPTURE_DELAY_SEC", "3.0"))   # รอ 3 วิ เมื่อรถเข้าเฟรม
TRACK_TTL = float(os.getenv("CAR_TRACK_TTL_SEC", "3"))           # ลบ track ถ้าหายไปเกินนี้
INFER_EVERY = int(os.getenv("CAR_INFER_EVERY_N_FRAMES", "1"))      # ตรวจทุกกี่เฟรม เพื่อลดโหลด
CAR_STREAM_MAX_RUNTIME_SEC = int(os.getenv("CAR_STREAM_MAX_RUNTIME_SEC", "0"))   # 0 = ไม่จำกัดเวลา
CAR_STREAM_MAX_CAPTURES = int(os.getenv("CAR_STREAM_MAX_CAPTURES", "0"))         # 0 = ไม่จำกัดจำนวนแคป
CAR_FORWARD_TO_DETECT = (os.getenv("CAR_FORWARD_TO_DETECT", "true").lower() == "true")

model = None
if MODEL_PATH and os.path.exists(MODEL_PATH):
    print(f"Loading YOLO model from: {MODEL_PATH}")
    model = YOLO(MODEL_PATH)
    print("✅ YOLO model loaded successfully!")
else:
    print("⚠️ CAR_DETECTION_PATH not found or invalid:", MODEL_PATH)

def _now() -> float:
    return time.time()

def _iou(boxA, boxB) -> float:
    # box = [x1,y1,x2,y2]
    xA = max(boxA[0], boxB[0])
    yA = max(boxA[1], boxB[1])
    xB = min(boxA[2], boxB[2])
    yB = min(boxA[3], boxB[3])
    inter = max(0, xB - xA) * max(0, yB - yA)
    areaA = max(0, boxA[2] - boxA[0]) * max(0, boxA[3] - boxA[1])
    areaB = max(0, boxB[2] - boxB[0]) * max(0, boxB[3] - boxB[1])
    union = areaA + areaB - inter if (areaA + areaB - inter) > 0 else 1e-6
    return inter / union

def _open_source(source: str) -> cv2.VideoCapture:
    if source.isdigit():
        cap = cv2.VideoCapture(int(source))
    else:
        cap = cv2.VideoCapture(source)
    return cap

def _detect_cars(image_bgr: np.ndarray, conf: float) -> List[Dict[str, Any]]:
    if model is None:
        raise RuntimeError("YOLO model not loaded")

    results = model(image_bgr, conf=conf, verbose=False)
    dets: List[Dict[str, Any]] = []
    for result in results:
        for box in result.boxes:
            c = float(box.conf[0])
            xyxy = box.xyxy[0].tolist()
            dets.append({
                "bbox": [float(xyxy[0]), float(xyxy[1]), float(xyxy[2]), float(xyxy[3])],
                "conf": c
            })
    return dets

def _match_tracks(tracks: Dict[str, dict], dets: List[Dict[str, Any]], iou_thr: float) -> None:
    now = _now()
    used = set()

    for tid, tinfo in list(tracks.items()):
        best_idx, best_iou = -1, 0.0
        for i, d in enumerate(dets):
            if i in used:
                continue
            iou = _iou(tinfo["bbox"], d["bbox"])
            if iou > best_iou:
                best_iou, best_idx = iou, i
        if best_idx >= 0 and best_iou >= iou_thr:
            tinfo["bbox"] = dets[best_idx]["bbox"]
            tinfo["last_seen"] = now
            used.add(best_idx)

    # สร้าง track ใหม่
    for i, d in enumerate(dets):
        if i in used:
            continue
        tid = str(uuid.uuid4())[:8]
        tracks[tid] = {
            "bbox": d["bbox"],
            "first_seen": now,
            "last_seen": now,
            "captured": False}

    # ลบ track ที่หายไปนานเกิน TTL
    for tid, tinfo in list(tracks.items()):
        if now - tinfo["last_seen"] > TRACK_TTL:
            del tracks[tid]

###################################################################################
@router.post("/car-detect")
def car_capture_stream(
    source: str = Form(...),     # "0" (webcam) หรือ path/URL วิดีโอ
    location_id: str = Form(...),
    model_id: str = Form(...),
    direction: str = Form("in"),
):
    if model is None:
        raise HTTPException(status_code=500, detail="YOLO model not loaded or model path invalid")

    cap = _open_source(source)
    if not cap.isOpened():
        return {"ok": False, "error": f"Cannot open source: {source}"}

    tracks: Dict[str, dict] = {}
    start = _now()
    frame_idx = 0
    saved: List[Dict[str, Any]] = []

    # ลิมิตจาก ENV (0 = ไม่จำกัด)
    runtime_limit = CAR_STREAM_MAX_RUNTIME_SEC if CAR_STREAM_MAX_RUNTIME_SEC > 0 else None
    captures_limit = CAR_STREAM_MAX_CAPTURES if CAR_STREAM_MAX_CAPTURES > 0 else None

    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                break

            frame_idx += 1
            now = _now()

            # หยุดตามเวลา (ถ้ากำหนดใน ENV)
            if runtime_limit and (now - start >= runtime_limit):
                break
            # หยุดตามจำนวน capture (ถ้ากำหนดใน ENV)
            if captures_limit and (len(saved) >= captures_limit):
                break

            # ลดโหลด: ข้ามบางเฟรมได้
            if frame_idx % INFER_EVERY != 0:
                continue

            # 1) ตรวจจับรถในเฟรมนี้
            dets = _detect_cars(frame, CAR_CONF)

            # 2) อัปเดต/สร้าง tracks ด้วย IoU
            _match_tracks(tracks, dets, IOU_MATCH)

            # 3) รอครบ CAPTURE_DELAY แล้วค่อย "จับภาพในหน่วยความจำ"
            for tid, tinfo in list(tracks.items()):
                if tinfo.get("captured"):
                    continue

                if now - tinfo["first_seen"] >= CAPTURE_DELAY:
                    # encode เฟรมเป็น JPEG ในหน่วยความจำ
                    ok, buf = cv2.imencode(".jpg", frame)
                    if not ok:
                        continue
                    jpg_bytes = buf.tobytes()

                    ts = time.strftime("%Y%m%d_%H%M%S")
                    filename = f"{ts}_{tid}.jpg"

                    forwarded = False
                    status = None

                    # ส่งเข้า /detect เป็น bytes ทันที
                    if API_BASE_URL and CAR_FORWARD_TO_DETECT:
                        try:
                            resp = requests.post(
                                f"{API_BASE_URL}/detect",
                                data={
                                    "location_id": location_id,
                                    "model_id": model_id,
                                    "direction": direction,
                                },
                                files={"file": (filename, io.BytesIO(jpg_bytes), "image/jpeg")},
                                timeout=300,
                            )
                            forwarded = True
                            status = resp.status_code
                            if status == 200:
                                print("✅ ส่งภาพไปยัง /detect สำเร็จ")
                            else:
                                print(f"⚠️ ส่งภาพไปยัง /detect ไม่สำเร็จ: {status}")
                        except Exception as e:
                            status = f"error: {e}"
                            print(f"❌ Error calling /detect: {e}")

                    saved.append({
                        "track_id": tid,
                        "filename": filename,
                        "in_memory": True,
                        "forwarded": forwarded,
                        "status": status,
                        "at": time.strftime("%Y-%m-%d %H:%M:%S"),
                    })

                    tinfo["captured"] = True

            for tid, tinfo in list(tracks.items()):
                if now - tinfo["last_seen"] > TRACK_TTL:
                    del tracks[tid]

    finally:
        cap.release()

    return {
        "ok": True,
        "source": source,
        "captures_count": len(saved),
        "captures": saved,
    }