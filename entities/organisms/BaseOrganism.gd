class_name BaseOrganism
extends Node2D

# Base class for all living organisms in the game

@export var health: int = 100
@export var max_health: int = 100
@export var movement_speed: float = 50.0
@export var organism_name: String = "Unknown"

signal health_changed(new_health: int)
signal died()

func _ready():
	add_to_group("organisms")

func take_damage(amount: int):
	health = max(0, health - amount)
	health_changed.emit(health)
	
	if health <= 0:
		die()

func heal(amount: int):
	health = min(max_health, health + amount)
	health_changed.emit(health)

func die():
	died.emit()
	queue_free()

# Virtual methods to be overridden
func _on_interact():
	pass

func _get_interaction_prompt() -> String:
	return ""