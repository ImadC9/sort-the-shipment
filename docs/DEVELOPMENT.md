# Sort the Shipment: developer guide

A 3D harbour puzzle game for Web and Android, built in Godot 4.5.2 (Compatibility renderer).
Tap a container stack to lift the top box with the crane. It goes straight onto a docked
ship of the same colour, or into the buffer if no ship wants it yet. Fill a ship and it
sails; buffered boxes jump aboard the next matching ship automatically. Run out of buffer
space and the yard jams.

## What's in the box

- 100 levels in 10 chapters: 20 authored opening layouts in
  `levels/opening_design.json`, followed by generated chapter puzzles.
  `tools/build_levels.gd` builds the base campaign and applies the opening via
  `tools/opening_levels.gd`. Stored solutions can be replayed through the game
  model with `--verify` to check that they earn three stars.
- One star rule everywhere: park fewer containers at once, get more stars. The
  parking gauge shows it directly (green spots keep 3 stars, orange 2, red 1).
- Lesson levels show a short coach tip; nothing blocks play before a level
- Dispatch chains are the signature reward: one tap that sends off several
  ships ("DOUBLE/TRIPLE DISPATCH!") or empties the pads ("QUAY CLEARED!")
- Covered cargo has a manifest listing the hidden colours. The opening verifier
  replays eight stored variants across four levels. Later generated covered
  levels use sampled shuffles, not exhaustive checks of every hidden arrangement.
- Harbour Projects: 17 cosmetic upgrades in two phases (about 16,800 coins in
  all) that visibly change the port: lighthouse, bunting, quay café,
  flower promenade, fireworks, fountain, clock tower, golden cranes, then
  solar roofs, quay lamps, flag masts, rooftop pool, rooftop gardens, ice
  cream stand, fairy lights, anchor monument and ship liveries. The camera
  glides to each new build. Replays of a level already at that star rating
  pay a small reward; new stars pay in full
- Chapter atmosphere: day, storm, golden hour, fog, night (yard lamps on),
  sunset and dusk, tuned so cargo colours stay readable
- Many stored three-star solutions include a double dispatch. Levels 4, 6 and 7
  are not marked as chain-capable; the opening alternates lessons and breathers.
- Resume mid-level after closing the app, with the last undo steps kept;
  coins are committed per move from the rules' events, so undo refunds exactly
  what that move earned and bought spots survive undo; every attempt has an ID
  so late callbacks never touch a new attempt; hints say honestly whether a position is a proven dead end
- Campaign-complete screen, reduced-motion setting
- Boosters: Undo (3 per level), Hint (solver-backed, first one free), +1 spot when stuck
- Gold cargo pays +10 whenever it reaches a ship (parking never loses it)
- Parking gauge with "LAST SPOT!" / "FULL!" warnings and glowing pads
- Reward moments: SHIPPED! stamps, coin fly-ups, confetti, star pops, milestone
  crates every 5 levels, 12 port ranks earned with stars
- Level intro banner, camera glide-in, ships turning and steaming out, hull foam
- Coins per ship sailed and per level, 1–3 stars per level, saved progress
- 3D models are built by Python scripts in Blender (`tools/blender/kit.py`,
  `tools/blender/build_all.py`): containers and covers, padlocks, three ships,
  cranes, quay wall, warehouses, lighthouse, palms, trees, tractor, light masts,
  buoys, clouds. Music and ship horns are synthesised in code; other sound
  effects come from SFX Kit (CC0). See `THIRD_PARTY_NOTICES.md`.
- Menus in the current casual-game style: a home screen with the live port,
  a scrolling level map (chapters, stars, milestone crates, a pin on your
  level), a Harbour page of project cards, and a bottom tab bar between them.
  Rank, coins and settings sit in a shared top bar
- In a level: a pause button (resume / restart / home, sound switches), and
  Android back pauses instead of quitting. Popups share one style: ribbon
  title, white card, close button
