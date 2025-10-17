# reset_password.py 
from fastapi import APIRouter
from pydantic import BaseModel
from ..api_service.reset_password import (
    create_and_send_otp,
    verify_otp,
    reset_password_with_otp
)

router = APIRouter()

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
