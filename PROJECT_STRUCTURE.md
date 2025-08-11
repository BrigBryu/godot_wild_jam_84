# Beach Critters Project Structure

## Overview
This project follows a modular, scalable architecture designed for maintainability and reusability. Each top-level folder serves a specific purpose with clear separation of concerns.

## Folder Structure

### 📦 common/
**Purpose**: Standalone, reusable components with no project dependencies
- Can be shared across projects
- Must be self-contained with no references to Beach Critters specific code
- **Subfolders**:
  - `debug/` - Debug tools and visualization systems
  - `state_machine/` - Generic state machine implementation
  - `shaders/` - Reusable visual effects and shaders

### ⚙️ config/
**Purpose**: Game configuration and settings management
- All user-configurable options
- Audio bus configurations
- Graphics settings
- **Subfolders**:
  - `settings/` - User preferences and game settings
  - `audio/` - Audio bus configurations and sound settings
  - `graphics/` - Resolution, quality, and visual settings

### 🎮 entities/
**Purpose**: Everything the player sees and interacts with in the game world
- Siblings to the player in the scene tree
- Interactive game objects
- **Structure Pattern**: Base Type → Sub Types → Implementations
- **Subfolders**:
  - `player/` - Player character with art/, data/, sound/ subfolders
  - `organisms/` - Living creatures
    - `base/` - Base organism scripts for inheritance
    - `critters/` - Specific creature implementations
      - `starfish/` - Starfish with art/, data/, sound/
  - `weather/` - Weather systems and effects
  - `ui/` - Core UI entities that exist in the game world

### 🌍 localization/
**Purpose**: Multi-language support
- Translation files and localized text
- **Subfolders**:
  - `en/` - English translations
  - `es/` - Spanish translations
  - `fr/` - French translations

### 🗺️ stages/
**Purpose**: Game locations and environments
- Parents to entities in the scene tree
- Level definitions and implementations
- **Subfolders**:
  - `beach/` - Beach stage implementation
  - `pier/` - Pier stage implementation
  - `tilesets/` - Shared tileset resources

### 🛠️ utilities/
**Purpose**: Behind-the-scenes helper logic
- Non-visual game systems
- **Subfolders**:
  - `managers/` - Game state and resource managers
  - `signals/` - Global signal bus system
  - `scene_manager/` - Scene transition and loading

### 🎨 assets/
**Purpose**: Global game resources
- Resources used throughout the entire game
- **Subfolders**:
  - `audio/` - Global sound effects and music
  - `credits/` - Credit information and assets
  - `fonts/` - Game fonts

## File Organization Rules

### Art, Data, Sound Pattern
For entities with assets, use this subfolder structure:
- `art/` - Sprites, textures, visual assets
- `data/` - Configuration files, stats, JSON/resource files
- `sound/` - Audio files specific to this entity

### Inheritance Pattern
For entities with variants:
1. Base script at folder level (e.g., `organisms/BaseOrganism.gd`)
2. Subtype folders for categories (e.g., `organisms/critters/`)
3. Implementation folders for specific types (e.g., `organisms/critters/starfish/`)

### Naming Conventions
- **Scripts**: PascalCase (e.g., `PlayerController.gd`)
- **Scenes**: PascalCase (e.g., `Player.tscn`)
- **Resources**: snake_case (e.g., `player_sprite.png`)
- **Folders**: snake_case (e.g., `state_machine/`)

## Scene Tree Hierarchy
```
Main (Stage)
├── Player (Entity)
├── Critters (Entities)
├── Weather (Entity)
└── UI (Entity)
```

## Best Practices
1. **No Cross-Dependencies**: Common folder must not reference project-specific code
2. **Clear Ownership**: Each file should clearly belong to one folder
3. **Consistent Structure**: Follow the art/data/sound pattern for all entities
4. **Documentation**: Each major folder has its own README.md
5. **Inheritance**: Use base classes for shared behavior