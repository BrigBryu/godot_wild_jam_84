# Common

## Purpose
Standalone, reusable components that can be shared across multiple projects. These components must have NO dependencies on Beach Critters specific code.

## Structure

### debug/
Debug tools and development utilities
- Debug camera system
- Performance monitors
- Visual debugging tools
- Console commands

### state_machine/
Generic finite state machine implementation
- BaseState.gd - Abstract state class
- StateMachine.gd - State manager
- Reusable across any entity needing states

### shaders/
Visual effects and shader programs
- Outline shaders
- Water effects
- Screen effects
- Must be generic and parameterizable

## Rules
1. **No Project Dependencies**: Cannot reference Beach Critters specific code
2. **Self-Contained**: Must work independently
3. **Well-Documented**: Include usage examples
4. **Generic Parameters**: Use exports and configuration

## Usage Example
```gdscript
# Using the state machine
extends StateMachine

func _ready():
    add_state("idle", IdleState.new())
    add_state("moving", MoveState.new())
    set_initial_state("idle")
```