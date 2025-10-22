# router_model.py
from fastapi import APIRouter, UploadFile, Form, File
from typing import List
from pydantic import BaseModel
from ..api_service.model import upload_sticker_model_service

router = APIRouter()

class UploadModelResponse(BaseModel):
    success: bool
    message: str
    data: dict | None = None

@router.post("/upload", response_model=UploadModelResponse)
async def upload_sticker_model(
    model_name: str = Form(...),
    location_id: str = Form(...),
    images: List[UploadFile] = File(...)
):
    success, message, data = await upload_sticker_model_service(model_name, location_id, images)
    return UploadModelResponse(success=success, message=message, data=data)

