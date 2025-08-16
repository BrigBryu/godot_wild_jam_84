# 🎨 How to Set Up Folder Colors in Godot

## Setting Folder Colors in Godot

Folder colors in Godot are set manually through the FileSystem dock. Here's how:

### Method 1: Right-Click Menu (Easiest)
1. In the **FileSystem** dock (usually on the left)
2. **Right-click** on any folder
3. Select **Change Folder Color** from the context menu
4. Pick a color from the palette

### Method 2: Folder Settings
1. Select a folder in the FileSystem dock
2. Look for the **folder color icon** in the FileSystem toolbar
3. Click it to open the color picker

## Recommended Color Scheme

### 🩷 PINK - All Art Folders
Set these to PINK:
- `entities/player/art/`
- `entities/organisms/critters/crab/art/`
- `entities/organisms/critters/starfish/art/`
- `entities/organisms/critters/jelly_fish/art/`
- `stages/beach/art/`
- `entities/ui/menu/art/`
- `entities/ui/hud/art/`

### ⚫ GRAY - All Sound Folders
Set these to GRAY:
- `entities/player/sound/`
- `entities/organisms/critters/starfish/sound/`
- `stages/beach/sounds/`

### 🔴 RED - All Shader Folders
Set these to RED:
- `common/shaders/`
- `stages/beach/shaders/`

### 🟦 CYAN - All Data Folders
Set these to CYAN:
- `entities/player/data/`
- `entities/organisms/critters/starfish/data/`

### Unique Colors for Each Organism
- `entities/organisms/critters/crab/` → ORANGE
- `entities/organisms/critters/starfish/` → BLUE
- `entities/organisms/critters/jelly_fish/` → GREEN

### Top Level Folders
- `assets/` → BLUE
- `common/` → PURPLE
- `config/` → GRAY
- `entities/` → GREEN
- `stages/` → YELLOW
- `utilities/` → ORANGE

## Quick Setup Script

Unfortunately, Godot doesn't support automatic folder coloring through config files. The `.godot/folder_colors.cfg` file I created won't work.

### But here's a faster way:

1. **Color all art folders at once:**
   - Search for "art" in FileSystem search
   - Select all art folders (Ctrl/Cmd + Click)
   - Right-click → Change Folder Color → Pink

2. **Color all sound folders at once:**
   - Search for "sound" in FileSystem search
   - Select all → Right-click → Gray

3. **Color all shader folders:**
   - Search for "shader" in FileSystem search
   - Select all → Right-click → Red

## Alternative: Project Organizer Plugin

Consider installing the "Project Organizer" plugin from the Asset Library which can:
- Auto-color folders based on naming patterns
- Save and load color schemes
- Apply colors to multiple folders at once

## The Colors Are Saved!

Once you set colors manually, Godot saves them in:
- `.godot/editor/filesystem_cache8` (binary format)
- These persist across sessions
- They're project-specific

## Why Manual?

Godot's folder colors are part of the editor state, not project configuration. This ensures:
- Each developer can have their own color preferences
- Colors don't conflict across teams
- Editor performance isn't impacted by color rules