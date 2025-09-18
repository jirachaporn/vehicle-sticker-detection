from email.header import Header
from flask import Flask, request, jsonify, Response, make_response
import os, random, smtplib, json, threading, base64, tempfile, urllib.request
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
from flask_cors import CORS
from supabase import create_client
from supabase.lib.client_options import ClientOptions
from concurrent.futures import ThreadPoolExecutor
import cloudinary
import cloudinary.uploader
from datetime import datetime
import pytz, cv2, requests, torch, httpx
import numpy as np
import time


load_dotenv()
app = Flask(__name__)
CORS(app)

# set time for thai
tz = pytz.timezone("Asia/Bangkok")
created_at = datetime.now(tz).isoformat()

# Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

# Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE,
    options=ClientOptions(
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_ROLE}"}
    )
)

EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD")

# Roboflow
ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY") or ""
ROBOFLOW_BASE_URL = (os.getenv("ROBOFLOW_API_URL") or "https://detect.roboflow.com").rstrip("/")

# 🚀 Global thread pool executor สำหรับ async operations
executor = ThreadPoolExecutor(max_workers=3)

# 🚀 Pre-connect SMTP connection pool
smtp_lock = threading.Lock()
smtp_pool = []

# ===== Multi-cam first state =====

# โมเดล/ดีเทคชัน
current_model = None
model_type = None               # "local" (ใช้ .pt) | "roboflow" (ถ้ามีในอนาคต)
active_model_url = None
RF_MIN_CONF = float(os.getenv("RF_MIN_CONF", "0.25"))
_JPEG_QUALITY_RF = 85

# เธรดฝั่งตรวจจับ
detector_stop = threading.Event()
detector_thread = None
current_location_id = None

# ---- Multi-cam collections ----
# key = index ของอุปกรณ์ webcam ใน OpenCV (0,1,2,...)
cameras = {}                    # {cam_id: cv2.VideoCapture}
display_threads = {}            # {cam_id: Thread}
display_stops = {}              # {cam_id: Event}

latest_frame_map = {}           # {cam_id: np.ndarray | None}
latest_jpeg_map  = {}           # {cam_id: bytes | None}
latest_ts_map    = {}           # {cam_id: float}
latest_lock = threading.Lock()

primary_cam_id = None           # กล้องหลัก (ถ้าจะให้ detector ใช้ตัวเดียว)

# ---- Legacy aliases (ให้โค้ดเดิมยังรันได้ระหว่างเปลี่ยนเป็น multi-cam) ----
latest_frame = None             # จะถูกอัปเดตจาก cam หลัก (ถ้าจำเป็น)
latest_jpeg  = None
latest_ts    = 0.0
latest_gen   = 0                # เพิ่มทุกครั้งที่ start-camera ใหม่

# ---- ค่าปรับสำหรับการแสดงผล ----
DISPLAY_FPS = 60                # 45–60 ก็พอสำหรับ USB cam ส่วนใหญ่
JPEG_QUALITY_DISPLAY = 60       # 0–100 เท่านั้น (60–85 คือ sweet spot)
TARGET_DISPLAY_WIDTH = 640

# ไม่ enhance/ไม่ใส่ timestamp ที่ฝั่งแสดงผล (ให้ฝั่งตรวจจับทำเองถ้าต้องการ)
APPLY_ENHANCE_FOR_DISPLAY = False
DRAW_TS_ON_DISPLAY = False


def _corsify(response):
    response.headers.add("Access-Control-Allow-Origin", "*")
    response.headers.add("Access-Control-Allow-Headers", "Content-Type,Authorization")
    response.headers.add("Access-Control-Allow-Methods", "GET,PUT,POST,DELETE,OPTIONS")
    return response

def enhance_lowlight(bgr):
    """ปรับภาพแสงน้อย: CLAHE + gamma"""
    # CLAHE บนช่อง Y
    ycrcb = cv2.cvtColor(bgr, cv2.COLOR_BGR2YCrCb)
    y, cr, cb = cv2.split(ycrcb)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    y = clahe.apply(y)
    ycrcb = cv2.merge([y, cr, cb])
    out = cv2.cvtColor(ycrcb, cv2.COLOR_YCrCb2BGR)

    # gamma (>1 สว่างขึ้น)
    gamma = 1.5
    table = np.array([((i / 255.0) ** (1.0 / gamma)) * 255
                      for i in np.arange(256)]).astype("uint8")
    out = cv2.LUT(out, table)
    return out

def create_smtp_connection():
    """สร้าง SMTP connection แบบ reusable"""
    # ✅ กันเคส env ว่างจนทำให้เกิด 'NoneType'.encode() ใน smtplib
    if not EMAIL_ADDRESS or not EMAIL_PASSWORD:
        print("❌ SMTP ENV missing: EMAIL_ADDRESS or EMAIL_PASSWORD is empty")
        return None
    try:
        server = smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=10)
        server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
        return server
    except Exception as e:
        print(f"❌ SMTP connection failed: {e}")
        return None

