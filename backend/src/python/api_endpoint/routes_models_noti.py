# src/python/api_endpoint/routes_models.py
import os
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client

router = APIRouter(tags=["models"])

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE") 
if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE:
    raise RuntimeError("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE")

sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)

class SaveModelBody(BaseModel):
    location_id: str
    reason: Optional[str] = "Model training completed :)"

class FailModelBody(BaseModel):
    location_id: str
    reason: Optional[str] = "There are not enough sticker images for training the model"

def get_model(model_id: str, location_id: str) -> Dict[str, Any]:
    res = (sb.table("model").select("*").eq("model_id", model_id).eq("location_id", location_id).single()
        .execute())
    if res.data is None:
        raise HTTPException(404, "Model not found for this location")
    return res.data

def update_model_to_ready(model_id: str):
    upd = (sb.table("model").update({"sticker_status": "ready", "is_active": False}).eq("model_id", model_id)
        .execute())
    if upd.data is None:
        raise HTTPException(500, f"Failed to update model: {upd.error}")
    
def update_model_to_failed(model_id: str):
    upd = (sb.table("model").update({"sticker_status": "failed", "is_active": False}).eq("model_id", model_id)
        .execute())
    if upd.data is None:
        raise HTTPException(500, f"Failed to update model to failed: {upd.error}")

def insert_training_completed_notification(
        *, location_id: str, model_id: str, model_name: str, old_status: str, reason: str) -> Dict[str, Any]:
    title = "Model training completed"
    message = f"{model_name} is READY for use"
    meta = {
        "event": "MODEL_TRAINING",
        "result": "completed",
        "model_id": model_id,
        "model_name": model_name,
        "old_status": old_status,
        "new_status": "ready",
        "reason": reason
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

def insert_training_failed_notification(
    *, location_id: str, model_id: str, model_name: str, old_status: str, reason: str
) -> Dict[str, Any]:
    title = "Model training failed"
    message = f"{model_name} could not be trained"
    meta = {
        "event": "MODEL_TRAINING",
        "result": "failed",
        "model_id": model_id,
        "model_name": model_name,
        "old_status": old_status,
        "new_status": "failed",
        "reason": reason
    }
    payload = {
        "location_id": location_id,
        "severity": "critical",
        "title": title,
        "message": message,
        "image_url": None,
        "is_read": False,
        "meta": meta,
        "notification_status": "new"
    }
    ins = sb.table("notifications").insert(payload).execute()
    if getattr(ins, "error", None):
        raise HTTPException(500, f"Failed to create failure notification: {ins.error}")

    return {
        "title": title,
        "message": message,
        "severity": "critical",
        "notification_status": "new",
        "meta": meta
    }

@router.post("/models/{model_id}/save")
def save_model(model_id: str, body: SaveModelBody):
    model = get_model(model_id, body.location_id)
    model_name = model.get("model_name") or model_id[:8]
    old_status = model.get("sticker_status") or "processing"

    update_model_to_ready(model_id) # processing -> ready, is_active=False

    notif = insert_training_completed_notification(
        location_id=body.location_id,
        model_id=model_id,
        model_name=model_name,
        old_status=old_status,
        reason=body.reason)
    return notif

@router.post("/models/{model_id}/fail")
def fail_model(model_id: str, body: FailModelBody):
    # โหลดโมเดลสำหรับ location นี้
    model = get_model(model_id, body.location_id)
    model_name = model.get("model_name") or model_id[:8]
    old_status = model.get("sticker_status") or "processing"
    
    update_model_to_failed(model_id) # processing -> fail, is_active=False

    notif = insert_training_failed_notification(
        location_id=body.location_id,
        model_id=model_id,
        model_name=model_name,
        old_status=old_status,
        reason=body.reason)
    return notif