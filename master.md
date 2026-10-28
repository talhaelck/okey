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