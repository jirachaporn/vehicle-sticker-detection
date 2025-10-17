# utils/sticker_model_loader.py
import os, hashlib, threading, requests
from typing import Optional, Dict, Any
from ultralytics import YOLO
from ..db.supabase_client import get_supabase_client

_LOCK = threading.Lock()
_MODEL_CACHE: Dict[str, YOLO] = {}

CACHE_DIR = os.getenv("STICKER_CACHE_DIR", "models_cache")
os.makedirs(CACHE_DIR, exist_ok=True)

def _hash(s: str) -> str:
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]

def _download_if_needed(url: str) -> str:
    local = os.path.join(CACHE_DIR, f"{_hash(url)}.pt")
    if not os.path.exists(local):
        r = requests.get(url, stream=True, timeout=60)
        r.raise_for_status()
        with open(local, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
    return local

def _get_active_sticker_model_record(location_id: str) -> Optional[Dict[str, Any]]:
    sb = get_supabase_client()
    res = sb.table("model").select(
        "model_id, model_name, model_url, location_id, is_active").eq("location_id", location_id)\
    .eq("is_active", True)\
    .limit(1).execute()
    data = getattr(res, "data", None) or []
    return data[0] if data else None

def get_yolo_model_for_location(location_id: str) -> YOLO:
    rec = _get_active_sticker_model_record(location_id)
    if not rec or not rec.get("model_url"):
        model_path = os.getenv("STICKER_MODEL_PATH", "sc9_sticker.pt")
        return YOLO(model_path)

    url = rec["model_url"]
    with _LOCK:
        if url in _MODEL_CACHE:
            return _MODEL_CACHE[url]
        local_path = _download_if_needed(url)
        model = YOLO(local_path)
        _MODEL_CACHE[url] = model
        return model

def detect_sticker_from_bytes(image_bytes: bytes, model: YOLO, conf: float = None, iou: float = None):
    import numpy as np, cv2
    if conf is None:
        conf = float(os.getenv("STICKER_CONF", "0.30"))
    if iou is None:
        iou  = float(os.getenv("STICKER_IOU", "0.50"))

    npbuf = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(npbuf, cv2.IMREAD_COLOR)
    if img is None:
        return {"is_sticker": False, 
                "count": 0, 
                "confident": 0.0}

    results = model.predict(img, verbose=False, conf=conf, iou=iou)
    cnt, confs = 0, []
    if results:
        r = results[0]
        for b in r.boxes:
            c = float(b.conf[0].item())
            if c >= conf:
                cnt += 1
                confs.append(c)
    return {"is_sticker": cnt > 0, 
            "count": cnt, 
            "confident": max(confs) if confs else 0.0}