- Buttons squish when pressed; rewards land over turning light rays
- Fonts: Fredoka (interface), Poppins (default theme font) and DejaVu Sans (symbols), all under open licences

## Project layout

| Path | What it is |
|---|---|
| `scripts/game_model.gd` | Game rules (no visuals) |
| `scripts/solver.gd` | Search-based solver with a node budget, used for level generation and hints |
| `scripts/level_gen.gd` | Random yard generator driven by a difficulty spec |
| `scripts/world.gd` | 3D port, camera, tap picking, event playback, particles |
| `scripts/cargo.gd`, `ship.gd` | Container and ship nodes and their animations |
| `scripts/meshes.gd` | Mesh loading and procedural meshes (backdrop ridges, slot frames) |
| `scripts/hud.gd` | In-level UI, popups (pause, settings, win, lose), effects |
| `scripts/menu.gd` | Menu shell: home, level map, harbour, tab bar |
| `scripts/ui_kit.gd`, `icons.gd` | Design system (buttons, cards, ribbons, switches) and drawn icons |
| `scripts/harbour.gd` | Harbour Projects: the cosmetic port upgrades |
| `levels/hand.json` | Legacy base-campaign lessons, replaced by the authored opening during generation |
| `levels/opening_design.json` | Current 20 authored opening layouts |
| `tools/opening_levels.gd` | Applies and solves the authored opening |
| `scripts/main.gd` | Game flow, boosters, rewards, resume |
| `scripts/dev_harness.gd` | Command-line tests and screenshot tool (only runs with user arguments) |
| `levels/levels.json` | The verified level pack |
| `tools/make_audio.py` | Synthesises the music loop (and the original effects) |
| `tools/make_sfx.py` | Builds the 1.11 effects: synthesised horns + SFX Kit (CC0) |
| `tools/sign_apk.py` | APK Signature Scheme v2 signer |

## Common tasks

Import `project.godot` in Godot 4.5.2 and press Play. From a terminal:

```bash
# regenerate the 100 levels (about 4 minutes)
godot --headless --path . --script res://tools/build_levels.gd
# check every level clears with the real game rules
godot --headless --path . -- --verify
# menu flow test (tabs, level popup, back button, pause)
godot --path . -- --uitest
# reproductions of the review's defects (attempts, undo coins, bought spots, resume, hints)
godot --path . -- --bugtest
# ad placements and pacing, with simulated ads (no SDK on desktop)
godot --path . -- --adtest
# play levels back to back through win -> CONTINUE, logging memory and tweens
godot --path . -- --chaintest --level=1 --count=30 --after=0.05 --dump
# regenerate sounds
python3 tools/make_audio.py   # music (also rewrites the old effects: run make_sfx.py after it)
# sound effects from a checkout of https://github.com/wyzowl/sfx-kit
python3 tools/make_sfx.py /path/to/sfx-kit
# V3 checks: opening fairness and ship dispatch
godot --headless --path . --script res://tools/verify_opening.gd
godot --path . res://tools/verify_dispatch.tscn
```

To tune difficulty, edit the specs in `tools/build_levels.gd` (colours, stacks,
buffer size, covered/locked containers, random-play win-rate band) and rebuild.

## Rebuilding the 3D models

```bash
pip install bpy                              # Blender as a Python module
python3 tools/blender/build_all.py           # every model, or pass names: build_all.py palm ship_feeder
godot --headless --path . --import
```

Untinted colours are folded into the vertex colours, so a ship is 4 draw calls
(Hull, Deck, Funnel tinted per ship + one fixed surface) and a container is 1.
`scripts/model_mats.gd` swaps in the game materials at load time.

The backdrop (warehouses, trees, palms) uses only the folded
"Fixed" material, so `World._bake_static()` merges all of it into one or two
draw calls. The ground (`shaders/ground.gdshader`: concrete slabs, asphalt
yard) and the sea (`shaders/water.gdshader`) are procedural, with no textures.
Scene budget: about 210–265 draw calls and 185k–205k triangles in a busy level (2.0).

