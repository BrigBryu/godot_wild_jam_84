# Entities

## Purpose
All interactive game objects that exist as siblings to the player in the scene tree. These are things the player can see, interact with, or that affect gameplay.

## Structure Pattern
```
Base Type (Script)
└── Sub Type (Folder)
    └── Implementation (Folder)
        ├── art/
        ├── data/
        └── sound/
```

## Categories

### player/
The player character and all associated systems
- **art/** - Player sprites, animations
- **data/** - Player stats, configuration
- **sound/** - Footsteps, voice, actions
- PlayerController.gd
- Player.tscn

### organisms/
Living creatures in the game world
- **base/** - Base scripts for all organisms
  - BaseOrganism.gd - Common organism behavior
  - OrganismStats.gd - Shared stat system
- **critters/** - Collectible creatures
  - BaseCritter.gd - Base critter behavior
  - **starfish/** - Starfish implementation
    - art/ - Starfish sprites
    - data/ - Starfish properties
    - sound/ - Starfish sounds

### weather/
Environmental effects and weather systems
- WeatherSystem.gd
- Rain.tscn
- Wind.tscn
- Fog.tscn

### ui/
Core UI that exists in the game world (not HUD)
- InteractionPrompt.tscn
- WorldSpaceHealth.tscn
- SpeechBubble.tscn

## Inheritance Example
```gdscript
# organisms/base/BaseOrganism.gd
class_name BaseOrganism
extends Node2D

@export var health: int = 100
@export var movement_speed: float = 50.0

# organisms/critters/BaseCritter.gd
class_name BaseCritter
extends BaseOrganism

@export var collection_value: int = 10

# organisms/critters/starfish/Starfish.gd
extends BaseCritter

func _ready():
    health = 1
    collection_value = 10
```

## Guidelines
1. Always use the art/data/sound subfolder pattern
2. Base classes should be abstract with virtual methods
3. Implementations should override base behavior
4. Keep entity-specific logic contained