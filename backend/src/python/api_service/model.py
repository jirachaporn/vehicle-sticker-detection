# model.py
import os
import time
from datetime import datetime, timezone
import cloudinary.uploader
from supabase import create_client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE = os.getenv("SUPABASE_SERVICE_ROLE")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)

cloudinary.config(
    cloud_name=os.getenv("MY_CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("MY_CLOUDINARY_API_KEY"),
    api_secret=os.getenv("MY_CLOUDINARY_API_SECRET"),
    secure=True
)
CLOUD_FOLDER = os.getenv("MY_CLOUDINARY_FOLDER", "stickers")

async def upload_sticker_model_service(model_name: str, location_id: str, files: list):
    """
    Upload images to Cloudinary and insert new sticker model to Supabase.
    """
    if not model_name or not location_id:
        return False, "Missing model_name or location_id", None

    if len(files) < 5:
        return False, "Upload at least 5 images", None

    image_urls = []
    created_at = datetime.now(timezone.utc)  

    for file in files:
        try:
            content = await file.read()  
            if len(content) > 5 * 1024 * 1024:
                return False, f"{file.filename} exceeds 5MB", None

            result = cloudinary.uploader.upload(
                content,
                folder=CLOUD_FOLDER,
                resource_type="image",
                return_delete_token=True
            )
            image_urls.append(result.get("secure_url", ""))
        except Exception as e:
            return False, f"Cloudinary upload error: {str(e)}", None

    new_sticker = {
        "location_id": location_id,
        "model_name": model_name,
        "is_active": False,
        "created_at": created_at.isoformat(),  
        "sticker_status": "processing",
        "image_urls": image_urls
    }

    try:
        res = supabase.table("model").insert(new_sticker).execute()
        if res.data:
            return True, "Sticker model uploaded successfully", res.data[0]
        else:
            return False, "Failed to insert to Supabase", None
    except Exception as e:
        return False, f"Supabase insert error: {str(e)}", None
