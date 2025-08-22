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

camera = None
current_model = None
model_type = None               # "roboflow" | "local"
active_model_url = None
RF_MIN_CONF = float(os.getenv("RF_MIN_CONF", "0.25"))  # ปรับ threshold ได้จาก .env
_JPEG_QUALITY_RF = 85  # คมขึ้นตอนส่งให้โมเดล (รักษารายละเอียด)

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
from email.mime.text import MIMEText
from email.header import Header

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
        print(f"🔍 Fetching locations for user: {user_email}")

        # 1. Owner
        owned_result = supabase.table("locations") \
            .select("*") \
            .eq("owner_email", user_email) \
            .order("created_at", desc=True) \
            .execute()

        # 2. Shared
        shared_result = supabase.table("locations") \
            .select("*") \
            .contains("shared_with", json.dumps([{"email": user_email}])) \
            .order("created_at", desc=True) \
            .execute()

        # 3. Merge and deduplicate
        unique = {}
        for loc in (owned_result.data or []) + (shared_result.data or []):
            loc_id = loc.get("locations_id")  # ✅ uuid
            if loc_id and loc_id not in unique:
                unique[loc_id] = loc

        # 4. Build response
        result = []
        for loc in unique.values():
            result.append({
                "locations_id": loc.get("locations_id"),
                "name": loc.get("location_name"),
                "address": loc.get("address"),
                "description": loc.get("description"),
                "color": loc.get("color"),
                "owner_email": loc.get("owner_email"),
                "shared_with": loc.get("shared_with", []),
                "created_at": loc.get("created_at"),
            })

        print(f"✅ Found {len(result)} locations for {user_email}")
        return jsonify(result), 200

    except Exception as e:
        print(f"🔥 ERROR during /locations:", e)
        return jsonify({"error": str(e)}), 500



