# api_service/email_service.py
from ..utils.email_utils import generate_otp, send_otp_email, send_permission_link_email

def create_and_send_otp(email: str) -> bool:
    otp = generate_otp()
    success = send_otp_email(email, otp)
    return success, otp

def send_permission_email(to_email: str, link_url: str, invited_name: str = "", location_name: str = "your workspace"):
    subject = (
        f"Automated Vehicle Tagging System - Confirm access to {location_name}"
        if location_name else
        "Automated Vehicle Tagging System - Confirm your access"
    )

    success = send_permission_link_email(
        to_email,
        link_url,
        invited_name=invited_name,
        location_name=location_name,
        subject=subject
    )
    return success