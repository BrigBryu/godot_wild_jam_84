# Fix for BaseOrganism Parser Error

## The Issue
Godot is showing: `Parser Error: Could not resolve class "BaseOrganism"`

This happens when Godot's class registration cache gets out of sync, especially after deleting files (like the removed BaseCritter.gd).

## Solutions (Try in Order)

### 1. Clear Godot's Cache (RECOMMENDED)
1. Close Godot completely
2. Delete the `.godot` folder in your project directory:
   ```bash
   rm -rf .godot
   ```
3. Reopen the project in Godot
4. Let it reimport all assets (this may take a moment)

### 2. Force Class Re-registration
1. In Godot, go to **Project → Reload Current Project**
2. Or use keyboard shortcut: `Ctrl+Shift+F5` (Windows/Linux) or `Cmd+Shift+F5` (Mac)

### 3. Manual Fix (If Above Doesn't Work)
1. Open `entities/organisms/BaseOrganism.gd`
2. Temporarily comment out the class_name line:
   ```gdscript
   #class_name BaseOrganism
   extends Area2D
   ```
3. Save the file
4. Uncomment the line:
   ```gdscript
   class_name BaseOrganism
   extends Area2D
   ```
5. Save again

### 4. Check for Orphaned References
Run this in your terminal to find any files still referencing the deleted BaseCritter:
```bash
grep -r "BaseCritter" . --include="*.gd" --include="*.tscn"
```

If any files are found, update them to use `BaseOrganism` instead.

## Verification
After fixing, verify by:
1. Opening `Crab.gd` and `Starfish.gd` - they should show no errors
2. Running the game - organisms should spawn and respond to waves

## Note on Debug Mode
I've enabled `debug_draw = true` on the WaveArea node in BeachMinimal.tscn. This will show:
- Wave collision boundaries (cyan rectangle)
- Wave phase indicators with colors
- Force vectors as red arrows on affected bodies

You can toggle this off later by setting `debug_draw = false` on the WaveArea node.