def get_smtp_connection():
    """ดึง SMTP connection จาก pool หรือสร้างใหม่"""
    with smtp_lock:
        if smtp_pool:
            return smtp_pool.pop()
    return create_smtp_connection()

def return_smtp_connection(server):
    """คืน SMTP connection กลับ pool"""
    if server and len(smtp_pool) < 2:  # เก็บแค่ 2 connections
        with smtp_lock:
            smtp_pool.append(server)
    elif server:
        try:
            server.quit()
        except:
            pass

# 🔢 สร้าง OTP 4 หลัก
def generate_otp():
    return ''.join([str(random.randint(0, 9)) for _ in range(4)])


def _build_otp_email_html(otp: str) -> str:
    # ทำกล่องตัวเลขทีละหลัก (inline style เพื่อรองรับอีเมลไคลเอนต์ส่วนใหญ่)
    box_style = (
        "display:inline-block;width:44px;height:56px;line-height:56px;"
        "margin:0 6px;border-radius:12px;background:#f8fafc;border:1px solid #e5e7eb;"
        "box-shadow:0 1px 2px rgba(0,0,0,.06);font-family:SFMono-Regular,Consolas,Menlo,monospace;"
        "font-weight:700;font-size:24px;color:#111;text-align:center;"
    )
    otp_boxes = "".join(f'<span style="{box_style}">{c}</span>' for c in str(otp).strip())

    return f"""\
        <!DOCTYPE html>
        <html lang="en">
        <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#111;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
            <tr>
                <td align="center" style="padding:24px;">
                <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:600px;background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.05);overflow:hidden;">
                    <tr>
                    <td style="height:4px;background:linear-gradient(90deg,#2563eb,#1d4ed8);"></td>
                    </tr>
                    <tr>
                    <td style="padding:28px;">
                        <h1 style="margin:0 0 8px 0;font-size:20px;line-height:1.3;color:#1d4ed8;">Reset your password</h1>
                        <p style="margin:0 0 18px 0;font-size:14px;color:#444;">
                        Use the verification code below to continue.
                        </p>
                        <div style="text-align:center;padding:6px 0 14px 0;">
                        {otp_boxes}
                        </div>
                        <p style="margin:0 0 6px 0;font-size:12px;color:#666;">
                        This code will expire in <strong>3 minutes</strong>.
                        </p>
                        <p style="margin:0 0 16px 0;font-size:12px;color:#999;">
                        If you didn’t request a password reset, you can safely ignore this email.
                        </p>
                    </td>
                    </tr>
                    <tr>
                    <td style="padding:12px 28px 24px 28px;border-top:1px solid #eee;">
                        <p style="margin:0;font-size:12px;color:#9aa1a9;text-align:center;">
                        This is an automated message—no reply is required.
                        </p>
                    </td>
                    </tr>
                </table>
                </td>
            </tr>
            </table>
        </body>
        </html>
        """

# ---------- ส่งอีเมล OTP แบบ HTML-only ----------
def send_otp_email(to_email: str, otp: str) -> bool:
    server = get_smtp_connection()
    if not server:
        return False

    try:
        html = _build_otp_email_html(otp)
        msg = MIMEText(html, "html", "utf-8")   # ส่งเป็น HTML อย่างเดียว
        msg["Subject"] = "Automated Vehicle Tagging System - Your OTP for Password Reset"
        msg["From"] = EMAIL_ADDRESS
        msg["To"] = to_email

        server.send_message(msg)
        return_smtp_connection(server)  # คืน connection กลับ pool
        return True
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        try:
            server.quit()
        except:
            pass
        return False


# ====== NEW: ส่งลิงก์ยืนยันสิทธิ์ทางอีเมล ======
# ---------- Template อีเมล ----------
def _build_link_email_html(invited_name: str, location_name: str, link_url: str) -> str:
    name = (invited_name or "").strip()
    greet = f"Hi {name}," if name else "Hi there,"
    loc = (location_name or "your workspace").strip()

    # โทนเรียบ สะอาด อ่านง่าย บนทุก client
    return f"""\
        <!DOCTYPE html>
        <html lang="en">
        <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#111;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
            <tr>
                <td align="center" style="padding:24px;">
                <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:600px;background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.05);overflow:hidden;">
                    <tr>
                    <td style="padding:28px 28px 8px 28px;">
                        <h1 style="margin:0 0 8px 0;font-size:20px;line-height:1.3;color:#111;">Confirm your access</h1>
                        <p style="margin:0 0 16px 0;font-size:14px;color:#444;">{greet}</p>
                        <p style="margin:0 0 16px 0;font-size:14px;color:#444;">
                        You’ve been invited to access <strong>{loc}</strong>. Please confirm your access using the button below.
                        </p>
                    </td>
                    </tr>
                    <tr>
                    <td align="left" style="padding:0 28px 20px 28px;">
                        <a href="{link_url}" style="display:inline-block;padding:12px 18px;border-radius:8px;background:#2563eb;color:#ffffff;text-decoration:none;font-weight:600;">
                        Confirm access
                        </a>
                    </td>
                    </tr>
                    <tr>
                    <td style="padding:0 28px 24px 28px;">
                        <p style="margin:0 0 8px 0;font-size:12px;color:#666;">
                        If the button doesn’t work, copy and paste this link into your browser:
                        </p>
                        <p style="margin:0;font-size:12px;word-break:break-all;">
                        <a href="{link_url}" style="color:#2563eb;text-decoration:underline;">{link_url}</a>
                        </p>
                    </td>
                    </tr>
                    <tr>
                    <td style="padding:0 28px 28px 28px;border-top:1px solid #eee;">
                        <p style="margin:12px 0 0 0;font-size:12px;color:#999;">
                        If you didn’t request or expect this invitation, you can safely ignore this email.
                        </p>
                    </td>
                    </tr>
                </table>
                <div style="font-size:11px;color:#9aa1a9;margin-top:12px;">
                    This is an automated message—no reply is required.
                </div>
                </td>
            </tr>
            </table>
        </body>
        </html>
        """