## Building for Android

The public source uses the neutral application ID `com.sorttheshipment.game`
in all three Android presets. Android treats it as a different application from
builds using another ID, with separate installed-app data. Keep this ID stable
once publishing an Android release; changing it is not an in-place app update.

Four export presets:

- **Android**: a non-Gradle APK without the ad SDK. The preset exports unsigned;
  sign it with `tools/sign_apk.py` before installing on a phone.
- **Android AAB**: the Google Play app bundle. It uses the Gradle build in
  `android/build`, which `python3 tools/android_setup.py` installs from the
  Godot 4.5.2 export templates and patches (target API 36, portrait, Android 16
  back-gesture and large-screen orientation opt-outs). It is not kept in the
  repository because its engine libraries exceed GitHub's 100 MB file limit.
- **Android Test APK**: a Gradle APK with the ad SDK, built alongside the AAB in
  GitHub Actions. It uses the same release-signing credentials.
- **Web Preview**: a browser export using `web_shell.html`.

The AAB needs the Android SDK and Gradle. This repository contains the build
configuration; a successful build requires your signing credentials and a
compatible build environment. The workflow runs manually or on `v*` tags.
Either:

1. **GitHub Actions** (no local setup): push this folder to a GitHub repository, add the secrets listed at the top of
   `.github/workflows/android-aab.yml`, then run the "Android AAB" workflow.
   The signed `.aab` appears under the run's Artifacts.
2. **Your own computer**: install Godot 4.5.2 with export templates, Android
   Studio (SDK platform 35 and build-tools 35) and JDK 17. In Godot set
   Editor Settings > Export > Android SDK and Java paths, enter the release
   keystore in Project > Export > Android AAB, run `tools/android_setup.py`
   once, and export.

Sign the AAB with your upload key and keep that keystore safe: every update
must be signed with the same key (Play App Signing holds the final key).

Store icons are generated by `tools/icon.tscn` and `tools/make_icons.py`.
Screenshots and gameplay media are in `docs/media/`; the privacy policy is
`docs/privacy-policy.html` (publishable with GitHub Pages).

Production ad configuration and consent setup, current physical-device checks
and store submission remain release steps. The included build checks alone do
not establish store approval. The V3 validation record in
`docs/design/Validation.json` explicitly notes no updated APK or physical-phone
performance measurement for that revision.

## Ads (Google AdMob)

The game uses the Poing Studios AdMob plugin v5.1.0 (`addons/admob`, MIT) and
Google's consent SDK (UMP). Code: `scripts/ads.gd` (autoload `Ads`) and
`scripts/ad_config.gd` (IDs and pacing).

| Placement | Type | Where |
|---|---|---|
| `rescue` | rewarded | Lose screen "FREE SPOT", once per attempt |
| `hint` | rewarded | Hint button when no free hint and not enough coins |
| `bonus` | rewarded | Win screen "+N COINS" (doubles the level reward) |
| `interstitial` | interstitial | Between levels: not before 5 wins, then at most every 3 levels and 2 minutes |

Rewards are granted only from the SDK's "user earned reward" callback. If an ad
cannot load (offline, no fill) its button simply does not appear.

The checked-in configuration uses test ads (`USE_TEST_ADS := true`) and leaves
`LIVE_UNITS` blank. Before a production release:
1. `project.godot`, section `[admob]`: add `general/android/app_id="ca-app-pub-XXXX~YYYY"`
   (or Project Settings > General > Admob > Android > App Id). Without it Google's test App ID is used.
2. `scripts/ad_config.gd`: paste the four ad unit IDs into `LIVE_UNITS` and set `USE_TEST_ADS := false`.
3. Build with the GitHub workflow (Gradle). The quick local APK preset "Android" is
   non-Gradle and contains no ad SDK, so it never shows ads.

Never tap your own live ads. To test on your phone, keep `USE_TEST_ADS` true, or
add your device as a test device in AdMob.
