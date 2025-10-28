# src/python/api_endpoint/routes_permission_notifications.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import os
from supabase import create_client, Client

router = APIRouter(prefix="/notifications/permission", tags=["notifications"])

def get_sb() -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE") or os.environ.get("SUPABASE_ANON_KEY")
    if not url or not key:
        raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE/ANON_KEY")
    return create_client(url, key)

class PermissionNotifyRequest(BaseModel):
    permission_log_id: str
    location_id: Optional[str] = None

# -------- Mapping & builders ---------
def map_action_and_severity(status: str, by_email: str, member_email: Optional[str]):
    status = (status or "").lower()
    if status == "invited":
        return "invited", "info"
    if status == "disabled":
        return "revoked", "critical"
    if status == "updatepermission":
        if member_email and by_email and by_email.lower() == member_email.lower():
            return "accepted", "info"
        return "updated", "info"
    return "updated", "info"

def build_title_message(action: str, row: dict, location_name: Optional[str] = None) -> tuple[str, str]:
    member_email = row.get("member_email")
    by_email = row.get("by_email")
    perm = (row.get("permission") or "").upper()  # VIEW | EDIT | OWNER
    loc_suffix = f" @ {location_name}" if location_name else ""

    if action == "invited":
        title = f"Invitation sent to {member_email}{loc_suffix}"
        msg = f"{by_email} invited {member_email} to access this location as {perm}{loc_suffix}."
    elif action == "accepted":
        title = f"Access accepted by {member_email}{loc_suffix}"
        msg = f"{member_email} accepted the invitation as {perm}{loc_suffix}."
    elif action == "updated":
        title = f"Permission updated for {member_email}{loc_suffix}"
        msg = f"{by_email} changed {member_email}'s permission to {perm}{loc_suffix}."
    elif action == "revoked":
        title = f"Access revoked for {member_email}{loc_suffix}"
        msg = f"{by_email} revoked access for {member_email}{loc_suffix}."
    else:
        title = f"Permission event for {member_email}{loc_suffix}"
        msg = f"Permission event: {action}{loc_suffix}."

    return title, msg

def exists_notification_for_log(sb: Client, permission_log_id: str) -> bool:
    q = (sb.table("notifications")
        .select("notifications_id", count="exact")
        .eq("meta->>permission_log_id", permission_log_id).limit(1).execute())
    return (q.count or 0) > 0

def get_location_name(sb: Client, location_id: str) -> Optional[str]:
    r = (sb.table("locations")
        .select("location_name")
        .eq("location_id", location_id).limit(1).execute())
    if r.data:
        return r.data[0].get("location_name")
    return None

def insert_notification(sb: Client, *, row: dict, action: str, severity: str, location_name: Optional[str]):
    title, message = build_title_message(action, row, location_name)
    payload = {
        "location_id": row["location_id"],
        "title": title,
        "message": message,
        "severity": severity,               # info | warning | critical
        "notification_status": "new",       # new | read
        "is_read": False,
        "meta": {
            "event": "PERMISSION",
            "action": action,
            "permission_log_id": row["permission_log_id"],
            "location_id": row["location_id"],
            "location_name": location_name,   
            "member": {
                "email": row.get("member_email"),
                "name": row.get("member_name"),
            },
            "permission": row.get("permission"),
            "status": row.get("status"),
            "by_email": row.get("by_email"),
            "created_at": row.get("created_at"),
        }
    }
    ins = sb.table("notifications").insert(payload).execute()
    return ins.data[0]["notifications_id"]

# Endpoint
@router.post("")
def create_from_permission_log(req: PermissionNotifyRequest):
    sb = get_sb()

    r = (sb.table("permission_log").select("*")
        .eq("permission_log_id", req.permission_log_id).limit(1).execute())
    if not r.data:
        raise HTTPException(status_code=404, detail="permission_log_id not found")

    row = r.data[0]

    if req.location_id and req.location_id != row["location_id"]:
        raise HTTPException(
            status_code=400,
            detail="location_id in body does not match permission_log.location_id")

    effective_location_id = row["location_id"] 
    location_name = get_location_name(sb, effective_location_id)

    if exists_notification_for_log(sb, req.permission_log_id):
        return {
            "ok": True,
            "duplicate": True,
            "permission_log_id": req.permission_log_id
        }

    action, severity = map_action_and_severity(row.get("status"), row.get("by_email"), row.get("member_email"))

    # insert notifications
    notifications_id = insert_notification(
        sb, row=row, action=action, severity=severity, location_name=location_name)

    # preview ให้ FE 
    title, message = build_title_message(action, row, location_name)
    return {
        "notifications_id": notifications_id,
        "action": action,
        "preview": {
            "title": title,
            "message": message,
            "severity": severity
        }
    }