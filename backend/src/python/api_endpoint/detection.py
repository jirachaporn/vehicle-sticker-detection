# src/python/api_endpoint/detection.py
from fastapi import APIRouter, File, UploadFile, HTTPException, Form
from typing import Literal
from ..utils.cloudinary_uploader import CloudinaryUploader
# from ..utils.sticker_detector import get_sticker_detector
from ..api_service.ai4thai_ocr_LP_api import recognize_license_plate
from ..utils.processor import insert_detection_payload
from ..utils.sticker_model_loader import get_yolo_model_for_location, detect_sticker_from_bytes
from ..api_service.notifications_service import create_from_detection
from ..utils.sticker_model_loader import resolve_model_local_path_for_location
import os, asyncio, numpy as np, cv2
from concurrent.futures import ProcessPoolExecutor
from fastapi.concurrency import run_in_threadpool

router = APIRouter()

EXECUTOR = ProcessPoolExecutor(max_workers=int(os.getenv("YOLO_WORKERS", "1")))

def _yolo_predict_bytes(image_bytes: bytes, model_path: str, conf: float, iou: float) -> dict:
    from ultralytics import YOLO
    import numpy as np, cv2

    npbuf = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(npbuf, cv2.IMREAD_COLOR)
    if img is None:
        return {"is_sticker": False, "count": 0, "confident": 0.0}

    model = YOLO(model_path)
    results = model.predict(img, verbose=False, conf=conf, iou=iou)
    cnt, confs = 0, []
    if results:
        r = results[0]
        # เดินทุก box แล้วนับตัวที่ผ่าน conf (กัน edge case)
        for b in r.boxes:
            c = float(b.conf[0].item())
            if c >= conf:
                cnt += 1
                confs.append(c)

    return {
        "is_sticker": cnt > 0,
        "count": cnt,
        "confident": max(confs) if confs else 0.0
    }

@router.post("/detect")
async def detect(
    file: UploadFile = File(...),
    location_id: str = Form(...),
    model_id: str = Form(...),
    direction: Literal["in", "out"] = Form("in"),
):
    try:
        # 1) รับไฟล์เป็น bytes
        image_bytes = await file.read()

        # 2) อัปโหลดขึ้น Cloudinary -> ใช้ threadpool กันบล็อก event loop
        uploader = CloudinaryUploader()
        image_url = await run_in_threadpool(uploader.upload_bytes, image_bytes, folder="detection")

        # 3) เตรียมค่า YOLO + หาพาธโมเดลของ location
        model_path = resolve_model_local_path_for_location(location_id)
        conf = float(os.getenv("STICKER_CONF", "0.50"))
        iou  = float(os.getenv("STICKER_IOU", "0.50"))

        # 4) เรียก YOLO ผ่าน ProcessPoolExecutor (multiprocessing)
        loop = asyncio.get_running_loop()
        sticker = await loop.run_in_executor(
            EXECUTOR, _yolo_predict_bytes, image_bytes, model_path, conf, iou
        )

        # 5) OCR (ใช้ threadpool)
        ocr = await run_in_threadpool(recognize_license_plate, image_url)

        # 6) ประกอบ payload + บันทึกลง DB (ใช้ threadpool)
        payload = {
            "location_id": location_id,
            "model_id": model_id,
            "image_path": [image_url],
            "detected_plate": ocr,
            "direction": direction,
            "is_sticker": bool(sticker["is_sticker"]),
            "sticker_result": sticker,  # เก็บไว้ใน meta ถ้าต้องการ
        }
        
        inserted_resp = await run_in_threadpool(insert_detection_payload, payload)
        inserted_row = None
        if hasattr(inserted_resp, "data"):
            data = inserted_resp.data or []
            inserted_row = data[0] if isinstance(data, list) and data else data
        elif isinstance(inserted_resp, dict) and "data" in inserted_resp:
            data = inserted_resp["data"] or []
            inserted_row = data[0] if isinstance(data, list) and data else data
        elif isinstance(inserted_resp, list):
            inserted_row = inserted_resp[0] if inserted_resp else None
        else:
            inserted_row = inserted_resp  # เผื่อฟังก์ชันของคุณคืน row ตรง ๆ

        if not inserted_row:
            raise HTTPException(status_code=500, detail="Insertion returned empty data")

        # ถ้าฟังก์ชันสร้าง notification ต้องใช้ detections_id ให้ส่ง inserted_row เข้าไป
        notif_resp = await run_in_threadpool(create_from_detection, inserted_row)

        return {
            "ok": True,
            "detection": inserted_row,
            "notification": getattr(notif_resp, "data", notif_resp),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")