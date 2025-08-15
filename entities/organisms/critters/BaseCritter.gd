class_name BaseCritter
extends Area2D

# Base class for all collectible critters
# Uses Area2D for interaction detection with RigidBody2D child for physics

@export var critter_type: String = "generic"
@export var collection_value: int = 10
@export var rarity: String = "common" # common, uncommon, rare, legendary
@export var scientific_name: String = ""
@export var description: String = ""
@export var organism_name: String = "Unknown Critter"

# Spawning properties - each critter manages its own
@export_group("Spawning Properties")
@export var spawn_scale: float = 1.0  # Scale when spawned (1.0 = original size)
@export var spawn_weight: float = 1.0  # Weight for random selection (higher = more likely)
@export var spawn_transparency: float = 0.0  # Initial transparency (0.0 = invisible, 1.0 = opaque)

var is_highlighted: bool = false
var health: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var physics_body: RigidBody2D = $PhysicsBody  # Child RigidBody2D for wave physics
@onready var interaction_shape: CollisionShape2D = $InteractionCollision  # Large area for collection
@onready var collision_shape: CollisionShape2D = $PhysicsBody/PhysicsCollision  # Small shape for physics

func _ready():
	add_to_group("critters")
	
	# Set up Area2D for interaction detection
	set_collision_layer_value(5, true)   # Critters interaction layer
	set_collision_mask_value(1, false)   # Don't mask anything (we're just for detection)
	
	# Set up physics body if it exists
	if physics_body:
		physics_body.set_collision_layer_value(6, true)  # Physics critters layer
		physics_body.set_collision_mask_value(1, true)   # Collide with world
		physics_body.set_collision_mask_value(10, true)  # Interact with waves
		
		# Configure physics properties
		physics_body.gravity_scale = 0.1
		physics_body.linear_damp = 2.0
		physics_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

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

func setup_for_spawning():
	"""Configure critter for spawning (called by spawner)"""
	# Apply spawn scale
	print("Setting up ", organism_name, " with spawn_scale: ", spawn_scale)
	scale = Vector2(spawn_scale, spawn_scale)
	print("Applied scale: ", scale)
	
	# Critters are now permanently visible (transparency handled by spawner)

func get_spawn_weight() -> float:
	"""Get this critter's spawn weight"""
	return spawn_weight

func apply_wave_force(force: Vector2):
	"""Apply wave forces (push/pull effects) to physics body"""
	if not physics_body:
		return
		
	if physics_body.freeze_mode == RigidBody2D.FREEZE_MODE_KINEMATIC:
		# Temporarily unfreeze to allow wave interaction
		physics_body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	
	# Apply the force to physics body
	physics_body.apply_central_force(force)
	
	# Re-freeze after a short delay to prevent excessive movement
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_refreeze_critter)

func _refreeze_critter():
	"""Re-freeze the critter after wave interaction"""
	if physics_body:
		physics_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

func get_info() -> Dictionary:
	return {
		"name": organism_name,
		"scientific_name": scientific_name,
		"type": critter_type,
		"rarity": rarity,
		"value": collection_value,
		"description": description
	}