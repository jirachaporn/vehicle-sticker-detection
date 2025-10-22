# api_endpoint/email_permission.py
from fastapi import APIRouter
from pydantic import BaseModel
from ..api_service.email_service import send_permission_email

router = APIRouter()

class PermissionEmailRequest(BaseModel):
    to_email: str
    link_url: str
    invited_name: str | None = "Unknown"
    location_name: str | None = "Unknown"

class PermissionEmailResponse(BaseModel):
    ok: bool
    error: str | None = None

@router.post("/send-permission", response_model=PermissionEmailResponse)
def send_permission_email_endpoint(req: PermissionEmailRequest):
    ok = send_permission_email(
        to_email=req.to_email,
        link_url=req.link_url,
        invited_name=req.invited_name,
        location_name=req.location_name
    )

    if not ok:
        return PermissionEmailResponse(ok=False, error="send email failed")
    return PermissionEmailResponse(ok=True)
