# api_endpoint/routes_overview.py - API endpoint for overview statistics
from fastapi import APIRouter
from ..db.supabase_client import get_supabase_client
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

router = APIRouter()

TZ = ZoneInfo("Asia/Bangkok")
HOURS_BUCKETS = [0, 3, 6, 9, 12, 15, 18, 21]

# แปลงเวลาเป็นไทย
def parse_ts_to_local(ts: str) -> datetime | None:
    if not ts:
        return None
    try:
        s = ts.strip()
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            return dt.replace(tzinfo=TZ)
        return dt.astimezone(TZ)
    except Exception:
        return None

@router.get("/overview/{location_id}")
def get_overview(location_id: str):
    try:
        # ดึงข้อมูล detections ของ location
        sb = get_supabase_client()
        res = sb.table("detections") \
            .select("detected_at,is_sticker,direction") \
            .eq("location_id", location_id) \
            .execute()
        rows = res.data or []

        now = datetime.now(TZ)
        today = now.date()
        seven_days_ago = today - timedelta(days=6)
        twenty_four_hours_ago = now - timedelta(hours=24)

        # นับ alerts จากตาราง notifications
        alerts_q = (
            sb.table("notifications")
            .select("notifications_id", count="exact")   
            .eq("location_id", location_id)
            .eq("notification_status", "new")            
            .gte("created_at", twenty_four_hours_ago.isoformat()))

        alerts_res = alerts_q.execute()
        alerts = alerts_res.count or (len(alerts_res.data or []))

        daily_keys = [today - timedelta(days=i) for i in range(6, -1, -1)]
        daily_map = {d: 0 for d in daily_keys}

        week_ranges = []
        for i in range(4, 0, -1):
            start = (today - timedelta(weeks=i))
            end = start + timedelta(days=7)
            week_ranges.append((start, end))
        weekly_counts = [0, 0, 0, 0]

        monthly_labels = []
        monthly_map = {}
        for i in range(6, 0, -1):
            approx_month = (today.replace(day=1) - timedelta(days=30*i))
            label = approx_month.strftime("%b")
            ym_key = approx_month.strftime("%Y-%m")
            monthly_labels.append((label, ym_key))
            monthly_map[ym_key] = 0

        recent_map = {f"{h:02d}:00": 0 for h in HOURS_BUCKETS}

        total = len(rows)
        authorized = 0
        in_count = 0
        out_count = 0

        for r in rows:
            dt_local = parse_ts_to_local(r.get("detected_at"))
            if dt_local is None:
                continue

            d_local = dt_local.date()
            h_local = dt_local.hour
            is_sticker = bool(r.get("is_sticker", False))

            if is_sticker:
                authorized += 1

            direction = (r.get("direction") or "").lower()
            if d_local == today:
                if direction == "in":
                    in_count += 1
                elif direction == "out":
                    out_count += 1

            if seven_days_ago <= d_local <= today:
                if d_local in daily_map:
                    daily_map[d_local] += 1

            for idx, (ws, we) in enumerate(week_ranges):
                if ws <= d_local < we:
                    weekly_counts[idx] += 1
                    break

            ym = d_local.strftime("%Y-%m")
            if ym in monthly_map:
                monthly_map[ym] += 1

            if dt_local >= twenty_four_hours_ago:
                bucket_hour = (h_local // 3) * 3
                key = f"{bucket_hour:02d}:00"
                if key in recent_map:
                    recent_map[key] += 1

        unauthorized = total - authorized
        accuracy = round((authorized / total) * 100, 2) if total > 0 else 0.0

        dailyData = [{"day": d.strftime("%a"), "count": daily_map[d]} for d in daily_keys]
        weeklyData = [{"week": f"Week {i+1}", "count": weekly_counts[i]} for i in range(4)]
        monthlyData = [{"month": lbl, "count": monthly_map[ym]} for (lbl, ym) in monthly_labels]
        recentActivity = [{"time": k, "count": recent_map[k]} for k in [f"{h:02d}:00" for h in HOURS_BUCKETS]]

        return {
            "totalVehicles": total,
            "authorizedVehicles": authorized,
            "unauthorizedVehicles": unauthorized,
            "alerts": alerts,
            "todayInOut": {"in": in_count, "out": out_count},
            "dailyData": dailyData,
            "weeklyData": weeklyData,
            "monthlyData": monthlyData,
            "recentActivity": recentActivity,
            "detectionAccuracy": accuracy }

    except Exception as e:
        return {"error": str(e)}