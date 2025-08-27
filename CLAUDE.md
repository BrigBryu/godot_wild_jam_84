# Beach Critters - Project Memory & Guidelines

## Purpose
Guide Claude Code's changes in this repo:
- Use **modern Godot 4** practices
- Follow **clean, conventional design**
- **Use the existing utilities layer** (managers, scene manager, signal bus, spawners)
- Keep diffs **small, readable, and testable**
- **Correct me bluntly** if I'm off - never let me go astray, prioritize good design patterns

## Source of Truth & Layout
- **CLAUDE.md** (this file) — Single source of truth for AI assistance and project guidelines
- **PROJECT_STRUCTURE.md** — The definitive project organization guide
- **utilities/signals/EVENTS_DOCUMENTATION.md** — Complete SignalBus event reference
- **Folder READMEs** — Each major folder contains implementation details
- **Project layout (must respect):**
  ```
  /assets/        art, audio, shaders (non-code)
  /common/        shared code (e.g., shaders, state_machine)
  /config/        Resources & settings (e.g., AudioSettings.gd, GameSettings.gd)
  /entities/      gameplay scenes (player, organisms/critters, ui/*)
  /localization/  languages
  /stages/        level scenes (e.g., beach/*, tilesets/*, shaders/*)
  /utilities/     infrastructure layer (managers/, signals/, spawning/, scene_manager/)
  /tests/         (if present) unit/scene tests
  ```

If a change conflicts with PROJECT_STRUCTURE.md, **open an issue** instead of pushing code.

## Godot 4 — Required Practices

### GDScript 2.0 & Typing
- Typed GDScript everywhere (vars, params, returns)
- Prefer `@onready var` for cached nodes; avoid `get_node()` in hot loops
- Use `const` for paths/resources; minimize magic strings

### Nodes, Scenes, Composition
- Prefer **composition** over deep inheritance
- Break large scenes into children; use **Groups** for cross-cutting roles
- Use **Resources** for tuneables/config over giant scripts

### Input & Update Loops
- Use **InputMap** (no raw keycodes)
- Physics in `_physics_process(delta)`, visuals in `_process(delta)`
- Prefer **Timers/State Machines** over per-frame polled booleans

### Performance Hygiene
- No per-frame `get_node()`; no allocations in hot paths
- Use `await` sparingly; prefer signals/timers
- Profile with **Debugger → Monitors**; fix spikes before adding features

### File/Node Conventions
- Files: `snake_case.gd`, scenes: `PascalCase.tscn`, constants: `UPPER_SNAKE`
- Node names are semantic (`Player`, `CameraRig`, `Hitbox`)
- Keep scripts ≲ ~300 lines; otherwise refactor

### Data & Config
- Use **Resources** for serialized, tunable data; JSON only for bulk/runtime data
- No hard-coded paths/IDs; export them

### Error Handling & Docs
- Dev: `assert()` early; Prod: clear early returns
- Guard scene assumptions with `@onready` checks & `is_instance_valid()`
- Public functions: 1–2 line docstring (what/when)
- Comment tricky math, shader branches, and non-obvious decisions

## Utilities & Systems Contracts (USE THESE)

### Signals (/utilities/signals)
- **SignalBus.gd** is the event hub; **use it instead of direct coupling**
- Define/extend events in `EVENTS_DOCUMENTATION.md` and keep names stable
- Emitting pattern:
  ```gdscript
  SignalBus.emit_signal("critter_collected", critter_id, points)
  ```
- Connecting pattern (code, not editor):
  ```gdscript
  SignalBus.critter_collected.connect(_on_critter_collected.bind(), CONNECT_DEFERRED)
  ```

### Managers (/utilities/managers)
- **GameManager.gd**: game flow/state; do not duplicate run-state flags elsewhere
- **ScoreManager.gd**: the single source of truth for score. Update via its API or signals:
  ```gdscript
  SignalBus.critter_collected.connect(func(id: String, pts: int) -> void:
      ScoreManager.add_points(pts)
  )
  ```
- Managers may be autoloads; do not introduce new singletons without explicit approval

### Scene Management (/utilities/scene_manager)
- All scene loads/transitions must go through the scene manager API (if present):
  ```gdscript
  SceneManager.request_change("res://stages/beach/BeachMinimal.tscn")
  ```
