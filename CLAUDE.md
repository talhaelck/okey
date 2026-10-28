# Sneaky Okey

3D, stylized, 4-player party Okey game with stealth/stealing mechanics. Full vision and roadmap: [master.md](master.md). Future ideas: [guncellemeOnerisi.md](guncellemeOnerisi.md).

## Working with the team
- Talha owns the project; friends pull the repo and develop with Claude Code too. Talk to them in Turkish, casual tone.
- Assume no 3D modelling or game-engine knowledge: explain what to click/test in plain words.
- They test by running the game and giving feedback on feel; keep each change small and testable.
- Several people push to `main`: pull before starting, commit small, and do not rewrite shared history.

## Tech
- **Engine:** Godot 4.7 (GDScript, Forward+). Executable: `C:\Tools\Godot\godot.cmd` (on user PATH as `godot`).
- Scenes are thin; most geometry is built in code so it stays text-editable. Placeholder art is procedural until real assets replace it.
- Art is made by Claude, not by hand: Blender 5.2.3 LTS lives in `C:\Tools\blender-5.2.3-windows-x64\` and models are
  built by Python scripts in `tools/blender/` (metaballs for organic shapes), exported to `assets/models/`.
  Rebuild the dayı: `blender -b --factory-startup -P tools/blender/dayi.py -- <abs path>/assets/models/dayi/dayi.glb [preview.png]`.
  Always render the preview and look at it after changing a model.

## Layout
```
scenes/            main.tscn (entry), table.tscn, seat.tscn
scripts/main.gd    deals tiles, wires camera/hand/watchers/HUD, debug screenshot mode
scripts/camera/    focus_camera.gd: observe/rack modes + depth-of-field blur
scripts/world/     rounded_box, toon (materials), tile + tile_factory, rack (2x15 slots), table (pile, loose tiles),
                   seat, buddy (opponent dayı: procedural breathing, head turn, head shake), room
scripts/character/ appearance.gd: dayı colours + optional parts (hat, mustache), random(), apply() to a dayi.glb
tools/blender/     dayi.py: builds the seated dayı; head parts sit under a "Head" pivot node
scripts/play/      hand.gd: local glove, ray picking, drop targets, steal/caught; watcher.gd: opponent glance AI
scripts/ui/        hud.gd: crosshair, hint, score, flash messages (built in code)
assets/            models/dayi/dayi.glb (generated, do not hand-edit), CREDITS.md (third-party assets only)
```

## Commands
- Import / refresh class cache: `godot --path . --headless --import`
- Run the game: `godot --path .` (Talha uses `.\oyna.cmd`, which calls the full exe path; VS Code terminals may not see the PATH entry)
- Debug screenshot (opens a window briefly, saves PNG, quits):
  `godot --path . -- --screenshot=screenshots/observe.png`. Extra flags: `--focus` (rack mode), `--yaw=<rad>` /
  `--pitch=<rad>` (head direction; negative yaw looks right), `--hold` (a tile in the glove), `--caught` (caught flash).
  Read the PNG to check visuals after any rendering change.

## Setup on a new machine
- Install Godot **4.7.2 standard (not .NET)** from https://godotengine.org. Either unzip to `C:\Tools\Godot\` (matches `oyna.cmd` and `.mcp.json`) or put `godot` on PATH and edit `GODOT_PATH` in `.mcp.json`.
- To change models, also unzip Blender 5.2.3 LTS (https://download.blender.org/release/Blender5.2/) to `C:\Tools\`.
- First run: `godot --path . --headless --import`, then `.\oyna.cmd`.

## Status (2026-10-29)
- Done: Phase 1 (room, table, seats, racks, tiles, deal, observe/rack camera with depth-of-field blur).
- Done: Phase 2 single-player demo.
  - Opponents are our own Blender dayıs with random Appearance (vest, cap, skin, hair colours; hat/mustache on or off).
  - Left click grabs/drops: aim with the crosshair in observe mode, with the mouse in rack mode. Reach is 1.35 m.
  - Drops go to the nearest free slot on any rack, or loose on the felt.
  - Tiles taken from another player's rack are "stolen" until dropped. If a Watcher looks at you meanwhile,
    the tile snaps back, the opponent shakes its head and the HUD shows "YAKALANDIN!".
  - Watchers glance at players every 2.5-6 s, with a short half-turn first. They show a yellow "!" when looking at you.
- Not yet: Okey rules/turns (Phase 4), multiplayer (Phase 3), sounds.
- **Direction changed (see master.md section 6):** 101 Okey, "Yakala!" key instead of automatic catching, kahvehane dayıları
  with a modular character creator. The procedural room is a throwaway placeholder.
- Done: layout pass (1.5 m table, chairs at 1.15 m, eye at 1.35 m; centre pile visible, own rack low and blurred).
- Next: "Yakala!" mechanic, kahvehane room + props from Blender scripts, more dayı parts (mustache/hat/body variants),
  then the character creator screen.

## Rules
1. Keep network, camera/visual effects and Okey rules in separate modules (see master.md section 5).
2. One module per step; every step must run without errors and be checkable by screenshot or by Talha.
3. Assets: only CC0 or CC-BY. Record source URL + license in `assets/CREDITS.md` before using.
