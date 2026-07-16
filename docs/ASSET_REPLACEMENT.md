# Asset Replacement

The default art and audio are original project assets. Keep filenames and dimensions
where possible, then rerun the Godot import and capture review.

## Branding files

Place replacement PNG files at:

- game/assets/branding/game_logo.png
- game/assets/branding/hero_emblem.png
- game/assets/branding/event_logo.png
- game/assets/branding/recruitment_qr.png

Use transparent PNG for logos and emblem. Use a square, high-contrast QR code with
quiet margin. Test QR scanning from the actual display distance. Do not put personal
data in the QR image.

## Attract city

game/assets/generated/attract_city.png is a 16:9 original background plate. A
replacement must retain dark left-centre negative space so title copy stays readable.

## Audio

Generated WAV files are under game/assets/audio/generated. Replace individual files
with PCM WAV using the same names, or update AudioManager paths. Keep music loops
free of copyrighted melodies and verify event playback rights.

## Fonts, textures and models

Store optional replacements in their matching assets subfolder. Prefer WOFF/TTF with
clear event-display licensing. Keep texture memory modest and models low-poly. Do
not introduce runtime downloads.

## Validation after replacement

Run the editor import, GDScript tests, Windows export and deterministic capture.
Inspect all 13 screenshots at 1920x1080 and test audio on event speakers.