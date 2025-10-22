# api_endpoint/router_email.py
from fastapi import APIRouter
from pydantic import BaseModel
from ..api_service.reset_password import (
    create_and_send_otp,
    verify_otp,
    reset_password_with_otp
)
from ..api_service.sign_up_otp import create_and_send_signup_otp, verify_signup_otp

router = APIRouter()

# ---------------- Reset Password OTP Models ----------------
class OTPRequest(BaseModel):
    email: str

class OTPResponse(BaseModel):
    success: bool
    message: str

class VerifyOTPRequest(BaseModel):
    email: str
    otp: str

class VerifyOTPResponse(BaseModel):
    valid: bool
    message: str

class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

class ResetPasswordResponse(BaseModel):
    success: bool
    message: str

# ---------------- Signup OTP Models ----------------
class SignUpOTPRequest(BaseModel):
    email: str

class SignUpOTPResponse(BaseModel):
    success: bool
    message: str
    otp: str | None = None

class VerifySignUpOTPRequest(BaseModel):
    email: str
    otp: str

class VerifySignUpOTPResponse(BaseModel):
    valid: bool
    message: str

# ---------------- Reset Password OTP Endpoints ----------------
@router.post("/send-otp", response_model=OTPResponse)
def send_otp(req: OTPRequest):
    success, otp = create_and_send_otp(req.email)
    if success:
        return OTPResponse(success=True, message=f"OTP sent successfully to {req.email}")
    else:
        return OTPResponse(success=False, message=f"Failed to send OTP: {otp}")

@router.post("/verify-otp", response_model=VerifyOTPResponse)
def verify_otp_endpoint(req: VerifyOTPRequest):
    valid, message = verify_otp(req.email, req.otp)
    return VerifyOTPResponse(valid=valid, message=message)

@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_password_endpoint(req: ResetPasswordRequest):
    success, message = reset_password_with_otp(req.email, req.otp, req.new_password)
    return ResetPasswordResponse(success=success, message=message)

# ---------------- Signup OTP Endpoints ----------------
@router.post("/send-signup-otp", response_model=SignUpOTPResponse)
def send_signup_otp_endpoint(req: SignUpOTPRequest):
    success, otp = create_and_send_signup_otp(req.email)
    if success:
        return SignUpOTPResponse(success=True, message=f"Signup OTP sent successfully to {req.email}", otp=otp)
    else:
        return SignUpOTPResponse(success=False, message=f"Failed to send signup OTP: {otp}", otp=None)

@router.post("/verify-signup-otp", response_model=VerifySignUpOTPResponse)
def verify_signup_otp_endpoint(req: VerifySignUpOTPRequest):
    valid, message = verify_signup_otp(req.email, req.otp)
    return VerifySignUpOTPResponse(valid=valid, message=message)
