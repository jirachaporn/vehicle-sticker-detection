# src/python/api_endpoint/routes_notifications.py API สำหรับหน้า Notification Page
from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional, Literal
from ..api_service.notifications_service import (list_notifications, summary, mark_read, dismiss, mark_all_read)

router = APIRouter(prefix="/notifications")

class ListResponse(BaseModel):
    items: list
    total: int
    unread_count: int

@router.get("", response_model=ListResponse)
def get_notifications(
    location_id: str = Query(...),
    status: Literal["new", "read", "dismissed", "all"] = Query("new"),
    limit: int = Query(100, ge=1, le=100),
    offset: int = Query(0, ge=0),
    severity: Optional[Literal["info","warning","critical"]] = None):
    return list_notifications(location_id, status, limit, offset, severity)

@router.get("/summary")
def get_summary(location_id: str = Query(...)):
    return summary(location_id)

@router.patch("/{notification_id}/read")
def api_mark_read(notification_id: str):
    return mark_read(notification_id)

@router.patch("/{notification_id}/dismiss")
def api_dismiss(notification_id: str):
    return dismiss(notification_id)

class MarkAllBody(BaseModel):
    location_id: str
    type: Optional[str] = "ALL"

@router.patch("/mark-all-read")
def api_mark_all_read(body: MarkAllBody):
    updated = mark_all_read(body.location_id, body.type)
    return {"updated": updated}