# src/python/api_endpoint/routes_table.py
from fastapi import APIRouter, Query
from typing import Optional, List, Dict, Any
from zoneinfo import ZoneInfo
from ..db.supabase_client import get_supabase_client
import re

router = APIRouter()

TH_TZ = ZoneInfo("Asia/Bangkok")

def to_db_timestamp_seconds(ts: Optional[str]) -> Optional[str]:
    if not ts:
        return None
    s = str(ts).replace("T", " ")
    m = re.match(r"^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})", s)
    if m:
        return m.group(1)
    s = re.sub(r"\.\d+", "", s)           
    s = re.sub(r"(Z|[+-]\d{2}:\d{2})$", "", s)
    return s.strip() # "timestamp": "2025-11-03 10:00:42"

# ทำ "th-10:Bangkok (กรุงเทพมหานคร)" เป็น "กรุงเทพมหานคร"
def parse_province(raw: Optional[str]) -> Optional[str]:
    if not raw:
        return None
    if "(" in raw and ")" in raw:
        try:
            return raw.split("(")[-1].split(")")[0]
        except Exception:
            pass
    return raw

def first_image(image_path: Any) -> Optional[str]:
    if isinstance(image_path, list) and image_path:
        return image_path[0]
    if isinstance(image_path, str) and image_path:
        return image_path
    return None

@router.get("/{location_id}/records")
def list_records(
    location_id: str,
    search: Optional[str] = Query(None, description="ค้นเลขป้ายทะเบียน"),
    direction: Optional[str] = Query(None, regex="^(in|out)$"),
    sticker: Optional[bool] = Query(None),
    date_from: Optional[str] = Query(None, description="ISO datetime"),
    date_to: Optional[str] = Query(None, description="ISO datetime"),
    sort: str = Query("detected_at.desc")):
    sb = get_supabase_client()

    # ดึงชื่อสถานที่จาก locations
    location_name = location_id
    try:
        loc = (sb.table("locations").select("location_id,location_name")
            .or_(f"location_id.eq.{location_id},location_license.eq.{location_id}")
            .limit(1).execute())
        if loc.data:
            location_name = loc.data[0].get("location_name") or location_name
    except Exception:
        pass

    # สร้าง base query + ใส่ filters 
    def apply_filters(q):
        q = q.eq("location_id", location_id)
        if search:
            # ค้นเลขป้ายใน JSON => detected_plate->>lp_number
            q = q.ilike("detected_plate->>lp_number", f"%{search}%")
        if direction:
            q = q.eq("direction", direction)
        if sticker is not None:
            q = q.eq("is_sticker", sticker)
        if date_from:
            q = q.gte("detected_at", to_db_timestamp_seconds(date_from))
        if date_to:
            q = q.lte("detected_at", to_db_timestamp_seconds(date_to))
        return q

    sort_col, sort_dir = "detected_at", "desc"
    if "." in sort:
        sort_col, sort_dir = (sort.split(".", 1) + ["asc"])[:2]
    desc = (sort_dir.lower() == "desc")

    # นับจำนวนแถวทั้งหมดที่ตรงเงื่อนไข เพื่อรู้ว่าจะดึงกี่แถว
    count_res = apply_filters(
        sb.table("detections").select("detections_id", count="exact")).limit(1).execute()
    total = count_res.count or 0

    # ดึงข้อมูลทั้งหมดตามเงื่อนไข + เรียง + ระบุช่วง index
    rows: List[Dict[str, Any]] = []
    if total > 0:
        data_res = apply_filters(
            sb.table("detections").select("*")).order(sort_col, desc=desc).range(0, total - 1).execute()
        rows = data_res.data or []

    items: List[Dict[str, Any]] = []
    for r in rows:
        plate = r.get("detected_plate") or {}
        items.append({
            "detections_id": r.get("detections_id"),
            "license_plate": plate.get("lp_number"),
            "province": parse_province(plate.get("province")),
            "type_car": plate.get("vehicle_body_type"),
            "vehicle_color": plate.get("vehicle_color"),
            "location": location_name,
            "timestamp": to_db_timestamp_seconds(r.get("detected_at")),
            "actions": first_image(r.get("image_path")),
            "direction": r.get("direction"),
            "sticker": bool(r.get("is_sticker"))
        })

    return {
        "total": total if total is not None else len(items),
        "items": items
    }