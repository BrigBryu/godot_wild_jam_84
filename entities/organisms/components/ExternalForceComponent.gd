class_name ExternalForceComponent
extends Node

## Simple component to handle wave forces for both player and organisms

enum ForceMode {
	CONSTANT,    # Force applied every frame
	IMPULSE     # One-time force application
}

# Force storage
var active_forces: Dictionary = {}
var physics_body: Node = null

# Properties
@export var max_velocity: float = 1000.0
@export var mass: float = 1.0

func _ready() -> void:
	# Auto-detect physics body (RigidBody2D or CharacterBody2D)
	if not physics_body:
		physics_body = get_parent()

func set_physics_body(body: Node) -> void:
	physics_body = body

func add_force(force: Vector2, source: String = "unknown", mode: ForceMode = ForceMode.CONSTANT) -> void:
	"""Add or update a force from a specific source"""
	active_forces[source] = {
		"force": force,
		"mode": mode
	}

func clear_forces(source: String = "") -> void:
	"""Clear forces from specific source or all forces"""
	if source.is_empty():
		active_forces.clear()
	else:
		active_forces.erase(source)

func get_accumulated_force(source: String = "") -> Vector2:
	"""Get total force from specific source or all sources"""
	if not source.is_empty():
		if active_forces.has(source):
			return active_forces[source]["force"]
		return Vector2.ZERO
	
	var total_force = Vector2.ZERO
	for force_data in active_forces.values():
		total_force += force_data["force"]
	return total_force

func activate() -> void:
	"""Activate the component"""
	pass  # Simple version doesn't need complex activation
