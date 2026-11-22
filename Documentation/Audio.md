# Arcade audio

All six WAV files in Real Pacman/Audio are original synthesized assets. No Pac-Man recording or melody is sampled. Scripts/generate_arcade_audio.py regenerates them deterministically using Python's standard library.

- menu_loop: eight bars at 128 BPM, A-minor pulse lead, arpeggios, bass and drums; 15 seconds, no vocals.
- ui_press: short rising confirmation chirp, played on activation before the navigation delay.
- ui_level: ascending three-note sound for carousel selection changes, including swipes.
- ui_toggle: bright two-note toggle feedback.
- ui_adjust: short slider-release preview.
- life_lost: 450 ms descending hit cue with a soft bass impact, played once when lives decrease in real or demo gameplay, including the final hit. Uses the Sound volume and existing Silent Mode/interruption behavior.

ArcadeAudio preloads one looping music player and three voices per effect. Music and Sound settings independently adjust playback immediately; zero mutes that channel. Effects remain available during gameplay, but menu music pauses. Music resumes at its paused position on return.

The ambient audio session respects iOS Silent Mode and mixes with other audio. Audio pauses outside the active scene and handles system interruptions; automatic resumption depends on the system's shouldResume indication. No background audio entitlement is added.

Verification: simulator SDK build, bundled resource checks, PCM duration/peak/loop-seam checks. Listening and phone-call/Silent Mode behavior should also be checked on an iPhone.
