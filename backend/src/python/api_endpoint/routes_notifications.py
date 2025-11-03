# src/python/api_endpoint/routes_notifications.py API สำหรับหน้า Notification Page
from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional, Literal
from ..api_service.notifications_service import (
    list_notifications, 
    summary, 
    mark_read,
    mark_all_read)

router = APIRouter(prefix="/notifications")

class ListResponse(BaseModel):
    items: list # รายการแจ้งเตือน
    total: int # จำนวนแจ้งเตือนทั้งหมด
    unread_count: int # จำนวนแจ้งเตือนที่ยังไม่อ่าน

# list notification of location
@router.get("", response_model=ListResponse) 
def get_notifications(
    location_id: str = Query(...),
    status: Literal["new", "read", "all"] = Query("new"),
    severity: Optional[Literal["info","warning","critical"]] = None):
    return list_notifications(location_id, status, severity)

# unread count ตาม severity
@router.get("/summary")
def get_summary(location_id: str = Query(...)):
    return summary(location_id)

# mark a notification as read
@router.patch("/{notification_id}/read")
def api_mark_read(notification_id: str):
    return mark_read(notification_id)

# mark all notifications as read
class MarkAllBody(BaseModel):
    location_id: str
    type: Optional[str] = "ALL"

@router.patch("/mark-all-read")
def api_mark_all_read(body: MarkAllBody):
    updated = mark_all_read(body.location_id, body.type)
    return {"updated": updated}