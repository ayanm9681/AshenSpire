# AshenSpire

AshenSpire is a small Godot turn-based boss encounter prototype.

## Current gameplay loop

- You fight **The Warden** in a single arena.
- Each round alternates between:
  - **Player turn** (Attack, Heavy Attack, Defend, Item placeholder)
  - **Boss turn** (telegraphed incoming move)
- UI includes:
  - Boss/player HP bars
  - Telegraph panel
  - Combat log feed

## Combat notes

- Standard and heavy attacks spawn a travelling slash effect.
- Hit-pause + flash feedback is used on successful hits.
- Hero and boss attack animations now explicitly return to `idle` after attack resolution to avoid getting stuck in attack pose.

## Project structure

- `scenes/combat/BossArena.tscn` – main combat scene
- `scripts/combat/BossArena.gd` – combat scene logic and VFX triggers
- `scripts/combat/TurnManager.gd` – turn order/state and combat calculations
- `scripts/combat/SlashEffect.gd` – moving slash VFX behaviour

## Running

1. Open the project in Godot 4.
2. Run the main scene/project.
3. Use the action menu buttons to play through the encounter loop.
