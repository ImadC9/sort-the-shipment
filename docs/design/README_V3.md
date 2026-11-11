# Sort the Shipment — Solstice Harbour V3

> Historical development note. V3 names an opening/dispatch revision, not the
> repository release number. The current package is version 2.0.0 and uses
> Godot 4.5.2. See the [README](../../README.md) and
> [case study](../case-study.md) for current status and validation scope.

This version adds a more deliberate dispatch sequence and a redesigned opening campaign to the polished V2 harbour. The sorting rules and controls stay the same.

## What changed

- Ships finish loading, settle briefly, sound their horn, ease away from the quay, then accelerate into the channel. The next ship waits until its berth is clear.
- Cargo assigned to an incoming ship waits locally before flying aboard. Rapid taps stay responsive.
- Three original horn families, a cargo seal sound and a short chain chime give departures a clearer identity. Sound and reduced-motion settings are respected.
- Dispatch rewards appear at the physical launch, with a small single-line notice. Fewer large flashes, particles and camera movements keep the board readable.
- The first 20 levels now teach matching, parking and chains before asking for more planning. Covered cargo arrives at level 13; locks arrive at level 16. Only six short coach tips are used.
- The V2 model, colour-readability and ground-flicker fixes remain included. Levels 21–100, the sorting rules, solver, saved-progress format and economy rules are unchanged.

## Open this source package

Import `project.godot` from the repository root into Godot 4.5.2, using the
Compatibility renderer. Start with `scenes/main.tscn`. Models are included;
rebuild scripts are in `tools/blender/`. See the [developer guide](../DEVELOPMENT.md)
for commands and export setup. Earlier standalone preview launchers and model
packs are separate historical deliverables and are not required here.

The save code supports local stars, coins and harbour progress. An unfinished
level whose layout has changed restarts safely. Android builds with a different
application ID use separate installed-app data; the public source now uses a
neutral ID as described in the developer guide.

## Checks and limits

The recorded V3 validation reports 100 stored solutions completed with three stars and eight covered-cargo variants across four opening levels. The design aimed for a strategy based only on visible information. The included verifier replays variant-specific solutions; it does not independently establish that strategy property. Later generated covered-cargo levels use sampled shuffles.

The rendered dispatch regression covered rapid legal taps in levels 3, 10, 20 and 100; all 30 monitored launch events occurred after docking and loading. It also checked berth handovers, undo during a chain, restart during the winning animation, and reduced motion. The final run reported zero failures and no script errors.

The included animation and screenshots come from the running game renderer. They are not Blender concept renders. New sounds were generated as original WAV assets and checked for clipping; subjective listening and phone speaker tuning remain useful next checks.

No updated APK has been built, and this version has not been measured on a physical Android phone. Desktop/browser checks do not establish mobile frame rate, battery use or player retention. Automated puzzle checks are not human playtesting.
