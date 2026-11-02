"""Generate original, deterministic chiptune assets using only Python's standard library.
No sampled or copied game music. Re-run from any working directory.
"""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "Real Pacman" / "Audio"
RATE = 44100
BEAT = 60 / 128
random.seed(7)

def hz(note):
    return 440 * 2 ** ((note - 69) / 12)

def tone(buffer, start, duration, note, gain, kind="pulse"):
    first = round(start * RATE)
    count = round(duration * RATE)
    frequency = hz(note)
    for i in range(count):
        t = i / RATE
        # Short ramps prevent clicks, including at the loop seam.
        envelope = min(1, t / .004, (duration - t) / .018) * math.exp(-t * 3)
        phase = 2 * math.pi * frequency * t
        if kind == "bass":
            sample = math.sin(phase) + .2 * math.sin(phase * 2)
        else:
            sample = sum(math.sin(phase * h) / h for h in (1, 3, 5) if frequency * h < RATE / 2) * .7
        if first + i < len(buffer):
            buffer[first + i] += sample * max(0, envelope) * gain

def drum(buffer, start, kind):
    duration = .16 if kind == "kick" else .09
    phase = 0
    for i in range(round(duration * RATE)):
        t = i / RATE
        if kind == "kick":
            phase += 2 * math.pi * (50 + 110 * math.exp(-t * 45)) / RATE
            sample = math.sin(phase) * math.exp(-t * 25) * .24
        else:
            sample = random.uniform(-1, 1) * math.exp(-t * 65) * (.075 if kind == "snare" else .025)
        index = round(start * RATE) + i
        if index < len(buffer):
            buffer[index] += sample

def write(name, samples):
    # A three millisecond boundary ramp removes the drum transient at loop start.
    samples = samples.copy()
    ramp = round(RATE * .003)
    for i in range(ramp):
        samples[i] *= i / ramp
        samples[-1-i] *= i / ramp
    assert max(abs(s) for s in samples) < 1, "Clipping"
    with wave.open(str(OUT / (name + ".wav")), "wb") as file:
        file.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        file.writeframes(b"".join(struct.pack("<h", round(s * 32767)) for s in samples))

def generate():
    OUT.mkdir(parents=True, exist_ok=True)
    music = [0.] * round(32 * BEAT * RATE)
    # Eight-bar A-minor arcade groove: pulse lead, arpeggios, bass and lo-fi drums.
    chords = [(45, 57, 60, 64), (41, 57, 60, 65), (48, 55, 60, 64), (43, 55, 59, 62)] * 2
    melodies = [
        [76, 0, 79, 81, 0, 79, 76, 72], [77, 0, 81, 84, 81, 0, 77, 76],
        [76, 79, 84, 0, 83, 79, 76, 0], [74, 0, 79, 78, 79, 74, 71, 0],
        [81, 0, 84, 88, 0, 84, 81, 79], [81, 84, 89, 0, 88, 84, 81, 0],
        [84, 83, 79, 76, 0, 79, 83, 84], [83, 79, 74, 71, 74, 76, 79, 0]
    ]
    for bar, chord in enumerate(chords):
        start = bar * 4 * BEAT
        for step in range(8):
            when = start + step * BEAT / 2
            tone(music, when, BEAT * .36, chord[0] + (12 if step % 4 == 3 else 0), .15, "bass")
            tone(music, when, BEAT * .22, chord[1 + step % 3] + 12, .045)
            if melodies[bar][step]:
                tone(music, when, BEAT * .38, melodies[bar][step], .105)
            drum(music, when, "hat")
        for beat in range(4):
            drum(music, start + beat * BEAT, "kick" if beat % 2 == 0 else "snare")
    write("menu_loop", music)
    for name, notes in [("ui_press", [76, 83]), ("ui_level", [72, 79, 84]),
                        ("ui_toggle", [79, 88]), ("ui_adjust", [84])]:
        samples = [0.] * round((len(notes) * .045 + .07) * RATE)
        for i, note in enumerate(notes):
            tone(samples, i * .045, .065, note, .22)
        write(name, samples)
    for path in sorted(OUT.glob("*.wav")):
        with wave.open(str(path)) as file:
            print(path.name, round(file.getnframes() / RATE, 3), "seconds")
            
if __name__ == "__main__":
    generate()
