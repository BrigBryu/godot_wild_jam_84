class_name BaseCritter
extends Area2D

# Base class for all collectible critters

@export var critter_type: String = "generic"
@export var collection_value: int = 10
@export var rarity: String = "common" # common, uncommon, rare, legendary
@export var scientific_name: String = ""
@export var description: String = ""
@export var organism_name: String = "Unknown Critter"

var is_highlighted: bool = false
var health: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("critters")
	
	# Set up collision layers for Area2D
	# Put on interactables layer for detection only (no physical collision)
	set_collision_layer_value(5, true)  # Interactables layer for detection
	set_collision_mask_value(1, false)  # Don't detect player (player detects us)
	
	# Area2D doesn't block movement - perfect for collectible items

func set_highlighted(highlighted: bool):
	is_highlighted = highlighted
	
	if not sprite:
		return
	
	if highlighted:
		# Apply white outline shader
		var shader = load("res://common/shaders/outline.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))  # Pure white
			material.set_shader_parameter("outline_width", 2.0)
			material.set_shader_parameter("show_outline", true)
			sprite.material = material
	else:
		# Remove highlight
		sprite.material = null

func collect():
	# Note: The actual SignalBus emission is handled by the PlayerController
	# This function just handles the visual collection animation
	
	# Play collection animation
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func _on_interact():
	collect()

func _get_interaction_prompt() -> String:
	return "Press E to collect " + organism_name

func get_info() -> Dictionary:
	return {
		"name": organism_name,
		"scientific_name": scientific_name,
		"type": critter_type,
		"rarity": rarity,
		"value": collection_value,
		"description": description
	}