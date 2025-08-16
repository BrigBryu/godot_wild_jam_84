# SignalBus Events Documentation

This document describes all the events available in the SignalBus and how to use them properly.

## Overview

The SignalBus is a global event system that allows different parts of the game to communicate without tight coupling. Instead of connecting nodes directly, systems emit and listen to events through this central hub.

## Usage Patterns

### Emitting Events
```gdscript
# Simple event emission
SignalBus.player_entered_water.emit()

# Event with data
SignalBus.player_moved.emit(new_position)

# Using helper functions
SignalBus.collect_critter("starfish", "Starfish", 10, Vector2(100, 200))
```

### Listening to Events
```gdscript
func _ready():
    # Connect to events you need
    SignalBus.critter_collected.connect(_on_critter_collected)
    SignalBus.ui_show_interaction_hint.connect(_on_show_hint)

func _on_critter_collected(critter_info: Dictionary):
    # Process collected critter

func _on_show_hint(show: bool, hint_text: String = ""):
    interaction_label.visible = show
    if show:
        interaction_label.text = hint_text
```

## Event Categories

### 🎮 Player Events

#### `player_moved(new_position: Vector2)`
**When:** Player position changes
**Emitted by:** PlayerController  
**Used by:** Camera systems, minimap, position tracking
**Example:**
```gdscript
SignalBus.player_moved.connect(_update_camera)
func _update_camera(pos: Vector2):
    camera.global_position = pos
```

#### `player_entered_water()`
**When:** Player enters water area
**Emitted by:** PlayerController  
**Used by:** Audio systems, particle effects, UI feedback

#### `player_exited_water()`
**When:** Player leaves water area
**Emitted by:** PlayerController  
**Used by:** Audio systems, particle effects, UI feedback

#### `player_interaction_attempted()`
**When:** Player presses interaction key (E)
**Emitted by:** PlayerController  
**Used by:** Debug systems, analytics

### 🦀 Critter Events

#### `critter_collected(critter_info: Dictionary)`
**When:** Critter is successfully collected
**Emitted by:** PlayerController via helper function  
**Data Structure:**
```gdscript
{
    "type": "starfish",      # Critter type ID
    "name": "Starfish",     # Display name
    "points": 10,           # Score value
    "position": Vector2()   # World position where collected
}
```
**Used by:** UI systems, score tracking, achievements

#### `critter_spawned(critter: Node2D)`
**When:** New critter is created in the world
**Emitted by:** CritterSpawner  
**Used by:** Minimap systems, critter tracking

#### `critter_highlighted(critter: Node2D)`
**When:** Critter becomes highlighted (player nearby)
**Emitted by:** PlayerController  
**Used by:** Visual effects, audio cues

#### `critter_unhighlighted(critter: Node2D)`
**When:** Critter highlight is removed
**Emitted by:** PlayerController  
**Used by:** Cleanup systems

#### `critter_interaction_available(critter: Node2D)`
**When:** Player gets close enough to interact with critter
**Emitted by:** PlayerController  
**Used by:** UI hint systems

#### `critter_interaction_unavailable(critter: Node2D)`
**When:** Player moves away from critter
**Emitted by:** PlayerController  
**Used by:** UI cleanup

### 🎯 Game State Events

#### `game_started()`
**When:** Game session begins
**Used by:** UI initialization, analytics

#### `game_paused()` / `game_resumed()`
**When:** Game pause state changes
**Used by:** Audio systems, animation pause

#### `game_ended(final_score: int, critters_collected: int)`
**When:** Game completion or quit
**Used by:** Score saving, statistics

#### `score_changed(new_score: int, score_change: int)`
**When:** Player's score changes
**Emitted by:** Score management systems  
**Used by:** UI updates, achievements

#### `collection_count_changed(new_count: int, total_critters: int)`
**When:** Number of collected critters changes
**Used by:** Progress tracking, completion detection

