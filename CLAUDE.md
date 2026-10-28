# Sneaky Okey

3D, stylized, 4-player party Okey game with stealth/stealing mechanics. Full vision and roadmap: [master.md](master.md). Future ideas: [guncellemeOnerisi.md](guncellemeOnerisi.md).

## Working with Talha
- Talk to Talha in Turkish, casual tone. He does not know 3D modelling or game engines, so explain what to click/test in plain words.
- He tests by running the game and giving feedback on feel; keep each change small and testable.

## Tech
- **Engine:** Godot 4.7 (GDScript, Forward+). Executable: `C:\Tools\Godot\godot.cmd` (on user PATH as `godot`).
- Scenes are thin; most geometry is built in code so it stays text-editable. Placeholder art is procedural until real assets replace it.
- No external art tools are required: models are CC0 glTF downloads (Quaternius, Kenney, Poly Pizza) or procedural meshes.

## Layout
```
scenes/            main.tscn (entry), table.tscn, seat.tscn
scripts/main.gd    deals tiles, wires the local camera, debug screenshot mode
scripts/camera/    focus_camera.gd: observe/rack modes + depth-of-field blur
scripts/world/     rounded_box, toon (materials), tile_factory, rack, table, seat, room
assets/            models/, textures/, CREDITS.md (license + source for every asset)
```

## Commands
- Import / refresh class cache: `godot --path . --headless --import`
- Run the game: `godot --path .` (Talha uses `.\oyna.cmd`, which calls the full exe path; VS Code terminals may not see the PATH entry)
- Debug screenshot (opens a window briefly, saves PNG, quits):
  `godot --path . -- --screenshot=screenshots/observe.png` (add `--focus` for rack mode).
  Read the PNG to check visuals after any rendering change.

## Setup on a new machine
- Install Godot **4.7.2 standard (not .NET)** from https://godotengine.org. Either unzip to `C:\Tools\Godot\` (matches `oyna.cmd` and `.mcp.json`) or put `godot` on PATH and edit `GODOT_PATH` in `.mcp.json`.
- First run: `godot --path . --headless --import`, then `.\oyna.cmd`.

## Status (2026-10-28)
- Done: Phase 1. Room, table, 4 seats, racks, procedural tiles, 106-tile shuffle and deal, centre pile + indicator. Camera observe/rack modes with depth-of-field blur work and feel good (Talha confirmed).
- Placeholder characters are procedural "buddies" in `seat.gd` (`_build_buddy`). Talha finds them low quality.
- In progress: replacing buddies with CC0 Quaternius models already in `assets/models/characters/` (see CREDITS). They are not wired in yet. Notes:
  - Models are about 3-3.7 m tall in glTF units. Scale to roughly 0.35-0.4 so heads sit near y = 1.2.
  - `blue_buddy` animations: Idle, Wave, Yes, No, HitReact, Duck... `rabbit`/`pigtail_rabbit` also have Sitting_Idle. `mushnub`/`cactoro`: Idle, Dance, Yes, No, HitRecieve.
  - Animation names carry a `CharacterArmature|` prefix (triple-prefixed on the rabbits). Match by suffix.
- Next: Phase 2 tile interaction. Drag tiles within the rack in rack mode; in observe mode, a crosshair click reaches a glove over to grab a pile tile or steal from another rack; dropping on the felt places a tile loose.

## Rules
1. Keep network, camera/visual effects and Okey rules in separate modules (see master.md section 5).
2. One module per step; every step must run without errors and be checkable by screenshot or by Talha.
3. Assets: only CC0 or CC-BY. Record source URL + license in `assets/CREDITS.md` before using.
