from __future__ import annotations

import logging
import threading
from dataclasses import dataclass
from time import monotonic, sleep

import cv2
import numpy as np

from vision.frame_buffer import LatestFrameBuffer


@dataclass(slots=True)
class CameraMetrics:
    connected: bool = False
    fps: float = 0.0
    frames: int = 0
    reconnects: int = 0
    last_error: str = ""


class CameraService:
    def __init__(
        self, camera_id: int, width: int, height: int, mirror: bool, logger: logging.Logger
    ) -> None:
        self.camera_id = camera_id
        self.width = width
        self.height = height
        self.mirror = mirror
        self.logger = logger
        self.frames: LatestFrameBuffer[np.ndarray] = LatestFrameBuffer()
        self.metrics = CameraMetrics()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, name="camera-capture", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self.frames.close()
        if self._thread:
            self._thread.join(timeout=2.0)

    def _open(self) -> cv2.VideoCapture:
        capture = cv2.VideoCapture(self.camera_id, cv2.CAP_DSHOW)
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return capture

    def _run(self) -> None:
        capture: cv2.VideoCapture | None = None
        window_started = monotonic()
        window_frames = 0
        try:
            while not self._stop.is_set():
                if capture is None or not capture.isOpened():
                    capture = self._open()
                    if not capture.isOpened():
                        self.metrics.connected = False
                        self.metrics.last_error = f"camera {self.camera_id} unavailable"
                        self.metrics.reconnects += 1
                        capture.release()
                        capture = None
                        sleep(1.0)
                        continue
                    self.metrics.connected = True
                    self.logger.info(
                        "camera %s connected at %sx%s", self.camera_id, self.width, self.height
                    )
                ok, frame = capture.read()
                if not ok or frame is None:
                    self.metrics.connected = False
                    self.metrics.last_error = "camera read failed"
                    capture.release()
                    capture = None
                    sleep(0.2)
                    continue
                if self.mirror:
                    frame = cv2.flip(frame, 1)
                self.frames.publish(frame)
                self.metrics.frames += 1
                window_frames += 1
                now = monotonic()
                if now - window_started >= 1.0:
                    self.metrics.fps = window_frames / (now - window_started)
                    window_frames = 0
                    window_started = now
        finally:
            if capture is not None:
                capture.release()
            self.metrics.connected = False