# ---------- ฟังก์ชันส่งเมลลิงก์ (แนบทั้ง Text + HTML) ----------
def send_permission_link_email(
    to_email: str,
    link_url: str,
    *,
    invited_name: str = "",
    location_name: str = "your workspace",
    subject: str = "Confirm your access"
) -> bool:
    """ส่งอีเมลแบบ HTML ล้วน (หัวข้อถูกส่งเข้ามาแล้ว ใช้ตามนั้นเลย)"""
    if not to_email or not link_url:
        print("❌ to_email or link_url is empty")
        return False

    server = get_smtp_connection()
    if not server:
        return False

    try:
        html = _build_link_email_html(invited_name, location_name, link_url)
        msg = MIMEText(html, "html", "utf-8")

        # ใช้ subject ที่ถูกบังคับให้เป็น EN แล้วจาก endpoint
        msg["Subject"] = str(Header(subject, "utf-8"))
        msg["From"] = EMAIL_ADDRESS
        msg["To"] = to_email

        server.send_message(msg)
        return_smtp_connection(server)
        return True
    except Exception as e:
        print(f"❌ Failed to send link email: {e}")
        try:
            server.quit()
        except:
            pass
        return False



# ---------- (ออปชัน) Endpoint สำหรับทดสอบส่งเมล ----------
@app.post("/send-permission-email")
def send_permission_email_endpoint():
    data = request.get_json(silent=True) or {}

    to_email = (data.get("to_email") or "").strip()
    link_url = (data.get("link_url") or "").strip()
    invited_name = (data.get("invited_name") or "").strip()
    location_name = (data.get("location_name") or "your workspace").strip()

    subject_en = f"Automated Vehicle Tagging System - Confirm access to {location_name}" if location_name else "Automated Vehicle Tagging System - Confirm your access"

    ok = send_permission_link_email(
        to_email,
        link_url,
        invited_name=invited_name,
        location_name=location_name,
        subject=subject_en,       
    )
    if not ok:
        return jsonify({"ok": False, "error": "send email failed"}), 500
    return jsonify({"ok": True}), 200



@app.route("/send-otp", methods=["POST"])
def send_otp():
    try:
        data = request.get_json()
        email = data.get("email")

        if not email:
            return jsonify({"error": "Email is required"}), 400

        otp = generate_otp()
        
        # 🚀 ใช้ Stored Procedure แบบ atomic
        def db_operations():
            try:
                # ใช้ stored procedure ที่ทำทั้ง invalidate + insert ในครั้งเดียว
                result = supabase.rpc('send_new_otp', {
                    'user_email': email,
                    'new_otp': otp
                }).execute()
                return result
            except Exception as stored_error:
                print(f"⚠️ Stored procedure failed: {stored_error}")
                # Fallback
                supabase.rpc('invalidate_previous_otp', {'user_email': email}).execute()
                return supabase.table("password_reset_log").insert({
                    "email": email,
                    "otp": otp,
                    "used": False,
                    "success": None
                }).execute()
        
        # 🚀 รัน database operations และ email sending แบบ parallel
        db_future = executor.submit(db_operations)
        email_future = executor.submit(send_otp_email, email, otp)
        
        # รอให้ database operation เสร็จ (ลด timeout)
        insert_res = db_future.result(timeout=3)
        if not insert_res.data:
            print("❌ Failed to insert OTP")
            return jsonify({"error": "Insert OTP failed"}), 500
        
        # รอให้ email sending เสร็จ (ลด timeout)
        sent = email_future.result(timeout=8)
        if not sent:
            return jsonify({"error": "Failed to send email"}), 500

        return jsonify({"message": "OTP sent successfully", "email": email}), 200

    except Exception as e:
        print("🔥 ERROR during /send-otp:", e)
        return jsonify({"error": str(e)}), 500

