from __future__ import annotations

from dataclasses import dataclass, field
from math import sin

from vision.protocol import InputSnapshot


def _inside(elapsed: float, start: float, end: float) -> bool:
    return start <= elapsed < end


@dataclass(slots=True)
class ScriptedPlayer:
    session_id: str = "simulated-player"
    sequence: int = 0
    _left_active: bool = field(default=False, init=False)
    _right_active: bool = field(default=False, init=False)

    def sample(self, elapsed: float) -> InputSnapshot:
        self.sequence += 1
        chase_web = (
            _inside(elapsed, 13.0, 15.2)
            or _inside(elapsed, 20.0, 22.5)
            or _inside(elapsed, 28.0, 30.8)
            or _inside(elapsed, 33.0, 36.0)
            or _inside(elapsed, 48.0, 51.2)
        )
        boss_web = _inside(elapsed, 68.8, 71.6) or _inside(elapsed, 72.2, 75.4)
        finisher = elapsed >= 78.0
        left_active = chase_web or boss_web or finisher
        right_active = _inside(elapsed, 48.0, 51.2) or finisher
        left_trigger = left_active and not self._left_active
        right_trigger = right_active and not self._right_active
        self._left_active = left_active
        self._right_active = right_active
        return InputSnapshot(
            sequence=self.sequence,
            session_id=self.session_id,
            tracked=True,
            pose_confidence=0.94,
            hand_confidence=0.91,
            hand_count=2,
            move=sin(elapsed * 0.72) * 0.45 if _inside(elapsed, 9.5, 55.0) else 0.0,
            aim_x=0.5 + sin(elapsed * 0.7) * 0.26,
            aim_y=0.44 + sin(elapsed * 0.43) * 0.12,
            aim_left_x=0.46 + sin(elapsed * 0.7) * 0.26,
            aim_left_y=0.44 + sin(elapsed * 0.43) * 0.12,
            aim_right_x=0.54 + sin(elapsed * 0.7) * 0.26,
            aim_right_y=0.44 + sin(elapsed * 0.43) * 0.12,
            jump=_inside(elapsed, 16.0, 18.2) or _inside(elapsed, 76.0, 77.8),
            crouch=_inside(elapsed, 24.0, 26.4) or _inside(elapsed, 62.0, 64.3),
            dodge_left=_inside(elapsed, 10.5, 12.5) or _inside(elapsed, 58.8, 61.0),
            dodge_right=_inside(elapsed, 38.5, 40.9),
            shield=_inside(elapsed, 43.0, 45.8) or _inside(elapsed, 65.2, 67.7),
            web_left=left_active,
            web_right=right_active,
            web_left_trigger=left_trigger,
            web_right_trigger=right_trigger,
            fist_left=_inside(elapsed, 20.6, 22.5) or _inside(elapsed, 72.8, 75.4),
            fist_right=finisher and elapsed >= 78.7,
            palm_open_left=not left_active,
            palm_open_right=not right_active,
            gesture_left=(
                "PULL"
                if _inside(elapsed, 20.6, 22.5) or _inside(elapsed, 72.8, 75.4)
                else ("SPIDER_POSE" if left_active else "OPEN")
            ),
            gesture_right=(
                "PULL"
                if finisher and elapsed >= 78.7
                else ("SPIDER_POSE" if right_active else "OPEN")
            ),
            pull=0.9
            if _inside(elapsed, 20.0, 22.5) or _inside(elapsed, 72.2, 75.4)
            else 0.0,
            two_hand_pull=min(1.0, max(0.0, (elapsed - 78.7) / 1.6)) if finisher else 0.0,
        )
