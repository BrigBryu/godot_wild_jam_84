class_name SimpleOrganism
extends RigidBody2D

## Simple, clean organism base class
## Visuals, scaling, and collision shapes are set up in the scene files
## Override _configure() in child classes to set organism properties

# Basic organism properties
@export var organism_name: String = "Unknown Organism"
@export var points_value: int = 10

# Wave physics properties
@export var wave_influence: float = 1.0
@export var mass_override: float = 0.5

# Nodes - clean structure
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_collision: CollisionShape2D = $InteractionArea/InteractionCollision

func _ready() -> void:
	# Physics setup
	setup_physics()
	
	# Let child classes configure themselves
	_configure()
	
	# Apply configuration
	apply_configuration()
	
	# Set up interaction area for player detection
	setup_interaction_area()
	
	# Add to organisms group for wave detection
	add_to_group("organisms")

func _configure() -> void:
	"""Override this in child classes to set organism properties"""
	pass

func setup_physics() -> void:
	"""Configure RigidBody2D physics properties"""
	gravity_scale = 0.0
	linear_damp = 0.8
	angular_damp = 2.0
	mass = mass_override
	continuous_cd = CCD_MODE_CAST_RAY
	
	# Collision layers: organisms don't collide with player
	collision_layer = 0
	set_collision_layer_value(6, true)  # Organisms layer
	collision_mask = 0
	set_collision_mask_value(2, true)   # World collision only

func setup_interaction_area() -> void:
	"""Setup Area2D for player interaction detection"""
	if interaction_area:
		# Area2D is for interaction detection only, not physics
		interaction_area.collision_layer = 0
		interaction_area.collision_mask = 0
		interaction_area.set_collision_layer_value(5, true)   # Organisms interaction layer (2^4 = 16)
		interaction_area.monitoring = false  # Organisms don't monitor, player monitors them
		interaction_area.monitorable = true  # Organisms can be detected by player
		
		# Connect interaction area to this organism's group
		interaction_area.add_to_group("organisms")
		
		print("🔧 %s InteractionArea: Layer=%d, Monitoring=%s, Monitorable=%s" % [
			organism_name, 
			interaction_area.collision_layer,
			interaction_area.monitoring,
			interaction_area.monitorable
		])

func apply_configuration() -> void:
	"""Apply all configuration after _configure() runs"""
	# Simple debug info
	print("🐚 %s created: Points=%d, Mass=%.1f, Wave influence=%.1f" % [organism_name, points_value, mass, wave_influence])

func collect() -> void:
	"""Handle organism collection by player with animation"""
	SignalBus.critter_collected.emit(organism_name, points_value)
	
	# Play collection animation
	play_collection_animation()

func play_collection_animation() -> void:
	"""Animate the organism when collected"""
	if not sprite:
		queue_free()
		return
	
	# Create tween for collection animation
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations simultaneously
	
	# Scale up and fade out animation
	tween.tween_property(sprite, "scale", sprite.scale * 1.5, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	
	# Slight rotation for visual flair
	tween.tween_property(sprite, "rotation", sprite.rotation + PI * 0.5, 0.3)
	
	# Remove the organism after animation
	tween.tween_callback(queue_free).set_delay(0.3)

func set_highlighted(highlighted: bool) -> void:
	"""Handle highlighting for player interaction using outline shader"""
	if sprite and sprite.material:
		# Use outline shader to show/hide white outline
		sprite.material.set_shader_parameter("show_outline", highlighted)
	elif sprite and highlighted:
		# Create outline shader material if it doesn't exist
		var outline_shader = preload("res://common/shaders/outline.gdshader")
		var shader_material = ShaderMaterial.new()
		shader_material.shader = outline_shader
		shader_material.set_shader_parameter("outline_color", Color.WHITE)
		shader_material.set_shader_parameter("outline_width", 3.0)  # Bigger outline
		shader_material.set_shader_parameter("glow_intensity", 0.03)  # 3% glow tint
		shader_material.set_shader_parameter("show_outline", true)
		sprite.material = shader_material
	elif sprite and not highlighted:
		# Remove shader when not highlighted
		if sprite.material:
			sprite.material.set_shader_parameter("show_outline", false)

func _physics_process(delta: float) -> void:
	"""Apply wave forces if in wave area"""
	# Simple wave force application - no components needed
	if has_method("get_wave_force"):
		var wave_force = get_wave_force() * wave_influence
		if wave_force != Vector2.ZERO:
			apply_central_force(wave_force)

# Wave detection - simple approach
func _on_wave_entered(wave_force: Vector2) -> void:
	"""Called when organism enters wave area"""
	pass

func _on_wave_exited() -> void:
	"""Called when organism exits wave area"""
	pass

# Simple wave force storage for physics process
var current_wave_force: Vector2 = Vector2.ZERO

func apply_wave_force(force: Vector2) -> void:
	"""External wave system calls this to apply forces"""
	current_wave_force = force * wave_influence

func get_wave_force() -> Vector2:
	"""Get current wave force for physics process"""
	return current_wave_force

# Optional: Add ExternalForceComponent support for compatibility with player system
func get_force_component() -> ExternalForceComponent:
	"""Return null - SimpleOrganism uses direct wave forces, not components"""
	return null
