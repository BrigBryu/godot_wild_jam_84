# 🎨 Folder Color Guide

## Core Principle: No Same-Color Siblings!
Every folder at the same level has a DIFFERENT color for instant visual distinction.

## Consistent Folder Types (Same Color Everywhere)

### 🩷 **PINK** - All Art Folders
- Every `art/` folder is PINK no matter where it lives
- Easy to spot visual assets instantly

### ⚫ **GRAY** - All Sound Folders  
- Every `sounds/` folder is GRAY everywhere
- Audio files always easy to find

### 🔴 **RED** - All Shader Folders
- Every `shaders/` folder is RED
- Visual effects stand out

### 🟦 **TEAL** - All Data/Config Folders
- Every `data/` or config folder is TEAL
- Configuration files grouped visually

## Visual Navigation Examples

### When you open root:
```
📁 assets/        🔵 BLUE
📁 common/        🟣 PURPLE  
📁 config/        ⚫ GRAY
📁 entities/      🟢 GREEN
📁 stages/        🟡 YELLOW
📁 utilities/     🟠 ORANGE
```
**Result:** Every folder is different - instant recognition!

### When you open entities/:
```
📁 organisms/     🟡 YELLOW
📁 player/        🟣 PURPLE
📁 ui/            🟠 ORANGE
📁 weather/       🔵 BLUE
```
**Result:** All different colors - no confusion!

### When you open entities/organisms/critters/:
```
📁 crab/          🟠 ORANGE
📁 starfish/      🔵 BLUE
📁 shell/         🟢 GREEN
📁 seaweed/       🟣 PURPLE
📁 urchin/        🟡 YELLOW
```
**Result:** Each organism has its OWN color - easy to find!

### When you open any organism (e.g., crab/):
```
📁 art/           🩷 PINK (always pink!)
📁 sounds/        ⚫ GRAY (always gray!)
📁 data/          🟦 TEAL (always teal!)
📁 animations/    🟢 GREEN
📄 Crab.gd
📄 crab.tscn
```
**Result:** Consistent special folders, unique colors for others!

### When you open utilities/:
```
📁 managers/      🔵 BLUE
📁 signals/       🟢 GREEN
📁 spawning/      🟣 PURPLE
📁 helpers/       🟡 YELLOW
📁 debug/         🔴 RED
```
**Result:** Each system type has its own color!

## Quick Reference

### Finding Things:
- **Need art?** → Look for 🩷 PINK folders
- **Need sounds?** → Look for ⚫ GRAY folders
- **Need shaders?** → Look for 🔴 RED folders
- **Need config?** → Look for 🟦 TEAL folders
- **Need a specific organism?** → Each has unique color:
  - Crab → 🟠 ORANGE
  - Starfish → 🔵 BLUE
  - Shell → 🟢 GREEN
  - Seaweed → 🟣 PURPLE
  - Urchin → 🟡 YELLOW

## Benefits

✅ **No Confusion:** Sibling folders never share colors
✅ **Consistent Types:** Art/Sound/Shaders/Data always same color
✅ **Quick Scanning:** Different colors = different purposes
✅ **Easy Navigation:** Unique organism colors make finding creatures instant
✅ **Visual Hierarchy:** Color differences show folder relationships

## Adding New Content

When adding new folders:
1. **Check siblings** - Make sure your new folder has a different color than its siblings
2. **Follow conventions** - Art → Pink, Sounds → Gray, Shaders → Red, Data → Teal
3. **Unique organisms** - Give each new creature its own color