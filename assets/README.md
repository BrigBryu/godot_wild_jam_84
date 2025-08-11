# Assets

## Purpose
Global game resources that are used throughout the entire game. Only put assets here that are needed across multiple systems or stages.

## Structure

### audio/
Global sound effects and background music
- background_music.ogg
- ui_sounds.ogg
- ambient_sounds.ogg

### credits/
Credit information and developer assets
- team_info.json
- contributor_list.txt
- license_info.md

### fonts/
Game fonts used across the UI
- main_font.ttf
- ui_font.ttf
- title_font.ttf

## Guidelines

### What Goes Here
- Fonts used in multiple UI screens
- Background music tracks
- Global UI sound effects
- Credit and attribution files
- Universal icons and symbols

### What Doesn't Go Here
- Entity-specific sprites (goes in entities/*/art/)
- Stage-specific tiles (goes in stages/tilesets/)
- Entity-specific sounds (goes in entities/*/sound/)
- Temporary or test assets

## Asset Naming
- Use snake_case for all asset files
- Include the asset type in the name when helpful
- Be descriptive but concise

Examples:
- `menu_background_music.ogg`
- `button_hover_sound.wav`
- `main_ui_font.ttf`