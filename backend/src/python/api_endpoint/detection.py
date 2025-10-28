# src/python/api_endpoint/detection.py
from fastapi import APIRouter, File, UploadFile, HTTPException, Form
from typing import Literal
from ..utils.cloudinary_uploader import CloudinaryUploader
# from ..utils.sticker_detector import get_sticker_detector
from ..api_service.ai4thai_ocr_LP_api import recognize_license_plate
from ..utils.processor import insert_detection_payload
from ..utils.sticker_model_loader import get_yolo_model_for_location, detect_sticker_from_bytes
from ..api_service.notifications_service import create_from_detection

router = APIRouter()

@router.post("/detect")
async def detect(
    file: UploadFile = File(...),
    location_id: str = Form(...),
    model_id: str = Form(...),
    direction: Literal["in", "out"] = Form("in"),
):
    try:
        # 1) อ่านไฟล์
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty file.")

        # 2) อัป Cloudinary ได้ URL
        uploader = CloudinaryUploader()
        image_url = uploader.upload_bytes(image_bytes, folder="detection")
        if not image_url:
            raise HTTPException(status_code=500, detail="Upload to Cloudinary failed (no secure_url).")

        # 3) ตรวจสติกเกอร์ 
        # detector = get_sticker_detector()
        # sticker = detector.detect_from_bytes(image_bytes)
        # is_sticker = bool(sticker.get("is_sticker", False))
        
        # แก้ใหม่
        model = get_yolo_model_for_location(location_id)          
        sticker = detect_sticker_from_bytes(image_bytes, model)    
        is_sticker = bool(sticker.get("is_sticker", False))

        # 4) OCR 
        ocr = recognize_license_plate(image_url) or {}
        status_code = ocr.get("status", 404)

        if status_code != 200:
            ocr = { "status": status_code,           
                    "conf": 0.0,                      
                    "is_missing_plate": "yes",        
                    "is_vehicle": ocr.get("is_vehicle", "unknown"),
                    "country": ocr.get("country", None),
                    "lp_number": None,
                    "province": None,
                    "vehicle_brand": None,
                    "vehicle_body_type": None,
                    "vehicle_color": None,
                }

        # 5) payload 
        payload = {
            "location_id": location_id,
            "model_id": model_id,
            "image_path": [image_url],
            "detected_plate": ocr,
            "direction": direction.lower(),
            "is_sticker": is_sticker
        }
        # บันทึกลง DB
        res = insert_detection_payload(payload)
        if hasattr(res, "error") and res.error:
            raise HTTPException(status_code=500, detail=f"DB insert error: {res.error}")
        
        inserted = (res.data or [None])[0]
        if not inserted:
            raise HTTPException(status_code=500, detail="Insert returned no row.")

        # 6) สร้าง notification จาก detection ที่เพิ่ง insert
        notif = create_from_detection(inserted) 

        # 7) ส่งกลับให้ FE ใช้ต่อ
        return {
            "ok": True,
            "detection": inserted,      
            "notification": notif     
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")