@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    try:
        data = request.get_json()
        email = data.get("email")
        otp = data.get("otp")

        if not email or not otp:
            return jsonify({"valid": False, "message": "Email and OTP are required"}), 400

        print(f"🔍 Verifying OTP {otp} for {email}")

        # 🚀 ใช้ Stored Procedure แทนการ query แยก
        try:
            # ลองใช้ stored procedure ที่รวมทุกอย่างไว้
            result = supabase.rpc('verify_and_mark_otp', {
                'user_email': email,
                'user_otp': otp
            }).execute()
            
            # ถ้า stored procedure คืน true = valid
            is_valid = result.data
            
            if is_valid:
                print("✅ OTP is valid")
                return jsonify({"valid": True, "message": "OTP is valid"}), 200
            else:
                print("❌ OTP not found or expired")
                return jsonify({"valid": False, "message": "OTP is incorrect or expired"}), 400
                
        except Exception as stored_proc_error:
            print(f"⚠️ Stored procedure failed: {stored_proc_error}")
            # Fallback ไปใช้วิธีเดิมแต่ปรับปรุง
            
            # 🚀 ใช้ raw SQL query เดียวแทนหลาย filters
            query = """
            SELECT id FROM password_reset_log 
            WHERE email = %s 
            AND otp = %s 
            AND used = false 
            AND expires_at > now() 
            ORDER BY created_at DESC 
            LIMIT 1
            """
            
            # ใช้ supabase.postgrest แทน table() เพื่อความเร็ว
            from postgrest import APIError
            
            result = supabase.table("password_reset_log") \
                .select("id") \
                .eq("email", email) \
                .eq("otp", otp) \
                .eq("used", False) \
                .gt("expires_at", "now()") \
                .order("created_at", desc=True) \
                .limit(1) \
                .execute()

            if result.data and len(result.data) > 0:
                record_id = result.data[0]["id"]
                
                # 🚀 ใช้ async update
                def update_record():
                    return supabase.table("password_reset_log").update({
                        "used": True,
                        "success": True
                    }).eq("id", record_id).execute()
                
                # รัน update แบบ non-blocking
                update_future = executor.submit(update_record)
                
                print("✅ OTP is valid")
                
                # ส่ง response ก่อน รอให้ update เสร็จทีหลัง
                response = jsonify({"valid": True, "message": "OTP is valid"}), 200
                
                # รอให้ update เสร็จ (ไม่เกิน 2 วินาที)
                try:
                    update_future.result(timeout=2)
                except:
                    print("⚠️ Update operation timeout but OTP is still valid")
                
                return response

            print("❌ OTP not found or expired")
            return jsonify({"valid": False, "message": "OTP is incorrect or expired"}), 400

    except Exception as e:
        print("🔥 ERROR during /verify-otp:", e)
        return jsonify({"valid": False, "message": str(e)}), 500

@app.route("/reset-password", methods=["POST"])
def reset_password():
    try:
        data = request.get_json()
        new_password = data.get("new_password")

        if not new_password:
            return jsonify({"success": False, "message": "New password is required"}), 400

        # 🚀 ใช้ single query เพื่อหา verified email
        otp_result = supabase.table("password_reset_log") \
            .select("email") \
            .filter("success", "eq", True) \
            .order("created_at", desc=True) \
            .limit(1) \
            .execute()

        if not otp_result.data:
            return jsonify({"success": False, "message": "No verified OTP found"}), 400

        email = otp_result.data[0]["email"]
        print("✅ Using verified email:", email)

        # 🚀 ใช้ httpx client แบบ persistent connection
        project_id = SUPABASE_URL.split("//")[1].split(".")[0]
        
        headers = {
            "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE}",
            "apikey": SUPABASE_SERVICE_ROLE,
            "Content-Type": "application/json"
        }
        
        # 🚀 ใช้ context manager สำหรับ connection reuse
        with httpx.Client(timeout=httpx.Timeout(10.0)) as client:
            # หา user ด้วย email query แทนการดึงทุกคน
            get_url = f"https://{project_id}.supabase.co/auth/v1/admin/users"
            params = {"email": email}  # ถ้า Supabase Auth รองรับ
            
            response = client.get(get_url, headers=headers, params=params)
            
            # ถ้าไม่รองรับ email filter ต้องดึงทุกคนแล้วหา
            if response.status_code != 200:
                response = client.get(get_url, headers=headers)
                
            if response.status_code != 200:
                return jsonify({"success": False, "message": "Cannot fetch users"}), 500

            data_response = response.json()
            all_users = data_response.get("users", data_response if isinstance(data_response, list) else [])
            
            # หา user ที่ email ตรงแบบ exact match
            target_user = next((user for user in all_users 
                               if user.get("email", "").lower() == email.lower()), None)
                
            if not target_user:
                return jsonify({"success": False, "message": f"User with email {email} not found"}), 404

            user_id = target_user["id"]

            # อัปเดตรหัสผ่านด้วย PUT
            put_url = f"https://{project_id}.supabase.co/auth/v1/admin/users/{user_id}"
            put_data = {"password": new_password}

            put_res = client.put(put_url, headers=headers, json=put_data)

            if put_res.status_code == 200:
                updated_user = put_res.json()
                updated_email = updated_user.get("email", "")
                
                if updated_email.lower() == email.lower():
                    print(f"✅ Password updated successfully: {updated_email}")
                    return jsonify({"success": True, "message": "Password updated successfully"}), 200
                else:
                    return jsonify({"success": False, "message": f"Error: Updated wrong user"}), 500
            else:
                error_detail = put_res.json() if put_res.text else {"error": "Unknown error"}
                return jsonify({"success": False, "message": f"Failed to update password: {error_detail}"}), 500

    except Exception as e:
        print("🔥 EXCEPTION during reset-password:", repr(e))
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/locations", methods=["GET"])
def get_locations():
    user_email = request.args.get("user")
    if not user_email:
        return jsonify({"error": "User email is required"}), 400

    try:
        print(f"🔍 Fetching locations (via location_members) for: {user_email}")

        # 1) หา location_id ที่ user เป็นสมาชิกและยืนยันแล้ว
        mem_res = supabase.table("location_members") \
            .select("location_id") \
            .eq("member_email", user_email) \
            .eq("member_status", "confirmed") \
            .execute()

        memberships = mem_res.data or []
        loc_ids = [m.get("location_id") for m in memberships if m.get("location_id")]
        if not loc_ids:
            return jsonify([]), 200
        

        # 2) ดึงรายละเอียดสถานที่ตาม loc_ids (ใช้ชื่อคอลัมน์ตามสคีมาใหม่)
        loc_res = supabase.table("locations") \
            .select("location_id, location_name, location_address, location_description, location_color, created_at") \
            .in_("location_id", loc_ids) \
            .order("created_at", desc=True) \
            .execute()

        locations = loc_res.data or []

        # 3) สร้าง response (คง key เดิม 'locations_id' ถ้า frontend ใช้อยู่)
        result = []
        for loc in locations:
            result.append({
                "locations_id": loc.get("location_id"),                # alias ให้เหมือนของเดิม
                "name": loc.get("location_name"),
                "address": loc.get("location_address"),
                "description": loc.get("location_description"),
                "color": loc.get("location_color"),
                "created_at": loc.get("created_at"),
            })

        print(f"✅ Found {len(result)} locations for {user_email}")
        return jsonify(result), 200

    except Exception as e:
        print("🔥 ERROR during /locations:", e)
        return jsonify({"error": str(e)}), 500



