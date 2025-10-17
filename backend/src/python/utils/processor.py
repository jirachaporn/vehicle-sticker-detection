# utils/processor.py - Connect supabase client, call OCR service from AI for Thai, insert OCR data into supabase
from typing import Dict, Any
from ..db.supabase_client import get_supabase_client

def insert_detection_payload(payload: Dict[str, Any]):
    direction = (payload.get("direction") or "in").lower()
    if direction not in ("in", "out"):
        direction = "in"

    # สร้าง payload 
    row = {
        "location_id": payload["location_id"],
        "model_id": payload["model_id"],
        "image_path": payload.get("image_path") or [],          
        "detected_plate": payload.get("detected_plate") or {}, 
        "direction": direction,
        "is_sticker": bool(payload.get("is_sticker", False)) 
    }

    sb = get_supabase_client()
    return sb.table("detections").insert(row).execute()