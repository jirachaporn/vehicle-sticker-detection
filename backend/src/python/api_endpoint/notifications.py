from fastapi import APIRouter, HTTPException, Query
from typing import Optional, Any, Dict, List
from datetime import datetime, timezone
from db.supabase_client import get_supabase_anon, get_supabase_service

router = APIRouter(prefix="/notifications", tags=["notifications"])

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

@router.get("/{location_id}")
def list_notifications(
    location_id: str,
    status: str = Query("all", pattern="^(all|new)$"),
    limit: int = Query(50, ge=1, le=200),
    before: Optional[str] = None, 
) -> List[Dict[str, Any]]:
    sb = get_supabase_anon() 
    q = (sb.table("notifications")
        .select("*")
        .eq("location_id", location_id)
        .is_("dismissed_at", None)
        .order("created_at", desc=True)
        .limit(limit))
    if status == "new":
        q = q.eq("is_read", False)
    if before:
        q = q.lt("created_at", before)
    res = q.execute()
    return getattr(res, "data", res)

@router.get("/{location_id}/unread_count")
def unread_count(location_id: str) -> Dict[str, int]:
    sb = get_supabase_anon()
    res = (sb.table("notifications")
            .select("id", count="exact")
            .eq("location_id", location_id)
            .is_("dismissed_at", None)
            .eq("is_read", False)
            .execute())
    count_val = getattr(res, "count", None)
    if count_val is None:
        count_val = len(getattr(res, "data", []) or [])
    return {"unread": int(count_val)}

@router.patch("/{notif_id}/read")
def mark_read(notif_id: str) -> Dict[str, Any]:
    sb = get_supabase_service()  # bypass RLS
    res = (sb.table("notifications")
            .update({"is_read": True, "read_at": utc_now_iso()})
            .eq("id", notif_id)
            .execute())
    rows = getattr(res, "data", res) or []
    if not rows:
        raise HTTPException(404, "Notification not found")
    return {"ok": True, "updated": rows[0]}

@router.patch("/{location_id}/read_all")
def mark_all_read(location_id: str) -> Dict[str, Any]:
    sb = get_supabase_service()
    res = (sb.table("notifications")
            .update({"is_read": True, "read_at": utc_now_iso()})
            .eq("location_id", location_id)
            .eq("is_read", False)
            .is_("dismissed_at", None)
            .execute())
    rows = getattr(res, "data", res) or []
    return {"ok": True, "affected": len(rows)}

@router.patch("/{notif_id}/dismiss")
def dismiss(notif_id: str) -> Dict[str, Any]:
    sb = get_supabase_service()
    res = (sb.table("notifications")
            .update({"dismissed_at": utc_now_iso()})
            .eq("id", notif_id)
            .execute())
    rows = getattr(res, "data", res) or []
    if not rows:
        raise HTTPException(404, "Notification not found")
    return {"ok": True, "updated": rows[0]}
