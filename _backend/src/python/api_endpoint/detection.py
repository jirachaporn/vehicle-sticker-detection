# detection.py - API endpoint for image upload, OCR processing, and database insertion
from fastapi import APIRouter
from fastapi import FastAPI, File, UploadFile, HTTPException 
from ..utils.processor import run_ocr_and_insert
from ..utils.cloudinary_uploader import CloudinaryUploader 

router = APIRouter()

# สร้าง instance ของ Uploader ไว้ใช้งาน
# การตั้งค่า Cloudinary จะถูกทำแค่ครั้งเดียวตอนเริ่มแอป
cloudinary_uploader = CloudinaryUploader()

@router.post("/detect")
async def detect(file: UploadFile = File(...)):

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="No file uploaded.")
    
    cloudinary_url = cloudinary_uploader.upload_image(file_bytes, file.filename)
    if not cloudinary_url:
        raise HTTPException(status_code=500, detail="Upload to Cloudinary failed.")

    supabase_response, error = run_ocr_and_insert(cloudinary_url)
    if error:
        raise HTTPException(status_code=500, detail=error)

    return {
        "cloudinary_url": cloudinary_url,
        "supabase_response": supabase_response.data
    }











# D:\Work VS Code\Automated DT Sticker\src> uvicorn python.api_endpoint.app:app --reload