# ===== locations: CREATE =====
@app.route("/save_locations", methods=["POST"])
def save_locations():
    try:
        data = request.get_json() or {}

        # name และ owner_email ยังจำเป็น เพราะต้องสร้าง owner membership
        for field in ["name", "owner_email"]:
            if not (data.get(field) or "").strip():
                return jsonify({"error": f"{field} is required"}), 400

        owner_email = (data["owner_email"] or "").strip().lower()
        owner_name = owner_email.split("@", 1)[0].strip() or None

        now_ts = datetime.now(tz).isoformat()
        print(f"💾 Saving location: {data['name']} for {owner_email}")

        #  map ให้ตรง DB ใหม่
        location_data = {
            "location_name": (data.get("name") or "").strip(),
            "location_address": (data.get("address") or "").strip(),
            "location_description": (data.get("description") or "").strip(),
            "location_color": (data.get("color") or "#1565C0").strip(), 
            "created_at": now_ts,
        }

        # 1) insert สถานที่
        def insert_location():
            return supabase.table("locations").insert(location_data).execute()

        insert_future = executor.submit(insert_location)
        result = insert_future.result(timeout=5)

        if not result.data:
            return jsonify({"error": "Failed to create location"}), 500

        #  คีย์หลักใหม่ในตารางคือ location_id
        new_id = result.data[0]["location_id"]
        print(f"✅ Location saved with ID: {new_id}")

        # 2) สร้างสิทธิ์ owner ใน location_members ให้ผู้สร้าง
        owner_row = {
            "location_id": new_id,
            "member_email": owner_email,
            "member_name": owner_name,      
            "member_permission": "owner",
            "member_status": "confirmed",
        }

        try:
            supabase.table("location_members").insert(owner_row).execute()
        except Exception as e:
            try:
                supabase.table("locations").delete().eq("location_id", new_id).execute()
            except Exception as _:
                pass
            print(f"❌ create owner membership failed: {e}")
            return jsonify({"error": "Failed to create owner membership"}), 500

        return jsonify({
            "message": "Location created successfully",
            "id": new_id,
            "location": result.data[0],
        }), 201

    except Exception as e:
        print(f"🔥 ERROR during /save_locations: {e}")
        return jsonify({"error": str(e)}), 500



# ===== locations: UPDATE =====
@app.route('/update_location/<location_id>', methods=['PUT'])
def update_location(location_id):
    try:
        data = request.get_json() or {}

        update_data = {
            "location_name": data.get("name"),
            "location_address": data.get("address"),
            "location_description": data.get("description"),
            "location_color": data.get("color"),
        }

        # ลบ key ที่เป็น None ออก (กันเขียนทับด้วย null)
        update_data = {k: v for k, v in update_data.items() if v is not None}

        resp = (supabase.table("locations")
                .update(update_data)
                .eq("location_id", location_id)
                .execute())

        if resp.data:
            return jsonify({"message": "Location updated successfully"}), 200
        return jsonify({"message": "Location not found"}), 404

    except Exception as e:
        return jsonify({"message": str(e)}), 500


