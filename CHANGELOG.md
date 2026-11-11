# Changelog

Versions of Sort the Shipment, newest first. Dates are 2026.

## 2.0.0 (11 Nov 2026): Toy Harbour, full visual overhaul

Same rules, levels and saves as 1.12; everything you look at is new.

- Art direction: a sunny toy harbour. Chunky rounded models, a strong warm sun with
  soft cool shadows, saturated cargo on a calm slate yard, cream "paper" interface
  with navy ink. Font: Fredoka.
- Every model rebuilt with one kit (`tools/blender/kit.py`, `tools/blender/build_all.py`):
  containers, strapped canvas covers, padlocks, three ships, both cranes, the quay
  wall, painted harbour-front warehouses with arched doors and lanterns, lighthouse
  (ruin and restored), palms, trees, tractor, light masts, buoys, clouds.
  Run `python3 tools/blender/build_all.py [name...]` (needs `pip install bpy`).
- Colour pipeline fixed: model vertex colours are now read as sRGB, so paints show
  at the values written in the kit instead of washed out. All seven chapter moods
  were relit to match (`World.ATMOS`).
- Ground and water shaders repainted: sand quay slabs, slate yard and parking apron
  with white markings, turquoise water with a soft light net and foam.
- Home screen: three-quarter hero view of the live port that glides into the play
  camera when a level starts (`World.set_menu_view`).
- Level map: the sea changes colour chapter by chapter, with islands, sailing
  boats, rocks and buoys along the route.
- Interface kit (`tools/make_ui.py`, `scripts/ui_kit.gd`): textured cards, pills,
  glossy buttons, icon set and cargo symbols drawn as sprites.
- New app icon, adaptive icon layers, splash and store feature graphic
  (`tools/icon.gd`, `tools/make_icons.py`, `tools/make_splash.py`).

## 1.12.0 (9 Nov 2026): art pass

- Containers: a ~60-triangle chamfered box with a baked texture atlas
  (`tools/make_container_tex.py`); symbols painted in the shader from
  `tools/make_symbol_atlas.py` instead of Label3D. Covered cargo is a strapped canvas.
- Ships: `tools/blender/ships_v2.py` (lofted hull, raked bow, forecastle, new bridges).
- Scenery: `tools/blender/scenery_v2.py` (palms, trees, warehouses with flat roof
  terraces for the harbour projects). The town is gone: three hazed ridges
  (`Meshes.ridge_mesh`, `shaders/backdrop.gdshader`) make a clean backdrop.
- Lighting: stronger key light, real shadows, cooler ambient.
- Cost: about 330 draw calls and 166k triangles per frame (was 414 and 289k).

## 1.11.0 (8 Nov 2026): new opening, ship dispatch, sounds

- New 20-level opening (`tools/opening_levels.gd`): one idea at a time, covered
  cargo at 13, padlocks at 16. Design notes and checks are in `docs/design/`.
- Levels 21-23 bridge the opening and chapter 2: 21 stays at 24 boxes and four
  colours, 22 brings the fifth colour as a breather, 23 is a medium step.
- Ship dispatch: ships seal, sound their horn and pull away; the next ship starts
  its approach as soon as the previous one starts leaving (it uses the outer lane).
- Sounds: new ship horns and a full set of effects from SFX Kit (CC0); see
  `assets/audio/CREDITS.md`.
- Still Godot 4.5.2: keep the project on 4.5.x so the GitHub build stays the same.

## 1.11.x (8 Nov 2026)

- Branded loading screen: the splash continues into a progress bar while the
  harbour is built and shaders compile, then fades to the title; music starts after it.
- Original coin sound restored after player feedback.

## 1.10.0 (6 Nov 2026): ads

- Google AdMob with Google's consent form (UMP): rewarded "free spot", hint and
  bonus coins; paced interstitials (none in the first 5 wins, then at most every
  3 levels and 2 minutes). Rewards only from the SDK's "earned" callback.
- CI also builds an installable APK with ads for device testing; privacy policy
  and store data-safety answers updated.

## 1.9.3: bug hunt and code clean-up

## 1.9.2: settings switches fixed on Android
- Android sends each tap as a touch and an emulated mouse event, flipping
  switches twice. One event type is handled, with a debounce.

## 1.9.1: BUILD button on the win screen
- The harbour project shown after a level can be built right there.

## 1.9.0: review fixes and Google Play requirements
- Godot 4.5.2 for 16 KB memory-page support; target API 36.
- Four bugs from an external review fixed, plus agreed design changes.

## 1.8.1: crash between levels fixed
- Win-screen animation owned by its card, freed-node checks, attempt IDs.

## 1.8.0: upload-ready version
- 100 levels in 10 chapters, store graphics, privacy policy, signed builds.
