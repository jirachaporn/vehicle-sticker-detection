from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import random, string
from supabase import create_client
import os
from ..utils.email_utils import send_otp_sign_email

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)
executor = ThreadPoolExecutor(max_workers=3)

def _generate_otp(length=4):
    return ''.join(random.choices(string.digits, k=length))

def create_and_send_signup_otp(email: str) -> tuple[bool, str]:
    """สร้าง OTP สำหรับสมัครและบันทึกลง otp_log"""
    if not email:
        return False, "Email is required"

    otp = _generate_otp()
    expires_at = (datetime.utcnow() + timedelta(minutes=5)).isoformat() + "Z"  # ✅ timezone ปลอดภัยกว่า

    try:
        record = {
            "by_email": email,
            "otp_code": otp,
            "reset_used": False,
            "reset_success": False,
            "expires_at": expires_at,
            "otp_type": "sign_up"
        }
        print("📩 Inserting OTP record:", record)

        res = supabase.table("otp_log").insert(record).execute()
        print("✅ Supabase insert result:", res)

        # ส่งอีเมล
        email_sent = send_otp_sign_email(email, otp, otp_type="sign_up")
        if not email_sent:
            print(f"❌ Failed to send signup OTP to {email}")

        return True, otp
    except Exception as e:
        print(f"🔥 Error creating signup OTP: {e}")
        return False, str(e)

def verify_signup_otp(email: str, otp: str) -> tuple[bool, str]:
    """ตรวจสอบ OTP สำหรับ sign up"""
    try:
        now = datetime.utcnow().isoformat() + "Z"
        result = supabase.table("otp_log") \
            .select("otp_id") \
            .eq("by_email", email) \
            .eq("otp_code", otp) \
            .eq("reset_used", False) \
            .eq("otp_type", "sign_up") \
            .gt("expires_at", now) \
            .order("created_at", desc=True) \
            .limit(1) \
            .execute()

        print("🔍 Verify result:", result.data)

        if result.data and len(result.data) > 0:
            record_id = result.data[0]["otp_id"]

            def _update():
                supabase.table("otp_log").update({
                    "reset_used": True,
                    "reset_success": True
                }).eq("otp_id", record_id).execute()

            executor.submit(_update)
            return True, "OTP is valid"

        return False, "OTP is incorrect or expired"
    except Exception as e:
        print(f"🔥 Error verifying signup OTP: {e}")
        return False, str(e)
