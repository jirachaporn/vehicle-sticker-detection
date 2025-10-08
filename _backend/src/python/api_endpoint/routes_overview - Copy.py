# # routes_overview.py - API endpoint for overview statistics (Corrected)

# from fastapi import APIRouter, HTTPException
# from ..db.supabase_client import get_supabase_client 
# from datetime import date, datetime, timedelta, time

# router = APIRouter()

# @router.get("/{location_id}")
# def get_overview(location_id: str):
#     try:
#         sb = get_supabase_client()

#         # --- 1. ดึงข้อมูลสรุปพื้นฐาน ---
#         # [FIX] เปลี่ยนจาก 'id' เป็น 'detections_id'
#         all_detections_count = sb.table("detections").select('detections_id', count='exact').eq("location_id", location_id).execute().count
#         authorized_count = sb.table("detections").select('detections_id', count='exact').eq("location_id", location_id).eq("is_sticker", True).execute().count
#         unauthorized_count = all_detections_count - authorized_count

#         # --- 2. ดึงข้อมูลรถเข้า-ออกของวันนี้ ---
#         in_count, out_count = _get_today_in_out(sb, location_id)

#         # --- 3. เตรียมข้อมูลสำหรับกราฟต่างๆ ---
#         daily_data = _get_chart_data_by_period(sb, location_id, period="day", range_count=7)
#         weekly_data = _get_chart_data_by_period(sb, location_id, period="week", range_count=4)
#         monthly_data = _get_chart_data_by_period(sb, location_id, period="month", range_count=6)
#         recent_data = _get_recent_activity(sb, location_id)
        
#         accuracy = round((authorized_count / all_detections_count) * 100, 2) if all_detections_count > 0 else 0

#         # --- 5. รวบรวมข้อมูลส่งกลับ ---
#         return {
#             "totalVehicles": all_detections_count,
#             "authorizedVehicles": authorized_count,
#             "unauthorizedVehicles": unauthorized_count,
#             "alerts": unauthorized_count,
#             "todayInOut": {"in": in_count, "out": out_count},
#             "dailyData": daily_data,
#             "weeklyData": weekly_data,
#             "monthlyData": monthly_data,
#             "recentActivity": recent_data,
#             "detectionAccuracy": accuracy,
#         }

#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# # --- ฟังก์ชันย่อยสำหรับช่วยประมวลผล (Helper Functions) ---

# def _get_today_in_out(sb, location_id: str) -> tuple[int, int]:
#     """ดึงข้อมูลรถเข้า-ออกเฉพาะของวันนี้"""
#     today_start = datetime.combine(date.today(), time.min).isoformat()
#     today_end = datetime.combine(date.today(), time.max).isoformat()
    
#     today_records = sb.table("detections").select("direction") \
#         .eq("location_id", location_id) \
#         .gte("detected_at", today_start) \
#         .lte("detected_at", today_end) \
#         .execute().data
    
#     in_c = sum(1 for d in today_records if d.get("direction") == "in")
#     out_c = sum(1 for d in today_records if d.get("direction") == "out")
#     return in_c, out_c

# def _get_chart_data_by_period(sb, location_id: str, period: str, range_count: int) -> list:
#     """ฟังก์ชันสำหรับดึงข้อมูลย้อนหลังตามช่วงเวลา (วัน, สัปดาห์, เดือน)"""
#     results = []
#     today = date.today()
#     for i in range(range_count - 1, -1, -1):
#         if period == "day":
#             target_date = today - timedelta(days=i)
#             start_dt = datetime.combine(target_date, time.min)
#             end_dt = datetime.combine(target_date, time.max)
#             label = start_dt.strftime("%a")
#         elif period == "week":
#             start_of_this_week = today - timedelta(days=today.weekday())
#             start_dt = start_of_this_week - timedelta(weeks=i)
#             end_dt = start_dt + timedelta(days=6, hours=23, minutes=59, seconds=59)
#             label = f"Week {range_count - i}"
#         elif period == "month":
#             year, month = today.year, today.month - i
#             while month <= 0:
#                 month += 12; year -= 1
#             start_dt = date(year, month, 1)
#             next_month_start = date(year, month + 1, 1) if month < 12 else date(year + 1, 1, 1)
#             end_dt = datetime.combine(next_month_start - timedelta(days=1), time.max)
#             label = start_dt.strftime("%b")
#         else: continue

#         # [FIX] เปลี่ยนจาก 'id' เป็น 'detections_id'
#         count = sb.table("detections").select('detections_id', count='exact') \
#             .eq("location_id", location_id) \
#             .gte("detected_at", start_dt.isoformat()) \
#             .lte("detected_at", end_dt.isoformat()) \
#             .execute().count
#         results.append({"label": label, "count": count})
    
#     key_map = {"day": "day", "week": "week", "month": "month"}
#     return [{key_map[period]: item["label"], "count": item["count"]} for item in results]

# def _get_recent_activity(sb, location_id: str) -> list:
#     """ฟังก์ชันสำหรับดึงข้อมูลกิจกรรม 24 ชม.ล่าสุด แบ่งทุก 3 ชม."""
#     results = []
#     now = datetime.utcnow()
#     for i in range(8):
#         end_time = now - timedelta(hours=i * 3)
#         start_time = end_time - timedelta(hours=3)
#         # [FIX] เปลี่ยนจาก 'id' เป็น 'detections_id'
#         count = sb.table("detections").select('detections_id', count='exact') \
#             .eq("location_id", location_id) \
#             .gte("detected_at", start_time.isoformat()) \
#             .lt("detected_at", end_time.isoformat()) \
#             .execute().count
#         results.insert(0, {"time": start_time.strftime("%H:00"), "count": count})
#     return results