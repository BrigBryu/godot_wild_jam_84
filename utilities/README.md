# Utilities

## Purpose
Behind-the-scenes helper logic and game systems that don't directly appear in the game world but manage game functionality.

## Structure

### managers/
Core game management systems
- GameManager.gd - Overall game state
- SaveManager.gd - Save/load system
- ResourceManager.gd - Resource pooling
- ScoreManager.gd - Score and statistics

### signals/
Global signal bus for decoupled communication
- SignalBus.gd - Centralized signal system
- EventTypes.gd - Event definitions
Usage:
```gdscript
# Emit
SignalBus.emit_signal("critter_collected", critter_type)
# Listen
SignalBus.connect("critter_collected", _on_critter_collected)
```

### scene_manager/
Scene transitions and loading
- SceneManager.gd - Scene switching
- TransitionEffects.gd - Fade/slide effects
- LoadingScreen.tscn - Loading UI

## Utility Guidelines
1. Should be autoloaded (singletons) when needed globally
2. Provide clean APIs for other systems
3. Handle errors gracefully
4. Document public methods

## Autoload Setup
Add to Project Settings > Autoload:
```
GameManager -> utilities/managers/GameManager.gd
SignalBus -> utilities/signals/SignalBus.gd
SceneManager -> utilities/scene_manager/SceneManager.gd
```

## Common Patterns
```gdscript
# Singleton access
GameManager.start_game()
SceneManager.change_scene("res://stages/beach/BeachMinimal.tscn")
SignalBus.player_died.emit()
```