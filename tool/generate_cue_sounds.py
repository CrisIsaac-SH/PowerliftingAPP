import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def tone(freq: float, ms: int, volume: float = 0.7, release: float = 0.04) -> list[float]:
    count = int(RATE * ms / 1000)
    attack = 0.008
    duration = count / RATE
    samples: list[float] = []
    for i in range(count):
        t = i / RATE
        fade_in = min(1.0, t / attack)
        fade_out = min(1.0, max(0.0, (duration - t) / release))
        envelope = min(fade_in, fade_out)
        sample = math.sin(2 * math.pi * freq * t)
        sample += 0.16 * math.sin(4 * math.pi * freq * t)
        samples.append(sample * envelope * volume)
    return samples


def silence(ms: int) -> list[float]:
    return [0.0] * int(RATE * ms / 1000)


def write_wav(name: str, samples: list[float]) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = bytearray()
        for sample in samples:
            clipped = max(-1.0, min(1.0, sample))
            frames += struct.pack("<h", int(clipped * 32767))
        handle.writeframes(frames)
    print(path, len(samples))


def main() -> None:
    success: list[float] = []
    success += tone(880.0, 90, volume=0.62, release=0.03)
    success += silence(18)
    success += tone(1174.66, 190, volume=0.72, release=0.09)
    write_wav("success.wav", success)

    alert: list[float] = []
    alert += tone(932.33, 75, volume=0.76, release=0.02)
    alert += silence(48)
    alert += tone(932.33, 75, volume=0.76, release=0.02)
    alert += silence(48)
    alert += tone(698.46, 160, volume=0.8, release=0.07)
    write_wav("alert.wav", alert)


if __name__ == "__main__":
    main()
