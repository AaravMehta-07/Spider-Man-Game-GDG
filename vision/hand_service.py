from __future__ import annotations

from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


class HandService:
    def __init__(self, model_path: Path, confidence: float) -> None:
        if not model_path.is_file():
            raise FileNotFoundError(f"missing hand model: {model_path}")
        options = vision.HandLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=str(model_path)),
            running_mode=vision.RunningMode.VIDEO,
            min_hand_detection_confidence=confidence,
            min_hand_presence_confidence=confidence,
            min_tracking_confidence=max(0.4, confidence - 0.1),
            num_hands=2,
        )
        self._detector = vision.HandLandmarker.create_from_options(options)

    def detect(self, bgr: np.ndarray, timestamp_ms: int):
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        return self._detector.detect_for_video(image, timestamp_ms)

    def close(self) -> None:
        self._detector.close()
