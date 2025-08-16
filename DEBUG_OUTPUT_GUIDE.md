# Wave Physics Debug Output Guide

## 🔍 Debug Output Enabled

With `debug_draw = true` on WaveArea, you'll see the following console output to help identify position issues:

## 📊 Console Output Types

### 1. **Wave Entry/Exit Events**
```
🌊 PLAYER ENTERED WAVE - Phase: surging
   Entry Position: (640, 400)
   Wave Edge Y: 380
   Wave Bottom Y: 420

🌊 PLAYER EXITED WAVE
   Exit Position: (640, 370)
```

### 2. **Force Application** (prints continuously while in wave)
```
PLAYER POS BEFORE: (640, 400) | Phase: surging | Force: (0, -3)
PLAYER VEL AFTER: (0, -3) (was: (0, 0))
```

### 3. **Position Jump Detection** (⚠️ alerts for teleportation)
```
⚠️ POSITION JUMP DETECTED!
   From: (640, 400)
   To: (640, 300)
   Distance: 100
   Wave Phase: surging
```

### 4. **Collision Shape Changes** (detects wave area updates)
```
📐 COLLISION SHAPE CHANGE:
   Size: (1920, 50) -> (1920, 150) (delta: 100)
   Pos: (960, 400) -> (960, 350) (delta: 50)
```

### 5. **Force/Velocity Warnings** (safety checks)
```
⚠️ EXTREME FORCE DETECTED: (0, -5000) - CAPPING!
⚠️ VELOCITY TOO HIGH: 750 - CAPPING!
⚠️ Resetting WaveArea global_position from (100, 0) to (0, 0)
```

## 🎯 What to Look For

### **Teleportation Bug Signs:**
- Position jumps > 50 pixels between frames
- WaveArea global_position being reset frequently
- Multiple enter/exit events in quick succession
- Collision shape dramatic size changes

### **Force Issues:**
- Forces being applied during "pausing" phase (shouldn't happen)
- Extreme force values (> 1000)
- Velocity growing unchecked (> 500)
- Wrong force direction for phase

### **Expected Behavior:**
- **Surging**: Negative Y force (upward), position gradually decreasing
- **Retreating**: Positive Y force (downward), position gradually increasing
- **Pausing**: NO forces, position stable
- **Calm**: NO forces, no wave collision

## 🔧 Debugging Steps

1. **Run the game** with debug output enabled
2. **Stand at shore** and let wave hit you
3. **Watch console** for any ⚠️ warnings
4. **Note the phase** when issues occur
5. **Check position values** for sudden jumps

## 📝 Common Issues & Solutions

| Issue | Console Pattern | Likely Cause |
|-------|----------------|--------------|
| Teleportation | POSITION JUMP > 50px | Collision shape update or global_position reset |
| Stuck in place | No force prints | Not detecting player in wave |
| Flying away | VELOCITY TOO HIGH | Forces too strong or accumulating |
| Jittery movement | Rapid enter/exit | Collision detection flickering |

## 🚫 To Disable Debug Output

Set `debug_draw = false` on the WaveArea node in BeachMinimal.tscn once issues are resolved.