# ===== locations: DELETE =====
@app.route('/delete_location/<location_id>', methods=['DELETE'])
def delete_location(location_id):
    try:
        # ถ้า FK ไม่มี ON DELETE CASCADE ให้เคลียร์ตารางลูกก่อน
        try:
            supabase.table("location_members").delete().eq("location_id", location_id).execute()
            supabase.table("model").delete().eq("location_id", location_id).execute()
            supabase.table("detections").delete().eq("location_id", location_id).execute()
        except Exception as _:
            # ถ้าใช้ cascade อยู่แล้ว ส่วนนี้จะล้มเหลวก็ข้ามได้
            pass

        res = (supabase.table("locations")
               .delete()
               .eq("location_id", location_id)
               .execute())

        if res.data:
            return jsonify({"message": "Location deleted"}), 200
        return jsonify({"error": "Location not found"}), 404

    except Exception as e:
        return jsonify({"error": str(e)}), 500


    
    
@app.route("/upload-sticker-model", methods=["POST"])
def upload_sticker_model():
    try:
        model_name = request.form.get("model_name")
        location_id = request.form.get("location_id")
        files = request.files.getlist("images")

        # 🛑 ตรวจสอบค่าที่จำเป็น
        if not model_name or not location_id:
            return jsonify({"error": "Missing model_name or location_id"}), 400

        if len(files) < 5:
            return jsonify({"error": "Upload at least 5 images"}), 400

        image_urls = []

        for file in files:
            if file.content_length > 5 * 1024 * 1024:
                return jsonify({"error": f"{file.filename} exceeds 5MB"}), 400

            result = cloudinary.uploader.upload(
                file,
                folder="model",
                resource_type="image",
                return_delete_token=True
            )

            image_urls.append(result["secure_url"])

        new_sticker = {
            "location_id": location_id,
            "model_name": model_name,
            "is_active": False,
            "created_at": created_at,
            "sticker_status": "processing",
            "image_urls": image_urls
        }

        res = supabase.table("model").insert(new_sticker).execute()

        if res.data:
            return jsonify({
                "message": "Sticker model uploaded successfully",
                "data": res.data[0]
            }), 201
        else:
            return jsonify({"error": "Failed to insert to Supabase"}), 500

    except Exception as e:
        print("🔥 ERROR during /upload-sticker-model:", e)
        return jsonify({"error": str(e)}), 500


def _try_open_camera_on_index(index: int):
    """ลองเปิดกล้องด้วย backend หลายแบบบน Windows ตาม index ที่ระบุ"""
    backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, None]
    for be in backends:
        try:
            cap = cv2.VideoCapture(index, be) if be is not None else cv2.VideoCapture(index)
            if not cap.isOpened():
                try: cap.release()
                except: pass
                continue

            # flush buffer
            for _ in range(10):
                ok, _ = cap.read()
                if not ok:
                    break

            ok, img = cap.read()
            if ok and img is not None and img.size > 0:
                return cap, be
            cap.release()
        except Exception as e:
            print(f"⚠️ open camera index={index} with backend {be} failed: {e}")
    return None, None


def _probe_cameras(max_index: int = 8) -> list[int]:
    """สแกนหา index 0..max_index ที่เปิดได้จริง"""
    found = []
    for i in range(max_index + 1):
        cap, _ = _try_open_camera_on_index(i)
        if cap is not None:
            found.append(i)
            cap.release()
    return found


@app.get("/list-cameras")
def list_cameras():
    """คืนลิสต์ index ของกล้องที่เปิดได้ (ดีฟอลต์ตัด index 0 ออกเพื่อหลีกเลี่ยงกล้องโน้ตบุ๊ก)"""
    usb_only = request.args.get("usb_only", "1") == "1"
    found = _probe_cameras(8)
    cams = [i for i in found if (not usb_only or i != 0)] or found
    return _corsify(jsonify({"available": cams}))



