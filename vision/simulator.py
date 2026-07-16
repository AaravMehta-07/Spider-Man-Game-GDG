from __future__ import annotations

from dataclasses import dataclass
from math import sin

from vision.protocol import InputSnapshot


@dataclass(slots=True)
class ScriptedPlayer:
    session_id: str = "simulated-player"
    sequence: int = 0

    def sample(self, elapsed: float) -> InputSnapshot:
        self.sequence += 1
        move = sin(elapsed * 0.9) * 0.72 if 9.5 <= elapsed < 55.0 else 0.0
        pulse = elapsed % 4.0
        boss_pulse = elapsed % 3.5
        return InputSnapshot(
            sequence=self.sequence,
            session_id=self.session_id,
            tracked=True,
            pose_confidence=0.94,
            hand_confidence=0.91,
            move=move,
            aim_x=0.5 + sin(elapsed * 0.7) * 0.26,
            aim_y=0.44 + sin(elapsed * 0.43) * 0.12,
            jump=9.5 <= elapsed < 55.0 and 0.15 < pulse < 0.45,
            crouch=9.5 <= elapsed < 55.0 and 1.6 < pulse < 2.05,
            dodge_left=58.0 <= elapsed < 78.0 and boss_pulse < 0.22,
            dodge_right=58.0 <= elapsed < 78.0 and 1.7 < boss_pulse < 1.92,
            shield=58.0 <= elapsed < 78.0 and 2.7 < boss_pulse < 3.1,
            web_left=(5.5 <= elapsed < 9.5 and pulse < 0.5)
            or (9.5 <= elapsed < 78.0 and 2.2 < pulse < 2.45)
            or elapsed >= 78.0,
            web_right=(5.5 <= elapsed < 9.5 and 0.8 < pulse < 1.3)
            or (9.5 <= elapsed < 78.0 and 2.2 < pulse < 2.45)
            or elapsed >= 78.0,
            pull=0.82 if 24.0 <= elapsed % 30.0 <= 25.1 else 0.0,
            two_hand_pull=min(1.0, max(0.0, (elapsed - 79.0) / 2.5)) if elapsed >= 78.0 else 0.0,
        )
