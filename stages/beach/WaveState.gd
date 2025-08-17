class_name WaveState
extends Resource

## Single source of truth for wave state
## Manages all wave properties and emits changes

# Wave position and bounds
@export var edge_y: float = 420.0
@export var bottom_y: float = 420.0
@export var bounds: Rect2 = Rect2()

# Wave physics
@export var velocity: Vector2 = Vector2.ZERO
@export var phase: String = "calm"
@export var phase_progress: float = 0.0

# Wave force properties (pixels/second) - Not used anymore, forces are hardcoded in WaveArea
@export var surge_force: float = 300.0  # Force pushing up the beach during surge
@export var retreat_force: float = 250.0  # Force pulling toward ocean during retreat

# Visual properties
@export var alpha: float = 0.15
@export var foam_alpha: float = 0.15
@export var height: float = 100.0

# Configuration
@export var shore_y: float = 420.0
@export var surge_height: float = 120.0

# Signals for state changes
signal phase_changed(new_phase: String)
signal bounds_changed(new_bounds: Rect2)
signal position_changed(edge_y: float, bottom_y: float)

func update_bounds(viewport_width: float) -> void:
	"""Update wave collision bounds based on current position"""
	var top = edge_y
	var bottom = bottom_y
	var height = bottom - top
	
	if height > 0:
		bounds = Rect2(0, top, viewport_width, height)
		bounds_changed.emit(bounds)

func set_phase(new_phase: String) -> void:
	"""Change wave phase and emit signal"""
	if phase != new_phase:
		phase = new_phase
		phase_progress = 0.0
		phase_changed.emit(new_phase)

func update_position(new_edge_y: float, new_bottom_y: float) -> void:
	"""Update wave position and emit signal"""
	if edge_y != new_edge_y or bottom_y != new_bottom_y:
		edge_y = new_edge_y
		bottom_y = new_bottom_y
		position_changed.emit(edge_y, bottom_y)

func is_position_in_wave(test_position: Vector2) -> bool:
	"""Check if a position is within the wave bounds"""
	return test_position.y > edge_y and test_position.y < bottom_y

func get_surge_distance() -> float:
	"""Get how many pixels the wave has surged up the beach"""
	if edge_y >= shore_y:
		return 0.0
	return shore_y - edge_y  # Positive number = pixels up the beach