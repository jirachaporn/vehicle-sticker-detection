# api_endpoint/router_camera.py
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from ..api_service.camera import stream_camera, check_available_cameras, detect_vehicle

router = APIRouter(prefix="/camera", tags=["Camera"])

@router.get("/stream/{camera_id}")
def stream_camera_route(camera_id: int):
    frames = stream_camera(camera_id)
    if frames is None:
        raise HTTPException(status_code=404, detail="กล้องไม่พบ หรือ ไม่ใช่กล้องแวมแคม")
    return StreamingResponse(
        frames,
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@router.get("/available")
def check_available_cameras_route():
    available = check_available_cameras()
    if available is None:
        raise HTTPException(status_code=404, detail="ไม่พบการเชื่อมต่อกับกล้องแวมแคม")
    return available

@router.post("/car-detect")
async def detect_vehicle_route(request: Request):
    data = await request.json()
    image_base64 = data.get("image")
    if not image_base64:
        raise HTTPException(status_code=400, detail="Missing image data")
    result = detect_vehicle(image_base64)
    return result
