# AGENT.md

## Purpose

This file is a working note for future agents editing this project.
It should optimize for fast onboarding, safe edits, and preserving the intended prototype loop.


## Project Summary

`Slay the Slime Lord` is a very small Godot 4 prototype that demonstrates two core concepts:

1. A short combat round where slimes move around the arena.
2. A between-round upgrade phase with a simple skill tree.

Current combat design:

- The mouse has a circular attack zone.
- The zone charges over time.
- When charge completes, it deals one pulse hit to every slime inside the circle.
- Slimes drop crystals on death.
- Crystals are the currency for the upgrade tree.


## Engine / Run

- Engine: Godot `4.6.x`
- Local executable used in this workspace: `F:\games_projects\Godot_v4.6.2-stable_win64.exe`
- Project root: `F:\games_projects\slay-the-slime-lord`

Useful validation command:

```powershell
& "F:\games_projects\Godot_v4.6.2-stable_win64.exe" --headless --path "F:\games_projects\slay-the-slime-lord" --quit-after 3
```

Use that after gameplay/script changes to catch parse and startup errors quickly.


## Important Files

- `project.godot`
  Starts the project in `res://scenes/main.tscn` and registers autoload services.

- `data/balance.json`
  Base player stats, round scaling, and combat limits.

- `data/skills.json`
  Skill tree definitions, ranks, costs, requirements, graph positions, and modifiers.

- `data/slimes.json`
  Slime content definitions.

- `data/languages.json`
  Supported manual localization languages.

- `data/localization/ru.json`
- `data/localization/en.json`
  String tables for the current manual localization layer.

- `scenes/main.tscn`
  Main prototype scene. Contains arena, HUD, skill tree overlay, and cursor pulse node.

- `scripts/main.gd`
  Main scene controller only. It coordinates runtime state, scene nodes, UI refresh, and phase transitions.

- `scripts/core/run_state.gd`
  Runtime simulation state for a run. This is the core gameplay model. It owns crystals, purchased skills, round number, derived stats, and spawn profile calculation.

- `scripts/autoload/content_db.gd`
  Loads content definitions from JSON. New gameplay content should usually start here, not in scene scripts.

- `scripts/autoload/localization.gd`
  Manual localization service. Use `Localization.tr_key(key, params)` instead of hardcoded UI strings.

- `scripts/slime.gd`
  Slime behavior and drawing. Movement, HP, death signal, and target highlighting.

- `scripts/crystal.gd`
  Small visual reward effect for slime death.

- `scripts/cursor_pulse.gd`
  Visual circle around the cursor. Shows charge state and pulse flash.

- `scripts/skill_tree_panel.gd`
  Upgrade screen logic and skill button refresh state.

- `описание.md`
  Original game concept from the user in Russian.


## Current Design Truths

Treat these as intentional unless the user asks to change them:

- Combat is not click-to-kill and not hover-DPS.
- Damage is dealt by periodic area pulse around the cursor.
- Upgrade phase happens after a short combat round.
- This is a prototype first, not production architecture.
- Placeholder visuals drawn in code are acceptable.
- Content should be data-driven where practical.
- UI text should go through localization keys.


## Architecture Rules

- `RunState` is the gameplay source of truth during a run.
- `ContentDB` is the source of truth for static game content.
- `Localization` is the source of truth for player-facing strings.
- Scene scripts should coordinate systems, not store large balance dictionaries.
- Add new skill modifiers as data in `data/skills.json` first, then teach `RunState` how to resolve them if a new mode is needed.
- Avoid pushing more gameplay state back into `main.gd` unless it is purely scene-specific.


## Editing Guidance

- Keep the loop playable above all else.
- Prefer simple scene/script changes over adding deep abstractions.
- If a mechanic changes, also update localization strings so the prototype stays readable.
- If you change combat stats or content, check:
  - `data/balance.json`
  - `data/skills.json`
  - `data/slimes.json`
  - `data/localization/*.json`
  - any runtime logic in `scripts/core/run_state.gd`
- If you add new gameplay nodes to the main scene, keep names stable and wire them explicitly in `@onready`.
- Avoid adding external asset dependencies unless they provide clear value.
- Procedural placeholder art is preferred over downloading random assets.


## Known Fast Paths

- To change pulse feel:
  - edit `attack_radius`
  - edit `attack_interval`
  - edit `pulse_damage`
  - all are currently in `data/balance.json`

- To change upgrade balance:
  - edit `data/skills.json`

- To add slime variants:
  - edit `data/slimes.json`
  - add localization names in both locale files

- To change arena presentation:
  - edit `scenes/main.tscn`
  - current ground is a simple faux-isometric polygon layout

- To add or update UI text:
  - edit `data/localization/ru.json`
  - edit `data/localization/en.json`


## When Extending The Prototype

Good next steps:

- Add a visible hit wave when the pulse fires.
- Add crystal pickup behavior instead of instant bank gain.
- Add one elite/boss slime type.
- Add more meaningful upgrade branching.
- Separate balance data from logic if the tree grows.

Do not overengineer early:

- No need for a full save/load system yet.
- No need for a large scene hierarchy split unless the prototype becomes hard to edit.
- No need for networking, ECS, or plugin-style architecture.


## Definition Of Done For Future Changes

After changes, a future agent should ideally verify:

1. Project loads without script errors.
2. A combat round starts.
3. Cursor pulse visibly charges and fires.
4. Slimes take damage only when inside the pulse radius.
5. Dead slimes reward crystals.
6. Upgrade screen opens and purchases affect the next round.
