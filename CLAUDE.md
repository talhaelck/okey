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
- No external art tools are required: models are CC0 glTF downloads (Quaternius, Kenney, Poly Pizza) or procedural meshes.

## Layout
```
scenes/            main.tscn (entry), table.tscn, seat.tscn
scripts/main.gd    deals tiles, wires camera/hand/watchers/HUD, debug screenshot mode
scripts/camera/    focus_camera.gd: observe/rack modes + depth-of-field blur
scripts/world/     rounded_box, toon (materials), tile + tile_factory, rack (2x15 slots), table (pile, loose tiles),
                   seat, buddy (animated glTF opponent), room
scripts/play/      hand.gd: local glove, ray picking, drop targets, steal/caught; watcher.gd: opponent glance AI
scripts/ui/        hud.gd: crosshair, hint, score, flash messages (built in code)
assets/            models/characters/*.glb, CREDITS.md (license + source for every asset)
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
- First run: `godot --path . --headless --import`, then `.\oyna.cmd`.

## Status (2026-10-29)
- Done: Phase 1 (room, table, seats, racks, tiles, deal, observe/rack camera with depth-of-field blur).
- Done: Phase 2 single-player demo.
  - Opponents are CC0 Quaternius characters (`character` / `character_height` on each Seat in main.tscn), idle-animated.
  - Left click grabs/drops: aim with the crosshair in observe mode, with the mouse in rack mode. Reach is 1.35 m.
  - Drops go to the nearest free slot on any rack, or loose on the felt.
  - Tiles taken from another player's rack are "stolen" until dropped. If a Watcher looks at you meanwhile,
    the tile snaps back, the opponent shakes its head and the HUD shows "YAKALANDIN!".
  - Watchers glance at players every 2.5-6 s, with a short half-turn first. They show a yellow "!" when looking at you.
- Not yet: Okey rules/turns (Phase 4), multiplayer (Phase 3), sounds, a real sitting pose for standing models.

## Rules
1. Keep network, camera/visual effects and Okey rules in separate modules (see master.md section 5).
2. One module per step; every step must run without errors and be checkable by screenshot or by Talha.
3. Assets: only CC0 or CC-BY. Record source URL + license in `assets/CREDITS.md` before using.