- No `get_tree().change_scene_to_file(...)` in gameplay scripts

### Spawning (/utilities/spawning)
- CritterSpawner.gd is the only path to spawn critters:
  ```gdscript
  CritterSpawner.spawn_critter(critter_type: String, at: Vector2)
  ```
- Spawner reads tunables from /config Resources
- Add new critters via Resource data + factory mapping, not match chains in gameplay code

### Configuration (/config)
- Add/modify tunables via Resources (e.g., GameSettings.gd, AudioSettings.gd)
- Gameplay code reads from these; no hard-coded constants scattered in scripts

### UI & Entities
- UI scenes live under `/entities/ui/*` and are dumb: they subscribe to SignalBus and display state
- Entities under `/entities/organisms/*` expose small, focused signals/APIs; avoid reaching "up" the tree

## What Claude Must Do Before Changing Things
1. Read relevant docs in /readme/ and EVENTS_DOCUMENTATION.md
2. Identify which utility (manager/scene/spawner/signal) applies; use it rather than adding new glue
3. Summarize current architecture & constraints in the patch header (1–2 short paragraphs)
4. Propose a minimal diff; no drive-by refactors
5. Include a manual test plan; add/adjust Resources/Groups as needed

## Things Claude Must Not Do
- Add new singletons/global state without explicit justification
- Rewrite file/scene layout already standardized in /readme/ or PROJECT_STRUCTURE.md
- Add heavy plugins/deps casually
- Leave TODOs without an issue reference

## Patch Patterns (examples)

### Emit → react via SignalBus
```gdscript
# On collect:
SignalBus.emit_signal("critter_collected", id, points)

# In score UI:
SignalBus.critter_collected.connect(func(_id: String, pts: int) -> void:
    ScoreManager.add_points(pts)
    _refresh_display()
)
```

### Scene change via SceneManager
```gdscript
func _on_time_up() -> void:
    SceneManager.request_change("res://entities/ui/menu/MainMenu.tscn")
```

### Spawn via CritterSpawner
```gdscript
func _try_spawn_starfish(pos: Vector2) -> void:
    CritterSpawner.spawn_critter("starfish", pos)
```

## Review Checklist
- ✅ Typed GDScript, no magic strings/paths?
- ✅ Uses SignalBus, Managers, SceneManager, CritterSpawner (no ad-hoc wiring)?
- ✅ Respects directory layout & /readme/ rules?
- ✅ Minimal diff with clear commit message?
- ✅ Manual test steps; debug scene still works?
- ✅ No perf foot-guns (allocs in loops, repeated get_node)?
- ✅ Tunables in /config Resources; InputMap used?

## Team Preferences
- **It's okay to challenge assumptions—correctness over politeness**
- **Correct me bluntly if I'm off**
- **Never let me go astray**
- **Do not be sycophantic**
- **Always keep me on good design patterns and practices**

## Godot MCP Setup
- The project is set up with Godot MCP for Claude Code
- This provides Claude with tools to:
  - Parse, lint, and check syntax of GDScript, scene files, and shaders
  - Run sanity checks to ensure files can load without syntax/runtime errors
  - Verify patches compile cleanly before suggesting them

## Expectations for Claude
- Always run MCP syntax checks before proposing or finalizing changes
- Do not commit diffs that break the project (syntax, missing nodes, broken scenes)
- If a patch cannot be syntax-checked or validated in MCP, Claude must say so explicitly and propose a fix
- Treat "the game runs without parser errors" as a baseline requirement for every patch

## Integration with Utilities
When introducing or editing code, Claude must:
1. Check MCP output for parser or runtime errors
2. Use `/utilities/` managers, spawners, scene_manager, and SignalBus instead of re-implementing
3. Confirm MCP checks pass after integration

## Current Project State
- **Game**: Beach Critters for Wild Jam 84
- **Core Mechanics**: Wave physics system, critter collection
- **Architecture**: Entity-based with inheritance (BaseOrganism → Critters)
- **Communication**: Signal bus pattern for decoupling
- **Recent Work**: Wave system implementation, player wave detection, visual/audio feedback