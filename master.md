# Project Overview: 3D Co-op Casual Okey Game (Working Title: "Sneaky Okey")

## 1. Project Vision & Concept
A 3D, stylized, multiplayer casual party game based on traditional Turkish Okey, infused with stealth and deception mechanics similar to *Liar's Bar* and *Lethal Company*. 

Four players sit at a table in a cozy, cartoonish setting. The twist: players can physically interact with the environment, steal tiles from opponents, or manipulate the board—but only when others aren't looking.

### Key Visual & Art Style
* **Style:** Stylized Low-Poly / Toon Shader (similar to *Bombanana*, *Gang Beasts*, or *Human Fall Flat*).
* **Vibe:** Cute, vibrant, round edges, funny ragdoll/hand animations, non-serious and party-oriented.
* **Environment:** 3D room, 4 chairs, a central table, custom 3D racks (ıstaka), and 3D tiles (taşlar).

---

## 2. Core Game Loop & Mechanics

### Focus & Blur System (Depth of Field Mechanics)
To facilitate stealing and sneaky actions without split-screen cheating:
1. **Focus Mode (Looking at Rack):**
   * When a player presses a key (e.g., `Space` or `RMB`), the camera smoothly transitions to a close-up top-down/angled view of their own rack (ıstaka).
   * **Visual Effect:** The rest of the room and other players blur out completely (heavy Depth of Field / Blur Shader).
   * **Gameplay Consequence:** While organizing or viewing your tiles, you lose vision of what other players are doing with their hands.
2. **Observe Mode (Looking at Table/Room):**
   * The player looks around the table in 1st person or tight 3rd person.
   * **Visual Effect:** The player's own rack becomes blurred / out of focus.
   * **Gameplay Consequence:** You can see if an opponent is reaching over to steal, but you can't clearly read or organize your own tiles.

### Stealth & Interaction Mechanics
* **Free-Hand Reaching:** Players can extend their hand/arm across the table to grab tiles from the center, discarded piles, or covertly swipe a tile from a neighbor's rack.
* **Catching Cheaters:** If a player catches another player in the act of stealing (looking directly at them while they interact with a stolen tile), a funny penalty or challenge triggers (e.g., callout button, round forfeit, physical ragdoll slap).
* **Physics Interactions:** Tiles are physical 3D objects with lightweight colliders that can be picked up, placed, or accidentally knocked over.

---

## 3. Technical Architecture & Tech Stack

* **Engine:** Godot Engine 4.7 (GDScript, Forward+ renderer). *(Chosen: text-based scenes let AI build and test everything; CC0 glTF assets import natively.)*
* **Networking:** 
  * Godot High-Level Multiplayer (ENet for LAN/dev, Steam networking later).
  * Authority-based state synchronization: Tile positions, player head look-angles, and hand IK positions synced across 4 clients.
* **Graphics & Shaders:**
  * Custom Depth of Field / Bokeh blur post-processing shader tied to camera modes.
  * Stylized toon shader with simple color palettes (unlit/soft ambient occlusion).

---

## 4. Step-by-Step Development Roadmap

### Phase 1: Core Camera & Focus Prototype
* Set up a basic 3D scene with 4 dummy positions and a table.
* Implement 1st person camera rotation.
* Implement camera focus toggle (Look at Rack vs. Look at Table) with dynamic Depth of Field/Blur interpolation.

### Phase 2: Tile & Rack Interactions (Single Player)
* Implement 3D tile spawning, grabbing, and snapping to racks.
* Add raycast/physics-based hand interaction to pick up tiles from table or opponent's area.

### Phase 3: Multiplayer Networking (4-Player Lobby)
* Set up room lobi system (Host/Join).
* Sync player camera rotation (head turning) and hand reach position across network.
* Ensure tile ownership and physical location sync accurately.

### Phase 4: Basic Okey Game Logic
* Implement core Okey rules (tile distribution, draw pile, discard pile, turn management).
* Integrate rule-checking alongside manual physics placements.

### Phase 5: Asset Integration & Polishing
* Replace primitive shapes with stylized AI-generated 3D models (Meshy / Tripo3D / Low-poly assets).
* Add hand animations/IK for reaching and grabbing.
* Sound effects (tile clinks, comedic alert sounds, background tavern/room ambience).

---

## 5. Instructions for AI Assistant (Claude Code Guidelines)

When writing code or building architecture for this repository:
1. **Keep it modular:** Separate network logic from visual/camera effects and Okey game rules.
2. **Prioritize Physics & Feel:** Interaction responsiveness is key. Ensure grabbing felt physics-based yet snappy.
3. **Shader Efficiency:** Keep post-processing blur optimized for middle-range hardware.
4. **Step-by-Step Implementation:** Do not attempt full game logic in a single turn. Always write functional, testable scripts per module (e.g., Camera Controller first, then Interaction Raycaster, then Multiplayer Sync).
---

## 6. Decisions (2026-10-29)

### Game rules
* **Variant:** 101 Okey (point-based, 101-point penalties). Classic okey may come later as a mode.
* **Catching thieves is a player action, not automatic.** Look at the thief and press the **"Yakala!"** key.
  * Valid only while the stolen tile is still in the thief's hand or was taken within the last few seconds.
  * Correct call: the tile returns to its owner and the thief gets a **101 penalty**.
  * Wrong call: the accuser gets the penalty, so nobody spams the key.
* **"Arkadaş modu"** (lobby option): the game never applies penalties. It only announces "X taş çalarken görüldü!" to everyone and players settle it themselves.
* Bots use the same rule: they must "see" you, then they call "Yakala!".

### Art direction: Turkish kahvehane (coffeehouse)
* Players are cute, stylized **kahvehane dayıları** (coffeehouse uncles). Chunky, round, Bombanana-like proportions. No animal characters.
* Room is a cozy kahvehane: green-felt okey tables, hasır (wicker) chairs, ince belli çay bardağı, semaver, old TV, wall clock, calendar, signboard.
* No smoking props.

### Character creator (skins)
A modular dayı on **one shared skeleton**, so every part works with every animation (Mixamo humanoid rig):
1. **Base body:** 2-3 body types (göbekli, zayıf, iri) with the same rig, plus a skin tone parameter.
2. **Head attachments** (BoneAttachment3D on the head bone, static meshes): bıyık types, sakal, hair or bald, kasket/şapka/takke, gözlük.
3. **Hand attachments:** tespih, çay bardağı.
4. **Outfit:** first as material/colour/pattern variants (yelek, gömlek, hırka), later as separate skinned outfit meshes.
* An appearance is just a small set of item ids plus colours (`CharacterAppearance` resource, saved locally). Multiplayer later only syncs these ids.
* Creator screen: rotating 3D dayı preview in the kahvehane, category tabs (Yüz, Bıyık, Şapka, Kıyafet, Aksesuar), arrows and colour swatches, and a "Rastgele dayı" button. Bots get random appearances.

### Asset pipeline (AI-generated)
1. **Concept image:** generate a front-view, A-pose dayı with an image AI. Keep the base bald, clean-shaven and without accessories so parts stay separate.
2. **Image to 3D:** convert the concept to a 3D model with Meshy or Tripo. Generate accessories as separate small models.
3. **Rig and animate:** auto-rig in Mixamo (or Meshy). Use Mixamo animations: Sitting Idle, Sitting Laughing, Sitting Talking, Pointing, Sitting Clap, plus reactions.
4. **Import:** drop GLB/FBX files into `assets/` (Godot imports FBX natively) and record the source in `assets/CREDITS.md`.
