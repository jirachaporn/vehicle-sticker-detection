# cloudinary_uploader.py - Upload the image to cloundinary
import os
import uuid
import cloudinary
import cloudinary.uploader
import logging
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class CloudinaryUploader:
    def __init__(self):

        load_dotenv()
        try:
            cloudinary.config(secure=True)
            logging.info("✅ Cloudinary configured successfully!")
        except Exception as e:
            logging.error(f"❌ Failed to configure Cloudinary: {e}")
            raise

    def upload_image(self, file_bytes: bytes, original_filename: str) -> str:
        try:
            filename_without_ext = os.path.splitext(original_filename)[0]
            result = cloudinary.uploader.upload(
                file_bytes,
                folder="detection",             
                public_id=filename_without_ext, 
                overwrite=True,                 
                resource_type="image"
            )
            
            secure_url = result.get("secure_url", "")
            logging.info(f"✅ Image uploaded successfully! to Cloudinary")
            return secure_url

        except Exception as e:
            logging.error(f"❌ Error uploading to Cloudinary: {e}")
            return ""