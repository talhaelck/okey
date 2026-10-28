# Stealing, catching and evidence

Settings keys are in [101_rules.md](101_rules.md#çalma-stealing).

## Core idea
- The rules engine keeps track of how many tiles each player **should** hold (`expected_count`).
- The physical table is the truth of what each player **does** hold.
- A theft moves a tile physically without telling the rules engine. The difference between the two is the evidence.

Nothing stops a player from reaching. The risks are being seen during the act ("Yakala!") and being counted later ("Taş say!").

## Steal zones
Each zone has its own setting.

1. **Neighbours' racks:** the left and right player's racks. The opposite rack is out of reach (arm reach 1.5 m).
   The victim is a real person: if he is in rack mode he cannot see the hand, but he may notice the gap later.
2. **Discard rows:** each player's discards lie in a spread-out row on his right, not a stack.
   **Any** tile in any row can be taken, not only the top one. The rules only allow taking the top tile from the left
   player's row as your draw. Everything else is theft.
3. **Opened sets:** swap one of your rack tiles into a set on the table and take the okey (or any tile) out.
   It only works if the set stays valid. Invalid swaps are evidence anyone can see on the table.
4. **Centre pile:** draw an extra tile out of turn, or lift the top tile, look at it and put it back.
   A peek is not a theft (no count change) but is still a recorded event.

## Visibility log (`scripts/play/visibility.gd`)
- Every frame, for every player, store:
  - `head_dir`: where the head points.
  - `focused`: in rack mode or not.
  - `light`: 0-1 at the player's position.
- Every hand action is stored as a `TheftEvent`:
  - `thief`, `time`, `zone`, `tile`, `from`, `to`
  - `witnesses`: everyone whose view cone held the thief's hand at that moment, while not focused and with enough light.
- Seeing means the hand position is inside a 35° cone around the head direction. Line of sight goes through a ray test against bodies.
  Rack mode means seeing nothing beyond the rack. Darkness multiplies the cone by `light`.

## "Yakala!" (F)
- Accuses the player you are looking at.
- **Correct** if that player has a TheftEvent in the last `catch_window` seconds and you are one of its witnesses:
  - The tile goes back where it came from.
  - The thief gets `catch_penalty`.
  - The table reacts: everyone looks, the thief shakes his head.
- **Wrong** otherwise: the accuser gets `false_accusation_penalty`.
- Bots use the same rule. A bot calls "Yakala!" when it is a witness, with a reaction delay of 0.3-0.8 s and some chance of missing it.

## "Taş say!" (C, then look at the target)
- If the target's physical tile count is above `expected_count`, the target pays `count_check_penalty`. The extra tiles are returned to the pile or to their owners, whichever is known.
- Otherwise the challenger pays.
- The extra tiles are not identified. Only the count matters, so a well-hidden steal followed by discarding the extra tile is safe.

## Friend mode
No penalties are applied. Events are shown as announcements ("Recep taş çalarken görüldü!") and players settle it themselves.

## Bots as thieves
- Bot personality includes a `greed` value.
- A greedy bot steals when the victim is focused on his rack or looking away and nobody else is watching.
- It reaches with the IK arm, so a watching player sees the hand.

## Hooks for later modes (guncellemeOnerisi.md)
- **Blackout:** the room lights fade out on a timer and set `light` near 0 for everyone. Tile glints and hand silhouettes stay faintly visible.
- **Distractions:** table tap, lighter, radio. An event makes nearby players' heads turn toward the source for a moment, which is the visibility log's `head_dir` override.
- **Drink spill:** a timed blur on one player's camera, plus `focused` forced true.
- **Bomb tile:** a special tile with a timer. Passing it into another rack is a normal theft in reverse.
