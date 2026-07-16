# Visual Style

## Direction

The game uses an original near-future comic-thriller language: charcoal city mass,
neutral rain, cyan technology, crimson threat, white web energy and small amber
rescue accents. It avoids copying a licensed suit, emblem, villain or skyline.

## Composition

The first-person camera maintains a central route and readable horizon. Buildings
frame rather than occupy the play lane. Set pieces use silhouette, colour and
Spider-Sense direction before they reach the player. Boss presentation keeps the
city visible so the transition feels continuous.

## Materials and shaders

- comic_surface: stepped light and restrained ink edges
- boss_distortion: animated silhouette, Fresnel reveal and damage bands
- web_line: white-blue additive core with tension brightness
- rain and overlays: capped, reusable low-cost effects
- danger and impact: high-contrast full-screen cues behind readable text

## UI hierarchy

Title and immediate action are the largest text. Energy, pressure, score and clock
occupy stable corners. Context prompts sit in one consistent lower band. Boss and
finisher meters appear only when relevant. Diagnostics and operator controls are
not visible during public play.

## Screenshot review

Every required capture must show a nonblank world, readable 1080p text, intentional
framing, no debug overlay, no overlap, and the correct mission state. Attract must
show the original city plate. Chase frames must differ by set piece. Boss frames
must show readable distortion and cracks. Results must fit without clipping.