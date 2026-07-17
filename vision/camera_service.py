from __future__ import annotations

import logging
import os
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
    selected_camera: int = -1
    backend: str = ""
    worker_error: str = ""


class CameraService:
    def __init__(
        self,
        camera_id: int,
        width: int,
        height: int,
        mirror: bool,
        logger: logging.Logger,
        target_fps: int = 30,
    ) -> None:
        self.camera_id = camera_id
        self.width = width
        self.height = height
        self.mirror = mirror
        self.target_fps = target_fps
        self.logger = logger
        self.frames: LatestFrameBuffer[np.ndarray] = LatestFrameBuffer()
        self.metrics = CameraMetrics()
        self._stop = threading.Event()
        self._restart = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, name="camera-capture", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2.0)
            if self._thread.is_alive():
                self.logger.error("camera worker did not stop within two seconds")
        self.frames.close()

    def request_restart(self, camera_id: int | None = None, mirror: bool | None = None) -> None:
        if camera_id is not None:
            self.camera_id = max(0, camera_id)
        if mirror is not None:
            self.mirror = mirror
        self._restart.set()

    def _camera_candidates(self) -> list[int]:
        candidates = [self.camera_id]
        for camera_id in range(3):
            if camera_id not in candidates:
                candidates.append(camera_id)
        return candidates

    def _backend_candidates(self) -> list[tuple[int, str]]:
        if os.name == "nt":
            return [
                (cv2.CAP_MSMF, "Media Foundation"),
                (cv2.CAP_DSHOW, "DirectShow"),
                (cv2.CAP_ANY, "Auto"),
            ]
        return [(cv2.CAP_ANY, "Auto")]

    def _configure(self, capture: cv2.VideoCapture) -> None:
        capture.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
        capture.set(cv2.CAP_PROP_FPS, self.target_fps)
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    def _open(self) -> cv2.VideoCapture:
        last_capture: cv2.VideoCapture | None = None
        for camera_id in self._camera_candidates():
            for backend, backend_name in self._backend_candidates():
                capture = cv2.VideoCapture(camera_id, backend)
                self._configure(capture)
                if capture.isOpened():
                    self.metrics.selected_camera = camera_id
                    self.metrics.backend = backend_name
                    self.metrics.last_error = ""
                    return capture
                capture.release()
                last_capture = capture
        self.metrics.selected_camera = -1
        self.metrics.backend = ""
        return last_capture if last_capture is not None else cv2.VideoCapture()

    def _run(self) -> None:
        capture: cv2.VideoCapture | None = None
        window_started = monotonic()
        window_frames = 0
        try:
            while not self._stop.is_set():
                if self._restart.is_set():
                    if capture is not None:
                        capture.release()
                    capture = None
                    self.metrics.connected = False
                    self._restart.clear()
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
                        "camera %s connected via %s at %sx%s",
                        self.camera_id,
                        self.metrics.backend,
                        self.width,
                        self.height,
                    )
                ok, frame = capture.read()
                if not ok or frame is None:
                    self.metrics.connected = False
                    self.metrics.last_error = "camera read failed"
                    capture.release()
                    capture = None
                    sleep(0.2)
                    continue
                if self._stop.is_set():
                    break
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
        except Exception as error:
            self.metrics.connected = False
            self.metrics.worker_error = f"{type(error).__name__}: {error}"
            self.metrics.last_error = self.metrics.worker_error
            self.logger.exception("camera worker failed")
        finally:
            if capture is not None:
                capture.release()
            self.metrics.connected = False
