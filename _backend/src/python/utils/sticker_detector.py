# utils/sticker_detector.py
import os
import threading
from typing import Dict, Any, List
import numpy as np
import cv2
from ultralytics import YOLO

_LOCK = threading.Lock()
_DETECTOR = None  # singleton  

class StickerDetector:
    def __init__(self, model_path: str, conf: float = 0.30, iou: float = 0.50):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Sticker model not found: {model_path}")
        self.model = YOLO(model_path)
        self.conf = conf
        self.iou = iou

    def detect_from_bytes(self, image_bytes: bytes) -> Dict[str, Any]:
        npbuf = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(npbuf, cv2.IMREAD_COLOR)
        if img is None:
            return {"is_sticker": False, 
                    "count": 0, 
                    "confident": 0.0}

        results = self.model.predict(img, verbose=False, conf=self.conf, iou=self.iou)

        confs: List[float] = []
        cnt = 0
        if results:
            r = results[0]
            for box in r.boxes:
                c = float(box.conf[0].item())
                if c >= self.conf:
                    cnt += 1
                    confs.append(c)

        return {
            "is_sticker": cnt > 0,
            "count": cnt,
            "confident": max(confs) if confs else 0.0
        }

def get_sticker_detector() -> StickerDetector:
    global _DETECTOR
    if _DETECTOR is None:
        with _LOCK:
            if _DETECTOR is None:
                model_path = os.getenv("STICKER_MODEL_PATH", "sc9_sticker.pt")
                conf = float(os.getenv("STICKER_CONF", "0.30"))
                iou = float(os.getenv("STICKER_IOU", "0.50"))
                _DETECTOR = StickerDetector(model_path, conf=conf, iou=iou)
    return _DETECTOR
