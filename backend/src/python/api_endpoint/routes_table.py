# routes_table.py
from fastapi import APIRouter, Query, HTTPException
from typing import Optional, List, Dict, Any
from datetime import datetime
from zoneinfo import ZoneInfo
from ..db.supabase_client import get_supabase_client
import re

router = APIRouter()

TH_TZ = ZoneInfo("Asia/Bangkok")

def _to_db_timestamp_seconds(ts: Optional[str]) -> Optional[str]:
    if not ts:
        return None
    s = str(ts).replace("T", " ")
    m = re.match(r"^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})", s)
    if m:
        return m.group(1)
    s = re.sub(r"\.\d+", "", s)           
    s = re.sub(r"(Z|[+-]\d{2}:\d{2})$", "", s)
    return s.strip()

def _parse_province(raw: Optional[str]) -> Optional[str]:
    if not raw:
        return None
    if "(" in raw and ")" in raw:
        try:
            return raw.split("(")[-1].split(")")[0]
        except Exception:
            pass
    return raw

def _first_image(image_path: Any) -> Optional[str]:
    if isinstance(image_path, list) and image_path:
        return image_path[0]
    if isinstance(image_path, str) and image_path:
        return image_path
    return None

@router.get("/{location_id}/records")
def list_table_records(
    location_id: str,
    search: Optional[str] = Query(None, description="ค้นหาป้ายทะเบียน"),
    direction: Optional[str] = Query(None, regex="^(in|out)$"),
    sticker: Optional[bool] = Query(None, description="true/false"),
    date_from: Optional[str] = Query(None, description="ISO datetime"),
    date_to: Optional[str] = Query(None, description="ISO datetime"),
    sort: str = Query("detected_at.desc", description="เช่น detected_at.desc / detected_at.asc"),
    page: int = 1,
    page_size: int = 20,
):
    if page_size > 100:
        page_size = 100
    if page < 1:
        page = 1

    sb = get_supabase_client()

    location_name = location_id
    try:
        loc = (
            sb.table("locations")
              .select("location_id,location_name")
              .or_(f"location_id.eq.{location_id},location_id.eq.{location_id}")
              .limit(1)
              .execute()
        )
        if loc.data:
            location_name = loc.data[0].get("location_name") or location_name
    except Exception:
        pass

    # สร้าง query หลักจากตาราง detections
    q = (
        sb.table("detections")
          .select(
              "detections_id,location_id,detected_at,direction,is_sticker,image_path,detected_plate",
              count="exact"
          )
          .eq("location_id", location_id)
    )

    # ค้นหาทะเบียนจาก JSON ->>lp_number
    if search:
        q = q.filter("detected_plate->>lp_number", "ilike", f"%{search}%")
    if direction:
        q = q.eq("direction", direction)
    if sticker is not None:
        q = q.eq("is_sticker", sticker)
    if date_from:
        q = q.gte("detected_at", date_from)
    if date_to:
        q = q.lte("detected_at", date_to)

    # จัดเรียง
    try:
        sort_field, sort_dir = (sort.split(".") + ["desc"])[:2]
    except Exception:
        sort_field, sort_dir = "detected_at", "desc"
    q = q.order(sort_field, desc=(sort_dir.lower() == "desc"))

    # แบ่งหน้า
    start = (page - 1) * page_size
    end = start + page_size - 1
    q = q.range(start, end)

    res = q.execute()
    rows: List[Dict[str, Any]] = res.data or []
    total = getattr(res, "count", None)

    items: List[Dict[str, Any]] = []
    for r in rows:
        plate = (r.get("detected_plate") or {})
        items.append({
            "detections_id": r.get("detections_id") or r.get("id"),
            "license_plate": plate.get("lp_number"),
            "province": _parse_province(plate.get("province")),
            "type_car": plate.get("vehicle_body_type"),
            "vehicle_color": plate.get("vehicle_color"),
            "location": location_name,
            "timestamp": _to_db_timestamp_seconds(r.get("detected_at")),
            "actions": _first_image(r.get("image_path")),
            "direction": r.get("direction"),
            "sticker": bool(r.get("is_sticker")),
        })

    return {
        "page": page,
        "page_size": page_size,
        "total": total if total is not None else len(items),
        "items": items,
    }