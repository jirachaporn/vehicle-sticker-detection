# processor.py - Connect supabase client, call OCR service from AI for Thai, insert OCR data into supabase
import logging
from typing import Tuple, Optional, Any
from postgrest import APIResponse
from ..api_service.ai4thai_ocr_LP_api import recognize_license_plate
from ..db.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

def run_ocr_and_insert(image_url: str) -> Tuple[Optional[APIResponse], Optional[str]]:

    if not image_url:
        error_msg = "No image URL provided."
        logger.error(f"❌ {error_msg}")
        return None, error_msg

    try:
        supabase = get_supabase_client()
        logger.info("Attempting to process OCR and insert data...")

        # 1. เรียกใช้ OCR
        ocr_result = recognize_license_plate(image_url)
        if not ocr_result:
            error_msg = "OCR process failed or returned no result from API."
            logger.error(f"❌ {error_msg}")
            return None, error_msg

        # logger.info(f"✅ OCR successful. Result: {ocr_result.get('lp_number')}")

        # 2. เตรียมข้อมูลและบันทึกลง Supabase
        data_to_insert = {
            "detected_plate": ocr_result,
            "path_img": [image_url] 
        }

        response = supabase.table("TEST_detections").insert(data_to_insert).execute()
        
        logger.info("✅ Data has been successfully inserted into Supabase.")
        return response, None

    except Exception as e:
        # ดักจับข้อผิดพลาดที่ไม่คาดคิด เช่น Supabase down หรืออื่นๆ
        error_msg = f"An unexpected error occurred in processor: {e}"
        logger.exception(error_msg)
        return None, error_msg