class_name BaseOrganism
extends Area2D

# Base class for ALL organisms in the game (crabs, starfish, etc.)
# Easy to extend - just override the organism-specific properties!

# === ORGANISM IDENTITY ===
@export_group("Identity")
@export var organism_name: String = "Unknown Organism"
@export var organism_type: String = "generic"  # crab, starfish, shell, etc.
@export var scientific_name: String = ""
@export var description: String = ""

# === GAMEPLAY VALUES ===
@export_group("Gameplay")
@export var collection_value: int = 10  # Points when collected
@export var rarity: String = "common"  # common, uncommon, rare, legendary

# === SPAWNING PROPERTIES ===
@export_group("Spawning")
@export var spawn_scale: float = 0.05  # Default 5% of original size
@export var spawn_weight: float = 1.0  # Higher = more likely to spawn

# === VISUAL CUSTOMIZATION ===
@export_group("Visuals")
@export var sprite_texture: Texture2D  # The organism's sprite/art
@export var sprite_color: Color = Color.WHITE  # Tint color
@export var collision_shape_radius: float = 10.0  # Collection area size

# === STATE ===
var is_highlighted: bool = false
var outline_shader: Shader = null

# === CACHED NODES ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var physics_body: Node2D = $PhysicsBody  # For wave physics (can be RigidBody2D or CharacterBody2D)
@onready var interaction_shape: CollisionShape2D = $InteractionCollision  # Large area for collection
@onready var collision_shape: CollisionShape2D = $PhysicsBody/PhysicsCollision  # Small shape for physics

func _ready():
	add_to_group("organisms")
	
	# Load outline shader once
	outline_shader = load("res://common/shaders/outline.gdshader")
	
	# Apply visual customization
	if sprite and sprite_texture:
		sprite.texture = sprite_texture
		sprite.modulate = sprite_color
	
	# Set up collision shapes
	if interaction_shape and interaction_shape.shape is CircleShape2D:
		interaction_shape.shape.radius = collision_shape_radius
	
	# Set up Area2D for interaction detection
	set_collision_layer_value(5, true)   # Organisms interaction layer
	set_collision_mask_value(1, false)   # Don't mask anything (we're just for detection)
	
	# Set up physics body if it exists
	if physics_body:
		physics_body.set_collision_layer_value(6, true)  # Physics organisms layer
		physics_body.set_collision_mask_value(1, true)   # Collide with world
		# physics_body.set_collision_mask_value(10, true)  # Wave interaction disabled for rework
		
		# Configure physics properties for RigidBody2D
		if physics_body is RigidBody2D:
			physics_body.gravity_scale = 0.1
			physics_body.linear_damp = 2.0
			physics_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	# Let child classes do their setup
	_organism_ready()

# === OVERRIDE THIS IN CHILD CLASSES ===
func _organism_ready():
	"""Override this to set organism-specific properties"""
	return

# === HIGHLIGHTING ===
func set_highlighted(highlight: bool):
	is_highlighted = highlight
	
	if not sprite:
		return
	
	if highlight:
		# Apply white outline shader
		if outline_shader:
			var material = ShaderMaterial.new()
			material.shader = outline_shader
			material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))  # Pure white
			material.set_shader_parameter("outline_width", 2.0)
			material.set_shader_parameter("show_outline", true)
			sprite.material = material
			
			# Emit highlight signal through SignalBus
			SignalBus.critter_highlighted.emit(self)
	else:
		# Remove highlight
		sprite.material = null
		# Emit unhighlight signal through SignalBus
		SignalBus.critter_unhighlighted.emit(self)

# === COLLECTION ===
func collect():
	"""Called when organism is collected by player"""
	# Get organism info for the signal
	var info = get_info()
	
	# Emit collection through SignalBus with all the data
	SignalBus.collect_critter(
		info.type,
		info.name,
		info.value,
		global_position
	)
	
	# Also emit the raw critter_collected signal for other systems
	SignalBus.critter_collected.emit(info)
	
	# Play collection animation
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

# === INTERACTION ===
func _on_interact():
	"""Called when player interacts with this organism"""
	collect()

func _get_interaction_prompt() -> String:
	"""Get the prompt text for interaction"""
	return "Press E to collect " + organism_name

# === SPAWNING ===
func setup_for_spawning():
	"""Configure organism for spawning (called by spawner)"""
	scale = Vector2(spawn_scale, spawn_scale)

func get_spawn_weight() -> float:
	"""Get this organism's spawn weight for random selection"""
	return spawn_weight

# === WAVE PHYSICS ===
func apply_wave_force(force: Vector2):
	"""Apply wave forces (push/pull effects) to physics body"""
	if not physics_body:
		return
		
	# Only apply forces if the organism is visible and active
	if not visible:
		return
		
	# For RigidBody2D, apply force directly
	if physics_body is RigidBody2D:
		# Temporarily unfreeze if frozen
		var was_frozen = physics_body.freeze
		if was_frozen:
			physics_body.freeze = false
		
		# Apply force scaled by organism size (smaller organisms affected more)
		var size_factor = 2.0 - clamp(spawn_scale, 0.5, 1.5)  # 0.5 to 1.5 scale factor
		physics_body.apply_central_force(force * size_factor * 100.0)  # Scale up force for physics
		
		# Re-freeze after a short delay if it was frozen
		if was_frozen:
			var timer = get_tree().create_timer(0.2)
			timer.timeout.connect(func(): 
				if physics_body:
					physics_body.freeze = true
			)
	
	# For CharacterBody2D (if any organisms use it)
	elif physics_body is CharacterBody2D:
		physics_body.velocity += force
		
func on_entered_wave():
	"""Called when organism enters wave area"""
	# Could add visual effects or state changes here
	pass
	
func on_exited_wave():
	"""Called when organism exits wave area"""
	# Could add visual effects or state changes here
	pass

# === DATA ACCESS ===
func get_info() -> Dictionary:
	"""Get all organism information as a dictionary"""
	return {
		"name": organism_name,
		"scientific_name": scientific_name,
		"type": organism_type,
		"rarity": rarity,
		"value": collection_value,
		"description": description
	}