@app.route("/save_locations", methods=["POST"])
def save_locations():
    """
    POST body:
    {
        "name": "Location Name",
        "address": "Address",
        "description": "Description",
        "color": "#FF0000",
        "owner_email": "user@example.com",
        "shared_with": [{"email": "user2@example.com"}]
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Request body is required"}), 400

        for field in ["name", "owner_email"]:
            if not data.get(field):
                return jsonify({"error": f"{field} is required"}), 400

        print(f"💾 Saving location: {data['name']} for {data['owner_email']}")

        # ✅ Clean JSON fields
        shared_with = data.get("shared_with", [])
        if not isinstance(shared_with, list):
            shared_with = []

        location_data = {
            "location_name": data.get("name"),
            "address": data.get("address", ""),
            "description": data.get("description", ""),
            "color": data.get("color", "#000000"),
            "owner_email": data.get("owner_email"),
            "shared_with": shared_with,
            "created_at": created_at,
        }

        def insert_location():
            return supabase.table("locations").insert(location_data).execute()

        insert_future = executor.submit(insert_location)
        result = insert_future.result(timeout=5)

        if result.data and len(result.data) > 0:
            new_id = result.data[0]["locations_id"]  # ✅ uuid
            print(f"✅ Location saved successfully with ID: {new_id}")

            return jsonify({
                "message": "Location created successfully",
                "id": new_id,
                "location": result.data[0]
            }), 201
        else:
            return jsonify({"error": "Failed to create location"}), 500

    except Exception as e:
        print(f"🔥 ERROR during /save_locations: {e}")
        return jsonify({"error": str(e)}), 500
    
    
@app.route('/update_location/<location_id>', methods=['PUT'])
def update_location(location_id):
    try:
        data = request.get_json()

        update_data = {
            "location_name": data.get("name"), 
            "address": data.get("address"),
            "description": data.get("description"),
            "color": data.get("color"),
            "shared_with": data.get("shared_with", [])
        }

        response = supabase.table("locations") \
            .update(update_data) \
            .eq("locations_id", location_id) \
            .execute()

        if response.data:
            return jsonify({"message": "Location updated successfully"}), 200
        else:
            return jsonify({"message": "Location not found"}), 404

    except Exception as e:
        return jsonify({"message": str(e)}), 500
    
    
    
@app.route('/delete_location/<location_id>', methods=['DELETE'])
def delete_location(location_id):
    try:
        res = supabase.table("locations") \
            .delete() \
            .eq("locations_id", location_id) \
            .execute()

        if res.data:
            return jsonify({"message": "Location deleted"}), 200
        else:
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



# --- ปรับ /start-camera ให้ใช้ CAP_DSHOW + ตั้งความละเอียด + วอร์มอัพ ---
@app.route("/start-camera", methods=["POST", "OPTIONS"])
def start_camera():
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    global camera, current_model, model_type, active_model_url, _frame_idx

    data = request.get_json() or {}
    location_id = data.get("location_id")
    if not location_id:
        return _corsify(jsonify({"error": "location_id is required"})), 400

    # หา active model
    model_res = supabase.table("model") \
        .select("model_name, model_url") \
        .eq("location_id", location_id) \
        .eq("is_active", True) \
        .limit(1).execute()
    if not model_res.data:
        return _corsify(jsonify({"error": "No active model for this location"})), 404

    row = model_res.data[0]
    db_model_name = (row.get("model_name") or "").strip()
    db_model_url = (row.get("model_url") or "").strip()

    # ปล่อยกล้องเก่า
    try:
        if camera is not None and camera.isOpened():
            camera.release()
    except:
        pass

    # เปิดกล้อง
    camera = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not camera.isOpened():
        return _corsify(jsonify({"error": "Unable to access webcam"})), 500

    camera.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    camera.set(cv2.CAP_PROP_FPS, 30)

    # warmup
    for _ in range(8):
        camera.read()

    # ตัดสินใจใช้ RF หรือ local
    active_model_url = None
    current_model = None
    model_type = None
    if db_model_url:
        if "detect.roboflow.com" in db_model_url:
            if "api_key=" not in db_model_url:
                if not ROBOFLOW_API_KEY:
                    return _corsify(jsonify({"error": "ROBOFLOW_API_KEY is missing in .env"})), 500
                sep = "&" if "?" in db_model_url else "?"
                active_model_url = f"{db_model_url}{sep}api_key={ROBOFLOW_API_KEY}"
            else:
                active_model_url = db_model_url
            model_type = "roboflow"
        else:
            if torch is None:
                return _corsify(jsonify({"error": "PyTorch is not available for local .pt"})), 500
            try:
                with tempfile.NamedTemporaryFile(suffix=".pt", delete=False) as tmp:
                    urllib.request.urlretrieve(db_model_url, tmp.name)
                    current_model = torch.hub.load('ultralytics/yolov5', 'custom', path=tmp.name)
                model_type = "local"
            except Exception as e:
                return _corsify(jsonify({"error": f"Failed to download/load model: {e}"})), 500
    elif db_model_name:
        if not ROBOFLOW_API_KEY:
            return _corsify(jsonify({"error": "ROBOFLOW_API_KEY is missing in .env"})), 500
        active_model_url = f"{ROBOFLOW_BASE_URL}/{db_model_name}?api_key={ROBOFLOW_API_KEY}"
        model_type = "roboflow"
    else:
        return _corsify(jsonify({"error": "No model_url or model_name provided"})), 500

    # ถ้าใช้ RF ลดความถี่ดึงเฟรมลงอีกนิด
    global _infer_every
    _infer_every = 3 if model_type == "roboflow" else 1
    _frame_idx = 0

    return _corsify(jsonify({"message": "Camera started", "model_type": model_type})), 200

# ------------------------- STOP CAMERA ----------------------------------------
@app.route("/stop-camera", methods=["POST", "OPTIONS"])
def stop_camera():
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    global camera, current_model, model_type, active_model_url
    try:
        if camera is not None and camera.isOpened():
            camera.release()
    except:
        pass
    camera = None
    current_model = None
    model_type = None
    active_model_url = None
    return _corsify(jsonify({"message": "Camera stopped"})), 200

# --------------------------- FRAME --------------------------------------------
@app.route("/frame", methods=["GET", "OPTIONS"])
def frame():
    if request.method == "OPTIONS":
        return _corsify(make_response(("", 200)))

    global camera, current_model, model_type, active_model_url, _frame_idx

    if camera is None or not camera.isOpened():
        return _corsify(jsonify({"error": "Camera not running"})), 400

    ok, img = camera.read()
    if not ok or img is None:
        black = np.zeros((480, 640, 3), dtype=np.uint8)
        cv2.putText(black, "No frame from camera", (20, 240),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        ok2, jpeg2 = cv2.imencode(".jpg", black, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        resp = make_response(jpeg2.tobytes(), 200)
        resp.mimetype = "image/jpeg"
        return _corsify(resp)

    # ---------- ปรับแสงก่อนวิเคราะห์ ----------
    enhanced = enhance_lowlight(img)

    annotated = enhanced.copy()
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    cv2.putText(annotated, f"TS: {ts}", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    # ทำ inference เฉพาะทุก N เฟรม (ลดภาระ)
    _frame_idx = (_frame_idx + 1) % _infer_every
    do_infer = (_frame_idx == 0)

    try:
        if do_infer and model_type == "roboflow" and active_model_url:
            # เพิ่มพารามิเตอร์ Roboflow: confidence ต่ำลง + overlap
            rf_url = f"{active_model_url}&confidence={RF_MIN_CONF}&overlap=20"
            # เข้ารหัสภาพคุณภาพสูงขึ้นตอนส่งให้โมเดล
            _, buf = cv2.imencode(".jpg", enhanced, [int(cv2.IMWRITE_JPEG_QUALITY), _JPEG_QUALITY_RF])
            b64 = base64.b64encode(buf).decode("utf-8")
            r = requests.post(rf_url, json={"image": b64}, timeout=8)
            preds = r.json().get("predictions", [])

            if preds:
                for p in preds:
                    x, y = int(p["x"]), int(p["y"])
                    w, h = int(p["width"]), int(p["height"])
                    label = p.get("class", "obj")
                    conf = p.get("confidence", 0)
                    cv2.rectangle(annotated, (x - w//2, y - h//2), (x + w//2, y + h//2), (0, 255, 0), 2)
                    cv2.putText(annotated, f"{label} {conf:.2f}",
                                (x - w//2, y - h//2 - 6),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            else:
                cv2.putText(annotated, "no predictions", (10, 60),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 200, 255), 2)

        elif do_infer and model_type == "local" and current_model is not None:
            results = current_model(enhanced)
            annotated = results.render()[0]
            cv2.putText(annotated, f"TS: {ts}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    except Exception as e:
        cv2.putText(annotated, f"infer err: {e}", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

    ok3, jpeg = cv2.imencode(".jpg", annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
    resp = make_response(jpeg.tobytes(), 200)
    resp.mimetype = "image/jpeg"
    return _corsify(resp)



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