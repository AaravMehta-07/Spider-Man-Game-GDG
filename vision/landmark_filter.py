from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class OneEuroLite:
    """Confidence-aware exponential filter suitable for normalized landmarks."""

    alpha: float = 0.35
    value: float | None = None

    def update(self, sample: float, confidence: float = 1.0) -> float:
        confidence = max(0.0, min(1.0, confidence))
        effective_alpha = max(0.04, min(0.92, self.alpha * (0.35 + confidence * 0.65)))
        if self.value is None:
            self.value = sample
        else:
            self.value += (sample - self.value) * effective_alpha
        return self.value

    def reset(self) -> None:
        self.value = None


class HysteresisGate:
    def __init__(self, enter: float, exit: float) -> None:
        if enter <= exit:
            raise ValueError("enter threshold must exceed exit threshold")
        self.enter = enter
        self.exit = exit
        self.active = False

    def update(self, value: float) -> bool:
        if self.active:
            self.active = value > self.exit
        else:
            self.active = value >= self.enter
        return self.active

    def reset(self) -> None:
        self.active = False
