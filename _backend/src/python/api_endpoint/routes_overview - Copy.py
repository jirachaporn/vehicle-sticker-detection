# # routes_overview.py - API endpoint for overview statistics (Refactored)

# from fastapi import APIRouter, HTTPException
# from ..db.supabase_client import get_supabase_client
# from datetime import date, datetime, timedelta, time

# router = APIRouter()

# @router.get("/overview/{location_id}", tags=["Overview"])
# def get_overview(location_id: str):
#     """
#     Endpoint ที่รวบรวมข้อมูลสถิติทั้งหมดสำหรับหน้า Overview
#     โดยดึงข้อมูลตาม location_id ที่ระบุ
#     """
#     try:
#         sb = get_supabase_client()

#         # --- 1. ดึงข้อมูลพื้นฐาน (ทั้งหมด, มีสติกเกอร์, ไม่มีสติกเกอร์) ---
#         # ให้ Supabase นับข้อมูลให้เลย ไม่ต้องดึงข้อมูลทั้งหมดมานับเอง
#         all_detections_count = sb.table("detections").select('id', count='exact').eq("location_id", location_id).execute().count
#         authorized_count = sb.table("detections").select('id', count='exact').eq("location_id", location_id).eq("is_sticker", True).execute().count
#         unauthorized_count = all_detections_count - authorized_count

#         # --- 2. ดึงข้อมูลรถเข้า-ออกของวันนี้ ---
#         today_start = datetime.combine(date.today(), time.min).isoformat()
#         today_end = datetime.combine(date.today(), time.max).isoformat()
        
#         today_records = sb.table("detections").select("direction") \
#             .eq("location_id", location_id) \
#             .gte("detected_at", today_start) \
#             .lte("detected_at", today_end) \
#             .execute().data

#         in_count = sum(1 for d in today_records if d.get("direction") == "In")
#         out_count = sum(1 for d in today_records if d.get("direction") == "Out")

#         # --- 3. เตรียมข้อมูลสำหรับกราฟต่างๆ ---
#         # สร้างฟังก์ชันย่อยเพื่อลดการเขียนโค้ดซ้ำซ้อน
#         daily_data = get_chart_data_by_period(sb, location_id, period="day", range_count=7)
#         weekly_data = get_chart_data_by_period(sb, location_id, period="week", range_count=4)
#         monthly_data = get_chart_data_by_period(sb, location_id, period="month", range_count=6)
#         recent_data = get_recent_activity(sb, location_id)

#         # --- 4. คำนวณค่า Accuracy ---
#         # เปลี่ยนจากการ mock มาคำนวณจากข้อมูลจริง (อัตราส่วนรถที่ได้รับอนุญาต)
#         accuracy = round((authorized_count / all_detections_count) * 100, 2) if all_detections_count > 0 else 0

#         # --- 5. รวบรวมข้อมูลส่งกลับ ---
#         return {
#             "totalVehicles": all_detections_count,
#             "authorizedVehicles": authorized_count,
#             "unauthorizedVehicles": unauthorized_count,
#             "alerts": unauthorized_count, # ใช้จำนวนรถไม่มีสติกเกอร์เป็น Alerts
#             "todayInOut": {"in": in_count, "out": out_count},
#             "dailyData": daily_data,
#             "weeklyData": weekly_data,
#             "monthlyData": monthly_data,
#             "recentActivity": recent_data,
#             "detectionAccuracy": accuracy,
#         }

#     except Exception as e:
#         # ใช้ HTTPException เพื่อส่ง status code ที่เหมาะสมกลับไปเมื่อเกิดข้อผิดพลาด
#         raise HTTPException(status_code=500, detail=str(e))


# def get_chart_data_by_period(sb, location_id: str, period: str, range_count: int) -> list:
#     """ฟังก์ชันสำหรับดึงข้อมูลย้อนหลังตามช่วงเวลา (วัน, สัปดาห์, เดือน)"""
#     results = []
#     today = date.today()

#     for i in range(range_count - 1, -1, -1):
#         if period == "day":
#             target_date = today - timedelta(days=i)
#             start_dt = datetime.combine(target_date, time.min)
#             end_dt = datetime.combine(target_date, time.max)
#             label = start_dt.strftime("%a") # Mon, Tue
            
#         elif period == "week":
#             # หาวันจันทร์ของสัปดาห์นั้นๆ
#             start_of_this_week = today - timedelta(days=today.weekday())
#             start_dt = start_of_this_week - timedelta(weeks=i)
#             end_dt = start_dt + timedelta(days=6)
#             label = f"Week {range_count - i}"
            
#         elif period == "month":
#             # คำนวณเดือนย้อนหลังให้แม่นยำขึ้น
#             current_month = (today.year, today.month)
#             year = current_month[0]
#             month = current_month[1] - i
            
#             # จัดการกรณีข้ามปี
#             while month <= 0:
#                 month += 12
#                 year -= 1
            
#             start_dt = date(year, month, 1)
#             next_month = month + 1 if month < 12 else 1
#             next_year = year if month < 12 else year + 1
#             end_dt = date(next_year, next_month, 1) - timedelta(days=1)
#             label = start_dt.strftime("%b") # Jan, Feb

#         count = sb.table("detections").select('id', count='exact') \
#             .eq("location_id", location_id) \
#             .gte("detected_at", start_dt.isoformat()) \
#             .lte("detected_at", end_dt.isoformat()) \
#             .execute().count

#         results.append({"label": label, "count": count})
    
#     # เปลี่ยน key "label" ให้ตรงกับที่ frontend ต้องการ
#     key_map = {"day": "day", "week": "week", "month": "month"}
#     return [{key_map[period]: item["label"], "count": item["count"]} for item in results]


# def get_recent_activity(sb, location_id: str) -> list:
#     """ฟังก์ชันสำหรับดึงข้อมูลกิจกรรม 24 ชม.ล่าสุด แบ่งทุก 3 ชม."""
#     results = []
#     now = datetime.utcnow()

#     for i in range(8): # 24 ชั่วโมง / 3 ชั่วโมง = 8 ช่วง
#         end_time = now - timedelta(hours=i * 3)
#         start_time = end_time - timedelta(hours=3)
        
#         count = sb.table("detections").select('id', count='exact') \
#             .eq("location_id", location_id) \
#             .gte("detected_at", start_time.isoformat()) \
#             .lt("detected_at", end_time.isoformat()) \
#             .execute().count
            
#         label = start_time.strftime("%H:00")
#         results.insert(0, {"time": label, "count": count}) # insert(0,...) เพื่อเรียงลำดับเวลาให้ถูกต้อง

#     return results