# api_services/notifications_service.py ฟังก์ชันสร้าง/อ่าน/สรุป/เปลี่ยนสถานะ notification ด้วย Supabase client
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from ..db.supabase_client import get_supabase_client
from ..utils.notify_rules import classify_notification, STATUS_NEW, STATUS_READ, STATUS_DISMISSED

_TH_NUM_MAP = str.maketrans("๐๑๒๓๔๕๖๗๘๙", "0123456789")

def _now_iso():
    return datetime.now(timezone.utc).isoformat()

def _norm_lp(s: Optional[str]) -> Optional[str]:
    if not s:
        return None
    x = s.strip().replace(" ", "")
    x = x.translate(_TH_NUM_MAP)   # แปลงเลขไทยเป็นอารบิก
    return x.upper()

def _norm_province(s: Optional[str]) -> Optional[str]:
    if not s:
        return None
    return s.strip()

def _resolve_registration_for_detection(detection_row: Dict[str, Any]) -> Dict[str, Any]:
    """
    1) แปลง location_id → location_license
    2) ถ้า OCR ได้แผ่นป้าย + จังหวัด → เช็คตาราง license_plate ว่ามี record ที่ location_license เดียวกันไหม
       - แมตช์แบบ strict: (location_license, license_text, license_local) ครบ
       - ถ้าไม่เจอ ลองผ่อน: แมตช์ plate อย่างเดียว (province อาจอ่านผิด) → ระบุ match_policy='plate_only'
    """
    sb = get_supabase_client()

    # 1) ดึง location_license
    loc = (
        sb.table("locations")
        .select("location_license, location_name")   # ⬅️ เพิ่ม location_name
        .eq("location_id", detection_row["location_id"])
        .single()
        .execute()
    )
    location_license = (loc.data or {}).get("location_license")
    location_name = (loc.data or {}).get("location_name")   # ⬅️ เก็บไว้ใช้

    # 2) เตรียมค่า OCR
    dp = detection_row.get("detected_plate") or {}
    status = dp.get("status")
    raw_lp = dp.get("lp_number")
    raw_prov = dp.get("province")

    norm_lp = _norm_lp(raw_lp)
    norm_prov = _norm_province(raw_prov)

    # ถ้าอ่านป้ายไม่ได้ → ไม่มีสิทธิ์ยืนยันว่า registered
    if status != 200 or not norm_lp:
        return {
            "is_registered": False,
            "location_license": location_license,
            "location_name": location_name,
            "matched_license_id": None,
            "match_policy": "none"
        }

    # 3) เช็ค strict: plate + province
    strict = (
        sb.table("license_plate")
        .select("license_id, license_text, license_local")
        .eq("location_license", location_license)
        .eq("license_text", norm_lp)
        .eq("license_local", norm_prov if norm_prov else "")
        .execute()).data or []

    if strict:
        return {
            "is_registered": True,
            "location_license": location_license,
            "location_name": location_name,
            "matched_license_id": strict[0]["license_id"],
            "match_policy": "strict"
        }

    # 4) ผ่อน: plate อย่างเดียว (กรณี province อ่านผิด/เว้นว่าง)
    loose = (
        sb.table("license_plate")
        .select("license_id")
        .eq("location_license", location_license)
        .eq("license_text", norm_lp)
        .execute()).data or []

    if loose:
        return {
            "is_registered": True,
            "location_license": location_license,
            "location_name": location_name,
            "matched_license_id": loose[0]["license_id"],
            "match_policy": "plate_only"
        }

    # ไม่พบ
    return {
        "is_registered": False,
        "location_license": location_license,
        "location_name": location_name,
        "matched_license_id": None,
        "match_policy": "none"
    }

def create_from_detection(detection_row: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    reg = _resolve_registration_for_detection(detection_row)

    # ส่งผลตรวจสิทธิ์เข้า rule
    rule = classify_notification(
        detection_row,
        is_registered=reg["is_registered"],
        location_license=reg["location_license"],
        registration=reg
    )
    if not rule:
        return None

    sb = get_supabase_client()
    payload = {
        "location_id": detection_row["location_id"],
        "detections_id": detection_row.get("detections_id") or detection_row.get("id"),
        "severity": rule["severity"],
        "title": rule["title"],
        "message": rule["message"],
        "image_url": rule.get("image_url"),
        "is_read": bool(rule.get("is_read", False)),
        "notification_status": rule.get("notification_status", STATUS_NEW),
        "meta": rule.get("meta") or {}
    }
    res = sb.table("notifications").insert(payload).execute()
    return (res.data or [None])[0]

def list_notifications(
    location_id: str,
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    severity: Optional[str] = None,
) -> Dict[str, Any]:
    sb = get_supabase_client()
    q = sb.table("notifications").select("*", count="exact").eq("location_id", location_id)

    if status and status.lower() != "all":
        q = q.eq("notification_status", status.lower())

    if severity:
        q = q.eq("severity", severity.lower())

    q = q.order("created_at", desc=True).range(offset, offset + limit - 1)
    data = q.execute()
    items = data.data or []
    total = data.count or 0

    # นับ unread เพื่อขึ้น badge
    unread = (
        sb.table("notifications")
        .select("notifications_id", count="exact")
        .eq("location_id", location_id)
        .eq("notification_status", STATUS_NEW)
        .execute()).count or 0

    return {"items": items, "total": total, "unread_count": unread}

def summary(location_id: str) -> Dict[str, Any]:
    sb = get_supabase_client()
    unread = (
        sb.table("notifications").select("notifications_id", count="exact")
        .eq("location_id", location_id).eq("notification_status", STATUS_NEW).execute()).count or 0

    # สรุปตาม severity
    by_sev = {}
    for sev in ["info", "warning", "critical"]:
        by_sev[sev] = (
            sb.table("notifications").select("notifications_id", count="exact")
            .eq("location_id", location_id).eq("notification_status", STATUS_NEW).eq("severity", sev)
            .execute()).count or 0

    return {"unread": unread, "by_severity": by_sev}

def mark_read(notification_id: str) -> Dict[str, Any]:
    sb = get_supabase_client()
    res = (
        sb.table("notifications")
        .update({"is_read": True, "read_at": _now_iso(), "notification_status": STATUS_READ})
        .eq("notifications_id", notification_id)
        .execute())
    return (res.data or [None])[0] or {}

def dismiss(notification_id: str) -> Dict[str, Any]:
    sb = get_supabase_client()
    res = (
        sb.table("notifications")
        .update({"notification_status": STATUS_DISMISSED})
        .eq("notifications_id", notification_id)
        .execute())
    return (res.data or [None])[0] or {}

def mark_all_read(location_id: str, type_filter: Optional[str] = None) -> int:
    sb = get_supabase_client()
    q = sb.table("notifications").update({"is_read": True, "read_at": _now_iso(), "notification_status": STATUS_READ}) \
                                .eq("location_id", location_id) \
                                .eq("notification_status", STATUS_NEW)
    if type_filter and type_filter != "ALL":
        q = q.eq("title", type_filter)
    res = q.execute()
    return len(res.data or [])