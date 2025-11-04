# src/python/api_endpoint/routes_models.py
from fastapi import APIRouter, HTTPException, Query
from typing import Literal
import os
from supabase import create_client, Client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)

DEFAULT_SUCCESS_REASON = "Model training completed :)"
DEFAULT_FAIL_REASON = "There are not enough sticker images for training the model"

router = APIRouter(tags=["models"])

def get_model(model_id: str):
    # ดึง location_id จาก model_id ไม่ต้องรับพารามิเตอร์ location_id
    res = (sb.table("model").select("model_id, location_id, model_name, sticker_status")
        .eq("model_id", model_id).single().execute())
    if res.data is None:
        raise HTTPException(404, "Model not found")
    return res.data

@router.post("/{model_id}/noti")
def set_model_status(
    model_id: str,
    status: Literal["save", "fail"] = Query(..., description='Use "save" for READY, "fail" for FAILED')):
    # อ่าน model จาก DB เพื่อได้ location_id, model_name, old_status
    model = get_model(model_id)
    location_id = model["location_id"]
    model_name = model.get("model_name") or model_id[:8] # ถ้าโมเดลไม่มีชื่อ จะใช้ 8 ตัวแรกของ model_id เป็นชื่อ
    old_status = model.get("sticker_status") or "processing"

    # แตกแขนงตาม status แล้วอัปเดตตาราง model
    if status == "save":
        # ready + is_active=false
        upd = (sb.table("model")
            .update({"sticker_status": "ready", "is_active": False})
            .eq("model_id", model_id).execute())
        if upd.data is None:
            raise HTTPException(500, "Failed to update model to ready")

        # สร้าง Notification (สำเร็จ)
        title = "Model training completed"
        message = f"{model_name} is READY for use"
        meta = {
            "event": "MODEL_TRAINING",
            "result": "completed",
            "model_id": model_id,
            "model_name": model_name,
            "old_status": old_status,
            "new_status": "ready",
            "reason": DEFAULT_SUCCESS_REASON
        }
        payload = {
            "location_id": location_id,
            "severity": "info",
            "title": title,
            "message": message,
            "image_url": None,
            "is_read": False,
            "meta": meta,
            "notification_status": "new"
        }
        ins = sb.table("notifications").insert(payload).execute()
        if getattr(ins, "error", None):
            raise HTTPException(500, f"Failed to create notification: {ins.error}")

        return {
            "title": title,
            "message": message,
            "severity": "info",
            "notification_status": "new",
            "meta": meta
        }

    else:  # status == "fail" -> failed + is_active=false
        upd = (sb.table("model").update({"sticker_status": "failed", "is_active": False})
            .eq("model_id", model_id).execute())
        if upd.data is None:
            raise HTTPException(500, "Failed to update model to failed")

        # สร้าง Notification (ล้มเหลว)
        title = "Model training failed"
        message = f"{model_name} could not be trained"
        meta = {
            "event": "MODEL_TRAINING",
            "result": "failed",
            "model_id": model_id,
            "model_name": model_name,
            "old_status": old_status,
            "new_status": "failed",
            "reason": DEFAULT_FAIL_REASON,
        }
        payload = {
            "location_id": location_id,
            "severity": "critical",
            "title": title,
            "message": message,
            "image_url": None,
            "is_read": False,
            "meta": meta,
            "notification_status": "new",
        }
        ins = sb.table("notifications").insert(payload).execute()
        if getattr(ins, "error", None):
            raise HTTPException(500, f"Failed to create failure notification: {ins.error}")

        return {
            "title": title,
            "message": message,
            "severity": "critical",
            "notification_status": "new",
            "meta": meta,
        }