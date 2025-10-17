# utils/notify_rules.py
from typing import Dict, Optional

SEVERITY_INFO = "info"
SEVERITY_WARNING = "warning"
SEVERITY_CRITICAL = "critical"

STATUS_NEW = "new"
STATUS_READ = "read"
STATUS_DISMISSED = "dismissed"

def _lower(s, default=""):
    return (s or default).lower()

def classify_notification(
    detection_row: Dict,*,
    is_registered: Optional[bool] = None,
    location_license: Optional[str] = None,
    registration: Optional[Dict] = None, 
) -> Optional[Dict]:
    """
    รับแถว detections + ผลตรวจสิทธิ์ แล้วคืนพารามิเตอร์สำหรับ insert ลง notifications
    ตาม 4 Scenario:
    1) Vehicle YES + Sticker YES + Registered(TRUE)   -> Authorized (info)
    2) Vehicle YES + Sticker YES + Registered(FALSE)  -> Unauthorized (warning)
    3) Vehicle NO/unknown + Sticker YES               -> Suspicious (warning)
    4) Vehicle NO/unknown + Sticker NO                -> Abnormal/Critical (critical)
    หมายเหตุ: หาก Vehicle YES + Sticker NO (เผื่อกรณีจริง) จะถือเป็น Unauthorized (warning)
    """
    dp = detection_row.get("detected_plate") or {}
    is_sticker = bool(detection_row.get("is_sticker"))
    is_vehicle = _lower(dp.get("is_vehicle"), "unknown")
    ocr_status = dp.get("status")
    lp = dp.get("lp_number")
    province = dp.get("province")
    direction = _lower(detection_row.get("direction"), "in")
    image_paths = detection_row.get("image_path") or []
    first_image = image_paths[0] if image_paths else None

    base_meta = {
        "lp_number": lp,
        "province": province,
        "direction": direction,
        "image_path": image_paths,
        "is_sticker": is_sticker,
        "is_vehicle": is_vehicle,
        "ocr_status": ocr_status,
        "location_license": location_license,
        "registration": registration or {"is_registered": is_registered}
    }

    # === Scenario 1: Registered + Sticker + Vehicle YES ===
    if is_vehicle == "yes" and is_sticker and is_registered is True:
        return {
            "title": "Authorized Vehicle",
            "message": f"Registered plate {lp or 'unknown'} at {location_license} ({direction}).",
            "severity": SEVERITY_INFO,
            "image_url": first_image,
            "notification_status": STATUS_NEW,
            "is_read": False,
            "meta": {**base_meta, "reason_codes": ["REGISTERED_WITH_STICKER"]}
        }

    # === Scenario 2: NOT Registered + Sticker + Vehicle YES ===
    if is_vehicle == "yes" and is_sticker and (is_registered is False):
        return {
            "title": "Sticker Shown but Plate Not Registered",
            "message": f"Plate {lp or 'unknown'} not found in {location_license} ({direction}).",
            "severity": SEVERITY_WARNING,
            "image_url": first_image,
            "notification_status": STATUS_NEW,
            "is_read": False,
            "meta": {**base_meta, "reason_codes": ["STICKER_WITH_UNREGISTERED_PLATE"]}
        }

    # === Scenario 3: Vehicle NO/unknown + Sticker YES ===
    if is_vehicle != "yes" and is_sticker:
        return {
            "title": "Suspicious: Sticker Only",
            "message": f"Sticker detected but no readable vehicle/plate ({direction}).",
            "severity": SEVERITY_WARNING,
            "image_url": first_image,
            "notification_status": STATUS_NEW,
            "is_read": False,
            "meta": {**base_meta, "reason_codes": ["STICKER_ONLY_NO_VEHICLE_OR_PLATE"]}
        }

    # (กรณีจริง: Vehicle YES + Sticker NO → ไม่อยู่ใน 4 scenario ใหม่ แต่เพื่อความปลอดภัยให้จัดเป็น Unauthorized)
    if is_vehicle == "yes" and not is_sticker:
        return {
            "title": "Unauthorized: Vehicle Without Sticker",
            "message": f"Plate {lp or 'unknown'} entered without sticker ({direction}).",
            "severity": SEVERITY_WARNING,
            "image_url": first_image,
            "notification_status": STATUS_NEW,
            "is_read": False,
            "meta": {**base_meta, "reason_codes": ["VEHICLE_WITHOUT_STICKER"]}
        }

    # === Scenario 4: Vehicle NO/unknown + Sticker NO ===
    return {
        "title": "Critical: No Vehicle, No Sticker",
        "message": "Abnormal trigger (no vehicle and no sticker detected).",
        "severity": SEVERITY_CRITICAL,
        "image_url": first_image,
        "notification_status": STATUS_NEW,
        "is_read": False,
        "meta": {**base_meta, "reason_codes": ["NO_VEHICLE_NO_STICKER"]}
    }