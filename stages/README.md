# Stages

## Purpose
Game locations and environments that serve as parents to entities in the scene tree. These define where the gameplay takes place.

## Structure

### beach/
Main beach stage
- BeachMinimal.tscn - Main beach scene (simplified version)
- BeachMinimal.gd - Beach wave physics and management
- Sections/ - Beach sub-areas
  - TidalZone.tscn
  - SandyArea.tscn
  - RockyArea.tscn

### pier/
Pier stage area
- Pier.tscn - Main pier scene
- PierLogic.gd - Pier-specific mechanics
- PierData.tres - Pier configuration

### tilesets/
Shared tileset resources used across stages
- water_tiles.tres - Water tileset
- sand_tiles.tres - Sand variations
- rock_tiles.tres - Rock formations
- vegetation_tiles.tres - Plants and seaweed
- CommonTiles.gd - Tileset utilities

## Stage vs Entity
- **Stage**: The environment, serves as parent node
- **Entity**: Objects within the stage, siblings to player

Example Scene Tree:
```
Beach (Stage)
├── TileMap
├── Player (Entity)
├── Starfish (Entity)
└── Weather (Entity)
```

## Stage Requirements
1. Must have spawn points for player
2. Must define boundaries
3. Should handle level-specific logic
4. Can have sub-sections for organization

## Tileset Guidelines
- Share common tiles across stages
- Use consistent tile sizes (16x16 base)
- Include collision shapes
- Document tile IDs and purposes