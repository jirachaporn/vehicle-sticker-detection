import os
from concurrent.futures import ThreadPoolExecutor
import httpx
from supabase import create_client
from datetime import datetime, timedelta
import random
import string

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)
executor = ThreadPoolExecutor(max_workers=3)


def _generate_otp(length=4):
    return ''.join(random.choices(string.digits, k=length))


def create_and_send_otp(email: str) -> tuple[bool, str]:
    """สร้าง OTP และบันทึกลง Supabase"""
    if not email:
        return False, "Email is required"

    otp = _generate_otp()
    expires_at = (datetime.utcnow() + timedelta(minutes=5)).isoformat()

    try:
        supabase.table("otp_log").insert({
            "by_email": email,
            "otp_code": otp,
            "otp_used": False,            # ✅ เปลี่ยนชื่อให้ตรงกับ DB
            "otp_type": "reset_password",
            "expires_at": expires_at
        }).execute()

        # 🔹 TODO: ส่ง OTP ผ่าน Email
        print(f"📩 OTP for {email}: {otp}")

        return True, otp
    except Exception as e:
        print(f"🔥 Error creating OTP: {e}")
        return False, str(e)


def verify_otp(email: str, otp: str) -> tuple[bool, str]:
    """ตรวจสอบ OTP ผ่าน Supabase"""
    if not email or not otp:
        return False, "Email and OTP are required"

    try:
        result = supabase.table("otp_log") \
            .select("otp_id") \
            .eq("by_email", email) \
            .eq("otp_code", otp) \
            .eq("otp_used", False) \
            .eq("otp_type", "reset_password") \
            .gt("expires_at", datetime.utcnow().isoformat()) \
            .order("created_at", desc=True) \
            .limit(1) \
            .execute()

        if result.data and len(result.data) > 0:
            record_id = result.data[0]["otp_id"]

            # mark OTP as used (non-blocking)
            def _update():
                supabase.table("otp_log").update({
                    "otp_used": True,  
                    "otp_success": True
                }).eq("otp_id", record_id).execute()

            executor.submit(_update)
            return True, "OTP is valid"

        return False, "OTP is incorrect or expired"
    except Exception as e:
        print(f"🔥 Error verifying OTP: {e}")
        return False, str(e)


def reset_user_password(email: str, new_password: str) -> tuple[bool, str]:
    """รีเซ็ตรหัสผ่าน Supabase Auth หลังจาก verify OTP"""
    if not email or not new_password:
        return False, "Email and new password are required"

    project_id = SUPABASE_URL.split("//")[1].split(".")[0]
    headers = {
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE}",
        "apikey": SUPABASE_SERVICE_ROLE,
        "Content-Type": "application/json",
    }

    try:
        with httpx.Client(timeout=httpx.Timeout(10.0)) as client:
            get_url = f"https://{project_id}.supabase.co/auth/v1/admin/users"
            response = client.get(get_url, headers=headers, params={"email": email})

            if response.status_code != 200:
                return False, "Cannot fetch users"

            data_response = response.json()
            all_users = data_response.get("users", data_response) if isinstance(data_response, dict) else data_response
            target_user = next((u for u in all_users if u.get("email", "").lower() == email.lower()), None)

            if not target_user:
                return False, f"User with email {email} not found"

            # อัปเดตรหัสผ่าน
            user_id = target_user["id"]
            put_url = f"https://{project_id}.supabase.co/auth/v1/admin/users/{user_id}"
            put_res = client.put(put_url, headers=headers, json={"password": new_password})

            if put_res.status_code == 200:
                return True, "Password updated successfully"
            else:
                error_detail = put_res.json() if put_res.text else {"error": "Unknown error"}
                return False, f"Failed to update password: {error_detail}"

    except Exception as e:
        print(f"🔥 Exception resetting password: {repr(e)}")
        return False, str(e)


def reset_password_with_otp(email: str, otp: str, new_password: str) -> tuple[bool, str]:
    """Verify OTP แล้ว reset password ในขั้นตอนเดียว"""
    valid, msg = verify_otp(email, otp)
    if not valid:
        return False, f"OTP verification failed: {msg}"

    return reset_user_password(email, new_password)
