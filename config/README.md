# Config

## Purpose
Centralized game configuration and settings management. All user-adjustable settings and game configuration files.

## Structure

### settings/
User preferences and game settings
- GameSettings.gd - Main settings manager
- UserPreferences.tres - Saved user preferences
- DefaultSettings.tres - Default configuration

### audio/
Audio configuration and bus management
- AudioBusLayout.tres - Audio bus configuration
- VolumeSettings.gd - Volume control manager
- SoundCategories.tres - Sound effect categories

### graphics/
Visual and display settings
- GraphicsSettings.gd - Graphics quality manager
- ResolutionManager.gd - Screen resolution handling
- QualityPresets.tres - Predefined quality levels

## Usage
Settings should be accessed through a singleton:
```gdscript
# In autoload
ConfigManager.get_setting("master_volume")
ConfigManager.set_setting("resolution", Vector2(1920, 1080))
ConfigManager.save_settings()
```

## File Types
- `.gd` - Setting managers and controllers
- `.tres` - Resource files for saved configurations
- `.cfg` - Configuration text files