@app.route("/start-camera", methods=["POST", "OPTIONS"])
def start_camera():
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    global detector_thread, detector_stop, current_location_id
    global primary_cam_id, latest_gen

    data = request.get_json() or {}
    location_id = data.get("location_id")
    cam_indices = data.get("camera_indices")            # optional: [1,2,...]
    usb_only    = bool(data.get("usb_only", True))      # ดีฟอลต์ True = ตัด 0 ทิ้ง

    if not location_id:
        return _corsify(jsonify({"error": "location_id is required"})), 400

    # --- เช็กโมเดล is_active (คง logic เดิมไว้ตามไฟล์ปัจจุบันของคุณ) ---
    try:
        model_res = (
            supabase.table("model")
            .select("model_url")
            .eq("location_id", location_id)
            .eq("is_active", True)
            .limit(1)
            .execute()
        )
    except Exception as e:
        return _corsify(jsonify({"error": f"DB error: {e}"})), 500

    if not model_res.data or not (model_res.data[0].get("model_url") or "").strip():
        return _corsify(jsonify({
            "error": "No active model for this location.",
            "code": "NO_ACTIVE_MODEL"
        })), 401

    # --- เลือกกล้องที่จะเปิด ---
    if not cam_indices:
        probed = _probe_cameras(8)
        cam_indices = [i for i in probed if (not usb_only or i != 0)] or probed
    if not cam_indices:
        return _corsify(jsonify({"error": "No webcam found"})), 404

    # --- ปิดของเก่าทั้งหมด (display threads + cameras) ---
    for ev in list(display_stops.values()):
        try: ev.set()
        except: pass
    for th in list(display_threads.values()):
        try:
            if th and th.is_alive():
                th.join(timeout=1)
        except: pass
    display_threads.clear()
    display_stops.clear()

    for cid, cap in list(cameras.items()):
        try:
            if cap and cap.isOpened():
                cap.release()
        except: pass
        cameras.pop(cid, None)

    # --- เปิดทุกกล้องตามรายการ + ตั้งค่า ---
    opened = []
    for idx in cam_indices:
        cap, be = _try_open_camera_on_index(idx)
        if cap is None:
            print(f"⚠️ open camera {idx} failed"); continue

        # พยายาม 1280x720@60 ถ้าไม่ไหวลดเป็น 640x480@60
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        cap.set(cv2.CAP_PROP_FPS, 60)
        try:
            fps = cap.get(cv2.CAP_PROP_FPS) or 0
        except Exception:
            fps = 0
        if fps < 59:
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            cap.set(cv2.CAP_PROP_FPS, 60)

        for _ in range(12):  # flush หลังตั้งค่า
            cap.read()

        cameras[idx] = cap
        display_stops[idx] = threading.Event()
        th = threading.Thread(target=display_worker, args=(idx,), daemon=True)
        th.start()
        display_threads[idx] = th
        opened.append(idx)
        print(f"✅ Camera opened index={idx}, backend={be}")

    if not opened:
        return _corsify(jsonify({"error": "Unable to open any webcam"})), 500

    # กล้องหลัก (สำหรับ detector) = ตัวแรกในลิสต์
    primary_cam_id = opened[0]

    # รีเซ็ตบัฟเฟอร์ภาพทั้งหมด
    with latest_lock:
        for cid in opened:
            latest_frame_map[cid] = None
            latest_jpeg_map[cid]  = None
            latest_ts_map[cid]    = 0.0
        latest_gen += 1

    current_location_id = location_id

    # รีสตาร์ต detection worker
    try:
        if detector_thread and detector_thread.is_alive():
            detector_stop.set()
            detector_thread.join(timeout=1)
    except Exception:
        pass
    detector_stop = threading.Event()
    detector_thread = threading.Thread(target=detection_worker, daemon=True)
    detector_thread.start()

    base = request.host_url.rstrip("/")
    streams = [f"{base}/frame_raw?cam={cid}" for cid in opened]

    return _corsify(jsonify({
        "message": "Cameras started",
        "opened": opened,
        "streams": streams,
        "location_id": current_location_id,
        "generation": latest_gen
    })), 200



# ------------------------- STOP CAMERA ----------------------------------------
@app.route("/stop-camera", methods=["POST", "OPTIONS"])
def stop_camera():
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    global primary_cam_id, detector_thread

    # stop display threads
    for ev in list(display_stops.values()):
        try: ev.set()
        except: pass
    for th in list(display_threads.values()):
        try:
            if th and th.is_alive():
                th.join(timeout=1)
        except: pass
    display_threads.clear()
    display_stops.clear()

    # release cameras
    for cid, cap in list(cameras.items()):
        try:
            if cap and cap.isOpened():
                cap.release()
        except: pass
        cameras.pop(cid, None)

    # stop detection worker
    try:
        detector_stop.set()
        if detector_thread and detector_thread.is_alive():
            detector_thread.join(timeout=1)
    except Exception:
        pass
    detector_thread = None

    # clear buffers
    with latest_lock:
        latest_frame_map.clear()
        latest_jpeg_map.clear()
        latest_ts_map.clear()

    primary_cam_id = None

    # reset model/session flags (คงตามไฟล์เดิมของคุณ)
    # current_model = None; model_type = None; active_model_url = None
    # current_location_id = None

    return _corsify(jsonify({"message": "Cameras stopped"})), 200


