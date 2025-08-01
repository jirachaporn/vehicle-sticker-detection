from flask import Flask, request, jsonify
import os, random, smtplib
from email.mime.text import MIMEText
from dotenv import load_dotenv
from flask_cors import CORS
from supabase import create_client
from supabase.lib.client_options import ClientOptions
import httpx
from concurrent.futures import ThreadPoolExecutor
import threading
import json
import cloudinary
import cloudinary.uploader
from datetime import datetime
from datetime import datetime, timezone

load_dotenv()
app = Flask(__name__)
CORS(app)

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

# Supabase setup
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

# 🚀 Global thread pool executor สำหรับ async operations
executor = ThreadPoolExecutor(max_workers=3)

# 🚀 Pre-connect SMTP connection pool
smtp_lock = threading.Lock()
smtp_pool = []

def create_smtp_connection():
    """สร้าง SMTP connection แบบ reusable"""
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

# ✅ ส่งอีเมลด้วย SMTP (ปรับปรุงให้เร็วขึ้น)
def send_otp_email(to_email, otp):
    server = get_smtp_connection()
    if not server:
        return False
    
    try:
        msg = MIMEText(
            f"""To authenticate, please use the following One Time Password (OTP):\n\n{otp}\n\nThis OTP will be valid for 3 minutes."""
        )
        msg["Subject"] = "Your OTP for Password Reset"
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
            .execute()

        # 2. Shared
        shared_result = supabase.table("locations") \
            .select("*") \
            .contains("shared_with", json.dumps([{"email": user_email}])) \
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
            "shared_with": shared_with
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


@app.route("/upload-sticker-model", methods=["POST"])
def upload_sticker_model():
    try:
        model_name = request.form.get("model_name")  # ✅ ใช้ model_name ตรงกับ Flutter
        location_id = request.form.get("location_id")
        files = request.files.getlist("images")

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
                folder="stickers",
                resource_type="image",
                return_delete_token=True
            )

            image_urls.append(result["secure_url"])

        new_sticker = {
            "location_id": location_id,
            "model_name": model_name,
            "is_active": False,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "sticker_status": "processing",
            "image_urls": image_urls
        }

        res = supabase.table("stickers").insert(new_sticker).execute()

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
    app.run(debug=True, threaded=True)  # เปิด threading