# api_service/locations.py
import os
import time
import pytz
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
from supabase import create_client

# ---- setup ----
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)
executor = ThreadPoolExecutor(max_workers=3)
tz = pytz.timezone("Asia/Bangkok")


# ---------- Utility ----------
def _get_user_role(email: str):
    if not email:
        return None
    try:
        r = supabase.table("users").select("user_role").eq("user_email", email).limit(1).execute()
        if r.data and len(r.data) > 0:
            return (r.data[0].get("user_role") or "").lower()
    except Exception as e:
        print(f"⚠️ _get_user_role_by_email error for {email}: {e}")
    return None

def _is_admin(email: str) -> bool:
    return _get_user_role(email) == "admin"

def _exec_with_retry(builder, retries=1, delay=0.25):
    try:
        return builder.execute()
    except Exception as e:
        msg = str(e)
        if any(k in msg for k in ["WinError 10035", "timed out", "Connection"]) and retries > 0:
            time.sleep(delay)
            return _exec_with_retry(builder, retries - 1, delay)
        raise


# ---------- GET LOCATIONS ----------
def get_locations(user_email: str):
    if not user_email:
        return False, "User email is required", []

    try:
        if _is_admin(user_email):
            print(f"🔑 Admin detected: {user_email}, returning ALL locations")
            loc_res = _exec_with_retry(
                supabase.table("locations")
                .select("location_id, location_name, location_address, location_description, location_color, created_at, location_license")
                .order("created_at", desc=True)
            )
            locations = loc_res.data or []
        else:
            print(f"🔍 Fetching locations for {user_email}")
            mem_res = _exec_with_retry(
                supabase.table("location_members")
                .select("location_id")
                .eq("member_email", user_email)
            )
            loc_ids = [m.get("location_id") for m in (mem_res.data or []) if m.get("location_id")]
            if not loc_ids:
                return True, "No locations found", []
            loc_res = _exec_with_retry(
                supabase.table("locations")
                .select("location_id, location_name, location_address, location_description, location_color, created_at, location_license")
                .in_("location_id", loc_ids)
                .order("created_at", desc=True)
            )
            locations = loc_res.data or []

        result = [
            {
                "locations_id": loc.get("location_id"),
                "name": loc.get("location_name"),
                "address": loc.get("location_address"),
                "description": loc.get("location_description"),
                "color": loc.get("location_color"),
                "created_at": loc.get("created_at"),
                "location_license": loc.get("location_license"),
            }
            for loc in locations
        ]
        return True, "OK", result
    except Exception as e:
        print(f"🔥 ERROR during get_locations: {e}")
        return False, str(e), []


# ---------- CREATE LOCATION ----------
def save_location(data: dict):
    try:
        for field in ["name", "owner_email"]:
            if not (data.get(field) or "").strip():
                return False, f"{field} is required", None

        owner_email = (data["owner_email"] or "").strip().lower()
        owner_name = owner_email.split("@", 1)[0].strip() or None
        now_ts = datetime.now(tz).isoformat()

        location_data = {
            "location_name": (data.get("name") or "").strip(),
            "location_address": (data.get("address") or "").strip(),
            "location_description": (data.get("description") or "").strip(),
            "location_color": (data.get("color") or "#1565C0").strip(),
            "created_at": now_ts,
        }

        def insert_location():
            return supabase.table("locations").insert(location_data).execute()

        result = executor.submit(insert_location).result(timeout=5)
        if not result.data:
            return False, "Failed to create location", None

        new_id = result.data[0]["location_id"]
        print(f"✅ Location saved with ID: {new_id}")

        owner_row = {
            "location_id": new_id,
            "member_email": owner_email,
            "member_name": owner_name,
            "member_permission": "owner",
        }

        try:
            supabase.table("location_members").insert(owner_row).execute()
        except Exception as e:
            supabase.table("locations").delete().eq("location_id", new_id).execute()
            print(f"❌ create owner membership failed: {e}")
            return False, "Failed to create owner membership", None

        return True, "Location created successfully", {
            "id": new_id,
            "location": result.data[0],
        }
    except Exception as e:
        print(f"🔥 ERROR during save_location: {e}")
        return False, str(e), None


# ---------- UPDATE LOCATION ----------
def update_location(location_id: str, data: dict):
    try:
        update_data = {k: v for k, v in {
            "location_name": data.get("name"),
            "location_address": data.get("address"),
            "location_description": data.get("description"),
            "location_color": data.get("color"),
        }.items() if v is not None}

        resp = supabase.table("locations").update(update_data).eq("location_id", location_id).execute()
        if resp.data:
            return True, "Location updated successfully"
        return False, "Location not found"
    except Exception as e:
        print(f"🔥 ERROR during update_location: {e}")
        return False, str(e)


# ---------- DELETE LOCATION ----------
def delete_location(location_id: str):
    try:
        try:
            supabase.table("location_members").delete().eq("location_id", location_id).execute()
            supabase.table("model").delete().eq("location_id", location_id).execute()
            supabase.table("detections").delete().eq("location_id", location_id).execute()
        except Exception:
            pass

        res = supabase.table("locations").delete().eq("location_id", location_id).execute()
        if res.data:
            return True, "Location deleted"
        return False, "Location not found"
    except Exception as e:
        print(f"🔥 ERROR during delete_location: {e}")
        return False, str(e)
