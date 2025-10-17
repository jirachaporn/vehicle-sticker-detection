# api_service/ai4thai_ocr_LP_api.py - OCR License Plate Recognition API service from ai for thai
import requests
import logging
import json
import os
from typing import Optional, Dict, Any
from dotenv import load_dotenv

logger = logging.getLogger(__name__)
load_dotenv()
API_KEY_MAIN = os.getenv("API_KEY_MAIN")
URL = "https://api.aiforthai.in.th/lpr-iapp"

FILTER_KEYS = [
    "conf", # เปอร์เซ็นต์ความเชื่อมั่น
    "status", # Response code
    "is_missing_plate", # ป้ายทะเบียนอ่านไม่ได้ (yes/no)
    "is_vehicle", # ใช่รถยนต์หรือไม่ (yes/no)
    "country", # ประเทศ
    "lp_number", # หมายเลขป้ายทะเบียน
    "province", # จังหวัด
    "vehicle_brand", # ยี่ห้อรถยนต์
    "vehicle_body_type", # ประเภทรถยนต์
    "vehicle_color" # สีรถยนต์
]

def recognize_license_plate(image_url: str) -> Optional[Dict[str, Any]]:
    if not API_KEY_MAIN or not URL:
        logger.error("API_KEY_MAIN or URL is missing in .env.")
        return None

    headers = {'apikey': API_KEY_MAIN}

    try:
        response_img = requests.get(image_url)
        response_img.raise_for_status() 
        image_bytes = response_img.content 

        files = [('file', ('image.jpg', image_bytes, 'image/jpeg'))]
        response = requests.post(URL, headers=headers, files=files)

        if response.status_code != 200:
            logger.error(f"HTTP {response.status_code}: {response.text}")
            return None

        json_response = response.json()
        response_filtered = {key: json_response[key] for key in FILTER_KEYS if key in json_response}
        return response_filtered

    except requests.RequestException as e:
        logger.error(f"Request failed: {e}")
    except json.JSONDecodeError:
        logger.error("Failed to decode JSON response.")
    return None

def recognize_license_plate_from_bytes(image_bytes: bytes) -> Optional[Dict[str, Any]]:
    if not API_KEY_MAIN or not URL:
        logger.error("API_KEY_MAIN or URL is missing in .env.")
        return None
    headers = {'apikey': API_KEY_MAIN}
    try:
        files = [('file', ('image.jpg', image_bytes, 'image/jpeg'))]
        response = requests.post(URL, headers=headers, files=files)
        if response.status_code != 200:
            logger.error(f"HTTP {response.status_code}: {response.text}")
            return None
        json_response = response.json()
        return {k: json_response[k] for k in FILTER_KEYS if k in json_response}
    except requests.RequestException as e:
        logger.error(f"Request failed: {e}")
    except json.JSONDecodeError:
        logger.error("Failed to decode JSON response.")
    return None


# ตัวอย่างผลลัพธ์
# {
#     "conf": 93.73386383,
#     "status": 200,
#     "is_missing_plate": "no",
#     "is_vehicle": "yes",
#     "country": "th",
#     "lp_number": "2ฒช6726",
#     "province": "th-10:Bangkok (กรุงเทพมหานคร)",
#     "vehicle_brand": "toyota",
#     "vehicle_body_type": "truck-standard",
#     "vehicle_color": "white"
# }