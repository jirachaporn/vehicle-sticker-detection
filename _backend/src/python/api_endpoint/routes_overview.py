# routes_overview.py - API endpoint for overview statistics
from fastapi import APIRouter
from ..db.supabase_client import get_supabase_client 
from datetime import date, timedelta

router = APIRouter()

@router.get("/{location_id}")
def get_overview(location_id: str):
    try:
        sb = get_supabase_client()
        detections = sb.table("detections").select("*").eq("location_id", location_id).execute().data

        total = len(detections)
        authorized = len([d for d in detections if d.get("is_sticker")])
        unauthorized = total - authorized

        today = str(date.today())
        today_records = [d for d in detections if d["detected_at"][:10] == today]
        in_count = len([d for d in today_records if d.get("direction") == "in"])
        out_count = len([d for d in today_records if d.get("direction") == "out"])

        # daily (7 วันย้อนหลัง)
        daily_data = []
        for i in range(6, -1, -1):
            day = date.today() - timedelta(days=i)
            count = len([d for d in detections if d["detected_at"][:10] == str(day)])
            daily_data.append({"day": day.strftime("%a"), "count": count})

        # weekly (4 สัปดาห์ย้อนหลัง)
        weekly_data = []
        for i in range(4, 0, -1):
            start = date.today() - timedelta(weeks=i)
            end = start + timedelta(weeks=1)
            count = len([
                d for d in detections
                if start <= date.fromisoformat(d["detected_at"][:10]) < end
            ])
            weekly_data.append({"week": f"Week {5-i}", "count": count})

        # monthly (6 เดือนย้อนหลัง)
        monthly_data = []
        for i in range(6, 0, -1):
            month = (date.today().replace(day=1) - timedelta(days=30*i))
            m = month.strftime("%b")
            count = len([d for d in detections if d["detected_at"][:7] == month.strftime("%Y-%m")])
            monthly_data.append({"month": m, "count": count})

        # recent activity (24h → mock เป็นทุก 3 ชม.)
        recent_data = []
        hours = [0, 3, 6, 9, 12, 15, 18, 21]
        for h in hours:
            count = len([d for d in detections if d["detected_at"][11:13] == f"{h:02d}"])
            recent_data.append({"time": f"{h:02d}:00", "count": count})

        accuracy = round((authorized / total) * 100, 2) if total > 0 else 0

        return {
            "totalVehicles": total,
            "authorizedVehicles": authorized,
            "unauthorizedVehicles": unauthorized,
            "alerts": 0,
            "todayInOut": {"in": in_count, "out": out_count},
            "dailyData": daily_data,
            "weeklyData": weekly_data,
            "monthlyData": monthly_data,
            "recentActivity": recent_data,
            "detectionAccuracy": accuracy,
        }

    except Exception as e:
        return {"error": str(e)}