### 🖥️ UI Events

#### `ui_show_interaction_hint(show: bool, hint_text: String = "")`
**When:** Need to show/hide interaction prompt
**Emitted by:** PlayerController  
**Used by:** HUD systems
**Example:**
```gdscript
SignalBus.ui_show_interaction_hint.emit(true, "Press E to collect Starfish")
```

#### `ui_show_collection_effect(world_position: Vector2, points: int)`
**When:** Visual effect needed for collection
**Emitted by:** Helper function  
**Used by:** Particle systems, score popups

#### `ui_show_completion_message(total_score: int, total_collected: int)`
**When:** Game completion message needed
**Used by:** Victory screens

### 🏖️ Stage Events

#### `stage_generation_started()`
**When:** Beach/level generation begins
**Emitted by:** CritterSpawner  
**Used by:** Loading screens, progress bars

#### `stage_generation_completed(critter_count: int)`
**When:** Beach/level generation finishes
**Emitted by:** CritterSpawner  
**Used by:** UI initialization, critter counting

#### `stage_transition_started(new_stage: String)`
**When:** Moving to different stage/level
**Used by:** Transition effects, loading

#### `stage_transition_completed()`
**When:** Stage transition finishes
**Used by:** Cleanup, initialization

### 🐛 Debug Events

#### `debug_mode_toggled(enabled: bool)`
**When:** Debug mode is turned on/off
**Used by:** Debug UI, development tools

#### `debug_info_updated(info: Dictionary)`
**When:** Debug information needs updating
**Used by:** Debug displays, performance monitoring

### ⚙️ System Events

#### `settings_changed(setting_key: String, new_value)`
**When:** Game settings are modified
**Used by:** Audio, graphics, input systems

#### `audio_volume_changed(bus_name: String, volume: float)`
**When:** Audio volume is adjusted
**Used by:** Audio management systems

## Helper Functions

The SignalBus includes helper functions for common event patterns:

### `collect_critter(critter_type: String, critter_name: String, points: int, world_pos: Vector2)`
Emits multiple related signals for critter collection:
- `critter_collected`
- `score_changed` 
- `ui_show_collection_effect`

### `update_interaction_state(available: bool, critter: Node2D = null, hint_text: String = "")`
Manages interaction availability:
- `critter_interaction_available`/`critter_interaction_unavailable`
- `ui_show_interaction_hint`

### `complete_game(final_score: int, critters_collected: int)`
Handles game completion:
- `game_ended`
- `ui_show_completion_message`

## Best Practices

### When to Use SignalBus
✅ **DO use for:**
- UI updates from game world
- Cross-system communication (Audio ↔ Gameplay)
- Events that multiple systems need to know about
- Loose coupling between distant nodes

❌ **DON'T use for:**
- Simple parent-child communication
- High-frequency events (every frame)
- Events only one system cares about

### Event Naming
- Use descriptive, action-based names
- Include category prefixes (`ui_`, `player_`, etc.)
- Past tense for completed actions (`critter_collected`)
- Present tense for state changes (`game_paused`)

### Error Handling
```gdscript
# Always check if SignalBus exists in _ready()
func _ready():
    if SignalBus:
        SignalBus.critter_collected.connect(_on_critter_collected)
    else:
        push_error("SignalBus not found - check autoload configuration")
```

## Migration from Direct Connections

### Before (Direct Connection):
```gdscript
# PlayerController.gd
signal critter_collected(type: String)

# GameUI.gd  
func _ready():
    var player = get_tree().get_first_node_in_group("player")
    player.critter_collected.connect(_on_critter_collected)
```

### After (SignalBus):
```gdscript
# PlayerController.gd
# No direct signal needed

# GameUI.gd
func _ready():
    SignalBus.critter_collected.connect(_on_critter_collected)
```

This removes the need for the UI to find and directly connect to the player, making the code more maintainable and flexible.