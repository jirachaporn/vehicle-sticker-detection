# camera.py
import cv2
import threading
import time
import numpy as np

# Maps / globals
cameras = {}
display_threads = {}
display_stops = {}
latest_frame_map = {}
latest_jpeg_map = {}
latest_ts_map = {}
latest_lock = threading.Lock()
primary_cam_id = None
latest_gen = 0
detector_thread = None
detector_stop = threading.Event()

DISPLAY_FPS = 15
TARGET_DISPLAY_WIDTH = 640
JPEG_QUALITY_DISPLAY = 80

def _try_open_camera_on_index(index: int):
    backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, None]
    for be in backends:
        try:
            cap = cv2.VideoCapture(index, be) if be else cv2.VideoCapture(index)
            if not cap.isOpened():
                cap.release()
                continue
            # flush buffer
            for _ in range(10):
                cap.read()
            ok, img = cap.read()
            if ok and img is not None and img.size > 0:
                return cap, be
            cap.release()
        except Exception:
            continue
    return None, None

def _probe_cameras(max_index: int = 8):
    found = []
    for i in range(max_index + 1):
        cap, _ = _try_open_camera_on_index(i)
        if cap:
            found.append(i)
            cap.release()
    return found

def release_all_cameras():
    global cameras, display_threads, display_stops
    for ev in list(display_stops.values()):
        ev.set()
    for th in list(display_threads.values()):
        if th and th.is_alive():
            th.join(timeout=1)
    display_threads.clear()
    display_stops.clear()
    for cid, cap in list(cameras.items()):
        if cap and cap.isOpened():
            cap.release()
        cameras.pop(cid, None)