def display_worker(cam_id: int):
    """
    อ่านกล้อง cam_id → resize → (optional enhance) → encode JPEG
    อัปเดต latest_*_map[cam_id]; ถ้าเป็น cam หลัก อัปเดต alias legacy ด้วย
    """
    fps_interval = 1.0 / max(1.0, DISPLAY_FPS)

    while not display_stops[cam_id].is_set():
        try:
            cap = cameras.get(cam_id)
            if cap is None or not cap.isOpened():
                time.sleep(0.02); continue

            ok, img = cap.read()
            if not ok or img is None or img.size == 0:
                time.sleep(0.005); continue

            h, w = img.shape[:2]
            if TARGET_DISPLAY_WIDTH > 0 and w > TARGET_DISPLAY_WIDTH:
                r = TARGET_DISPLAY_WIDTH / float(w)
                img = cv2.resize(img, (TARGET_DISPLAY_WIDTH, int(h*r)), interpolation=cv2.INTER_AREA)

            disp = enhance_lowlight(img) if APPLY_ENHANCE_FOR_DISPLAY else img

            ok2, buf = cv2.imencode(".jpg", disp, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY_DISPLAY])
            if ok2:
                now = time.time()
                with latest_lock:
                    latest_frame_map[cam_id] = disp
                    latest_jpeg_map[cam_id]  = buf.tobytes()
                    latest_ts_map[cam_id]    = now
                    # อัปเดต alias legacy ให้โค้ดเก่าไม่พัง (ใช้ cam หลักเท่านั้น)
                    if primary_cam_id == cam_id:
                        global latest_frame, latest_jpeg, latest_ts
                        latest_frame = disp
                        latest_jpeg  = latest_jpeg_map[cam_id]
                        latest_ts    = now

            time.sleep(fps_interval)

        except Exception as e:
            print(f"display worker error (cam {cam_id}):", e)
            time.sleep(0.01)



# --- NEW: background detection worker (no overlay on image) ---
def detection_worker():
    """
    ดึงภาพจากกล้องหลัก (primary_cam_id) ผ่าน latest_frame_map แล้วทำ inference
    """
    global model_type, active_model_url, current_model, current_location_id

    while not detector_stop.is_set():
        try:
            with latest_lock:
                pid = primary_cam_id
                img = None if pid is None else latest_frame_map.get(pid)
                img = None if img is None else img.copy()

            if img is None:
                time.sleep(0.02)
                continue

            enhanced = enhance_lowlight(img)

            if model_type == "roboflow" and active_model_url:
                rf_url = f"{active_model_url}&confidence={RF_MIN_CONF}&overlap=20"
                _, buf = cv2.imencode(".jpg", enhanced, [int(cv2.IMWRITE_JPEG_QUALITY), _JPEG_QUALITY_RF])
                b64 = base64.b64encode(buf).decode("utf-8")
                r = requests.post(rf_url, json={"image": b64}, timeout=8)
                _ = r.json().get("predictions", [])
                # TODO: บันทึกผลตามต้องการ

            elif model_type == "local" and current_model is not None:
                _ = current_model(enhanced)
                # TODO: แปลงผล/บันทึก

            time.sleep(0.20)  # ~5Hz

        except Exception as e:
            print("infer worker error:", e)
            time.sleep(0.2)




@app.route("/frame_raw", methods=["GET", "OPTIONS"])
def frame_raw():
    """
    ส่ง JPEG เฟรมล่าสุดของกล้องที่เลือก (?cam=<id>)
    รองรับ min_ts/min_gen และรอสั้นๆ เพื่อให้ได้เฟรมสด
    """
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    def _jpeg_resp(b: bytes, generation=None):
        resp = make_response(b, 200)
        resp.mimetype = "image/jpeg"
        resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        resp.headers["Pragma"] = "no-cache"
        resp.headers["Expires"] = "0"
        if generation is not None:
            resp.headers["X-Frame-Generation"] = str(generation)
        return _corsify(resp)

    try:
        cam_id = int(request.args.get("cam", str(primary_cam_id if primary_cam_id is not None else 0)))
    except Exception:
        cam_id = primary_cam_id if primary_cam_id is not None else 0

    try:
        min_ts = float(request.args.get("min_ts", "0"))
    except Exception:
        min_ts = 0.0

    try:
        min_gen = int(request.args.get("min_gen", "0"))
    except Exception:
        min_gen = 0

    max_wait_sec = 0.30
    staleness_limit = 0.5
    deadline = time.time() + max_wait_sec

    while time.time() < deadline:
        with latest_lock:
            data = latest_jpeg_map.get(cam_id)
            ts   = latest_ts_map.get(cam_id, 0.0)
            gen  = latest_gen

        if (data and ts > min_ts and gen >= min_gen and (time.time() - ts) <= staleness_limit):
            return _jpeg_resp(data, gen)
        time.sleep(0.01)

    # fallback: placeholder
    black = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(black, f"WAITING... CAM {cam_id}", (50, 240),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
    ok2, jpg = cv2.imencode(".jpg", black, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
    return _jpeg_resp(jpg.tobytes() if ok2 else black.tobytes())



# 🚀 เพิ่ม cleanup เมื่อปิด app
@app.teardown_appcontext
def cleanup_connections(error):
    with smtp_lock:
        while smtp_pool:
            server = smtp_pool.pop()
            try:
                server.quit()
            except:
                pass

if __name__ == "__main__":
    print(app.url_map)
    app.run(debug=True, threaded=True) 