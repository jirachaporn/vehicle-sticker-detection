# api_endpoint/detection.py
from fastapi import APIRouter, File, UploadFile, HTTPException, Form
from typing import Literal
from ..utils.cloudinary_uploader import CloudinaryUploader
from ..utils.sticker_detector import get_sticker_detector
from ..api_service.ai4thai_ocr_LP_api import recognize_license_plate
from ..utils.processor import insert_detection_payload

router = APIRouter()

@router.post("/detect")
async def detect(
    file: UploadFile = File(...),
    location_id: str = Form(...),
    model_id: str = Form(...),
    direction: Literal["in", "out"] = Form("in"),
):
    try:
        # 1) อ่านไฟล์เป็น bytes 
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty file.")

        # 2) อัป Cloudinary → ได้ URL
        uploader = CloudinaryUploader()
        image_url = uploader.upload_bytes(image_bytes, folder="detection")
        if not image_url:
            raise HTTPException(status_code=500, detail="Upload to Cloudinary failed (no secure_url).")

        # 3) ตรวจสติกเกอร์ 
        detector = get_sticker_detector()
        sticker = detector.detect_from_bytes(image_bytes)
        is_sticker = bool(sticker.get("is_sticker", False))

        # 4) OCR 
        ocr = recognize_license_plate(image_url) or {}

        # 5) สร้าง payload 
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

        return payload

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")