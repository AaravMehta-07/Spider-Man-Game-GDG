from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(value) for value in samples))
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value / peak)) * 32767)) for value in samples)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)


def envelope(time: float, duration: float, attack: float = 0.02, release: float = 0.15) -> float:
    return min(1.0, time / attack, max(0.0, (duration - time) / release))


def tone(duration: float, frequencies: list[float], pulse: float = 0.0) -> list[float]:
    result: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        value = sum(math.sin(math.tau * frequency * time) for frequency in frequencies) / len(frequencies)
        if pulse:
            value *= 0.65 + 0.35 * math.sin(math.tau * pulse * time)
        result.append(value * envelope(time, duration))
    return result


def sweep(duration: float, start: float, end: float, noise: float = 0.0) -> list[float]:
    random.seed(7331)
    phase = 0.0
    result: list[float] = []
    count = int(duration * SAMPLE_RATE)
    for index in range(count):
        progress = index / max(1, count - 1)
        frequency = start + (end - start) * progress
        phase += math.tau * frequency / SAMPLE_RATE
        value = math.sin(phase) * 0.75 + random.uniform(-1.0, 1.0) * noise
        result.append(value * envelope(index / SAMPLE_RATE, duration, 0.005, duration * 0.45))
    return result


def music(duration: float, root: float, urgent: bool = False) -> list[float]:
    notes = [1.0, 1.5, 1.2, 1.8, 1.0, 2.0, 1.5, 1.2]
    beat = 0.25 if urgent else 0.5
    result: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        note = notes[int(time / beat) % len(notes)]
        bass = math.sin(math.tau * root * note * time)
        upper = math.sin(math.tau * root * note * 2.0 * time) * 0.35
        rhythm = 0.45 + 0.55 * math.exp(-((time % beat) / 0.09))
        result.append((bass + upper) * rhythm * 0.55)
    fade = int(SAMPLE_RATE * 0.2)
    for index in range(fade):
        result[index] *= index / fade
        result[-index - 1] *= index / fade
    return result


def generate(root: Path) -> None:
    output = root / "game" / "assets" / "audio" / "generated"
    tracks = {
        "music_attract.wav": music(8.0, 55.0),
        "music_chase.wav": music(8.0, 65.4, True),
        "music_boss.wav": music(8.0, 48.9, True),
        "music_results.wav": music(7.0, 82.4),
        "web_fire.wav": sweep(0.28, 1800.0, 220.0, 0.08),
        "web_attach.wav": tone(0.22, [220.0, 440.0, 880.0]),
        "spider_sense.wav": sweep(0.65, 180.0, 1400.0, 0.03),
        "impact.wav": sweep(0.4, 130.0, 42.0, 0.35),
        "finisher.wav": tone(1.4, [55.0, 110.0, 220.0], 5.0),
        "ui_confirm.wav": tone(0.18, [660.0, 990.0]),
    }
    for name, samples in tracks.items():
        write_wav(output / name, samples)
    print(f"Generated {len(tracks)} original WAV files in {output}")


if __name__ == "__main__":
    generate(Path(__file__).resolve().parents[1])