# Localization

## Purpose
Multi-language support for all game text and localized content.

## Structure

### Language Folders
- `en/` - English (default)
- `es/` - Spanish
- `fr/` - French
- Add more as needed: `de/`, `ja/`, `pt/`, etc.

## File Types

### translations.csv
Main translation file with all game text
```csv
KEY,en,es,fr
MENU_PLAY,Play,Jugar,Jouer
MENU_SETTINGS,Settings,Configuración,Paramètres
CRITTER_STARFISH,Starfish,Estrella de mar,Étoile de mer
```

### dialogue/
Character dialogue and story text
- `npc_dialogue.json`
- `tutorial_text.json`
- `story_sequences.json`

### ui_text/
UI-specific translations
- `menu_text.csv`
- `hud_text.csv`
- `notification_text.csv`

## Usage
```gdscript
# Set language
TranslationServer.set_locale("es")

# In scenes/scripts
text = tr("MENU_PLAY")  # Returns "Jugar" if Spanish is active

# With parameters
text = tr("SCORE_TEXT").format({"score": 100})
```

## Guidelines
1. Use CAPS_SNAKE_CASE for keys
2. Keep keys descriptive but concise
3. Group related translations
4. Test all languages for text overflow
5. Consider cultural context, not just translation

## Adding New Language
1. Create folder: `localization/xx/`
2. Add column to translations.csv
3. Translate all content
4. Add to project settings
5. Test thoroughly