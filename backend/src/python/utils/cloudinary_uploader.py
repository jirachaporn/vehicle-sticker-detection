# utils/cloudinary_uploader.py - Upload the image to cloudinary
import os
import logging
import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

class CloudinaryUploader:
    def __init__(self) -> None:
        load_dotenv()
        url = os.getenv("CLOUDINARY_URL")
        name = os.getenv("CLOUDINARY_NAME")
        key = os.getenv("CLOUDINARY_API_KEY")
        secret = os.getenv("CLOUDINARY_API_SECRET")

        if url:
            cloudinary.config(cloudinary_url=url, secure=True)

        cfg = cloudinary.config()
        if not cfg.api_key:
            if name and key and secret:
                cloudinary.config(cloud_name=name, api_key=key, api_secret=secret, secure=True)
                cfg = cloudinary.config()

        # หากไม่มี api_key/cloud_name จะแจ้ง error 
        if not cfg.api_key or not cfg.cloud_name:
            raise RuntimeError(
                "Cloudinary config invalid. "
                "Either set a valid CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name> "
                "or set CLOUDINARY_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET.")
        
    def upload_bytes(self, image_bytes: bytes, folder: str = "detection") -> str:
        try:
            result = cloudinary.uploader.upload(
                image_bytes,
                resource_type="image",
                folder=folder,
                unique_filename=True,
                overwrite=False)
            
            secure_url = result.get("secure_url") or ""
            if not secure_url:
                logging.error(f"❌ Upload OK but missing secure_url. Response: {result}")
                return ""
            logging.info("✅ Image uploaded to Cloudinary")
            return secure_url
        except Exception as e:
            logging.error(f"❌ Error uploading to Cloudinary: {e}")
            return ""