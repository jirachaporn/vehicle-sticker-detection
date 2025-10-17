# utils/email_utils.py
import random
import threading
from email.mime.text import MIMEText
from email.header import Header
import smtplib
import os

EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD")

# Pre-connect SMTP connection pool
smtp_lock = threading.Lock()
smtp_pool = []

def create_smtp_connection():
    """สร้าง SMTP connection แบบ reusable"""
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
    if server and len(smtp_pool) < 2:
        with smtp_lock:
            smtp_pool.append(server)
    elif server:
        try:
            server.quit()
        except:
            pass

def generate_otp() -> str:
    """สร้าง OTP 4 หลัก"""
    return ''.join([str(random.randint(0, 9)) for _ in range(4)])

def _build_otp_email_html(otp: str) -> str:
    """สร้าง HTML ของ OTP สำหรับส่งอีเมล"""
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

def send_otp_email(to_email: str, otp: str) -> bool:
    """ส่ง OTP แบบ HTML-only"""
    server = get_smtp_connection()
    if not server:
        return False

    try:
        html = _build_otp_email_html(otp)
        msg = MIMEText(html, "html", "utf-8")
        msg["Subject"] = "Automated Vehicle Tagging System - Your OTP for Password Reset"
        msg["From"] = EMAIL_ADDRESS
        msg["To"] = to_email

        server.send_message(msg)
        return_smtp_connection(server)
        return True
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        try:
            server.quit()
        except:
            pass
        return False


# ---------- สร้าง HTML อีเมลลิงก์ ----------
def _build_link_email_html(invited_name: str, location_name: str, link_url: str) -> str:
    name = (invited_name or "").strip()
    greet = f"Hi {name}," if name else "Hi there,"
    loc = (location_name or "your workspace").strip()

    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#111;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
        <tr>
            <td align="center" style="padding:24px;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:600px;background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.05);overflow:hidden;">
                <tr><td style="padding:28px 28px 8px 28px;">
                    <h1 style="margin:0 0 8px 0;font-size:20px;line-height:1.3;color:#111;">Confirm your access</h1>
                    <p style="margin:0 0 16px 0;font-size:14px;color:#444;">{greet}</p>
                    <p style="margin:0 0 16px 0;font-size:14px;color:#444;">
                    You’ve been invited to access <strong>{loc}</strong>. Please confirm your access using the button below.
                    </p>
                </td></tr>
                <tr><td align="left" style="padding:0 28px 20px 28px;">
                    <a href="{link_url}" style="display:inline-block;padding:12px 18px;border-radius:8px;background:#2563eb;color:#ffffff;text-decoration:none;font-weight:600;">
                    Confirm access
                    </a>
                </td></tr>
                <tr><td style="padding:0 28px 24px 28px;">
                    <p style="margin:0 0 8px 0;font-size:12px;color:#666;">
                    If the button doesn’t work, copy and paste this link into your browser:
                    </p>
                    <p style="margin:0;font-size:12px;word-break:break-all;">
                    <a href="{link_url}" style="color:#2563eb;text-decoration:underline;">{link_url}</a>
                    </p>
                </td></tr>
                <tr><td style="padding:0 28px 28px 28px;border-top:1px solid #eee;">
                    <p style="margin:12px 0 0 0;font-size:12px;color:#999;">
                    If you didn’t request or expect this invitation, you can safely ignore this email.
                    </p>
                </td></tr>
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

def send_permission_link_email(
    to_email: str,
    link_url: str,
    *,
    invited_name: str = "",
    location_name: str = "your workspace",
    subject: str = "Confirm your access"
) -> bool:
    """ส่งอีเมลยืนยันลิงก์แบบ HTML"""
    if not to_email or not link_url:
        print("❌ to_email or link_url is empty")
        return False

    server = get_smtp_connection()
    if not server:
        return False

    try:
        html = _build_link_email_html(invited_name, location_name, link_url)
        msg = MIMEText(html, "html", "utf-8")
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