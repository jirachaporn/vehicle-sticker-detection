# router_camera.py
import threading
from fastapi import APIRouter, Query, Body
from fastapi.responses import StreamingResponse, JSONResponse
from typing import List
import time
import cv2
import numpy as np
from ..api_service.camera import (
    _try_open_camera_on_index,
    _probe_cameras,
    cameras,
    display_threads,
    display_stops,
    latest_frame_map,
    latest_jpeg_map,
    latest_ts_map,
    latest_lock,
    release_all_cameras,
    primary_cam_id,
    latest_gen
)

router = APIRouter()

@router.get("/list")
def list_cameras(usb_only: int = Query(1)):
    found = _probe_cameras(8)
    cams = [i for i in found if (not usb_only or i != 0)] or found
    return {"available": cams}

@router.post("/start")
def start_camera(location_id: str = Body(...), camera_indices: List[int] = Body(default=None), usb_only: bool = Body(default=True)):
    global primary_cam_id
    release_all_cameras()

    if not camera_indices:
        probed = _probe_cameras(8)
        camera_indices = [i for i in probed if (not usb_only or i != 0)] or probed
    if not camera_indices:
        return JSONResponse({"error": "No webcam found"}, status_code=404)

    opened = []
    for idx in camera_indices:
        cap, be = _try_open_camera_on_index(idx)
        if cap is None:
            continue
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cameras[idx] = cap
        display_stops[idx] = threading.Event()
        th = threading.Thread(target=lambda cid=idx: None, daemon=True)  # placeholder display_worker
        th.start()
        display_threads[idx] = th
        opened.append(idx)

    if not opened:
        return JSONResponse({"error": "Unable to open any webcam"}, status_code=500)

    primary_cam_id = opened[0]

    return {"message": "Cameras started", "opened": opened}

@router.post("/stop")
def stop_camera():
    release_all_cameras()
    return {"message": "Cameras stopped"}

@router.get("/frame_raw")
def frame_raw(cam: int = Query(None), min_ts: float = Query(0.0), min_gen: int = Query(0)):
    global primary_cam_id, latest_gen
    if cam is None:
        cam = primary_cam_id or 0

    deadline = time.time() + 0.3
    while time.time() < deadline:
        with latest_lock:
            data = latest_jpeg_map.get(cam)
            ts = latest_ts_map.get(cam, 0.0)
            gen = latest_gen
        if data and ts > min_ts and gen >= min_gen:
            return StreamingResponse(iter([data]), media_type="image/jpeg")
        time.sleep(0.01)

    # fallback black image
    black = np.zeros((480, 640, 3), dtype=np.uint8)
    ok, jpg = cv2.imencode(".jpg", black, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
    return StreamingResponse(iter([jpg.tobytes() if ok else black.tobytes()]), media_type="image/jpeg")
