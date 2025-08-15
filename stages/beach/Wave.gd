extends CharacterBody2D

# Physics-based wave that can push and pull objects

# Wave state
enum WavePhase { TRAVELING, SURGING, RETREATING, CALM }
var current_phase: WavePhase = WavePhase.TRAVELING

# All wave properties computed at initialization
var wave_speed: float = 0.0
var surge_velocity: float = 0.0
var deceleration: float = 0.0
var shore_y: float = 0.0
var force_multiplier: float = 2.0
var retreat_bonus: float = 1.5

# Randomization parameters (set these before calling initialize_wave)
var speed_variation_range: Vector2 = Vector2(0.7, 1.5)  # Min/max speed multipliers

# Physics areas for push/pull effects
@onready var surge_area: Area2D = $SurgeArea
@onready var retreat_area: Area2D = $RetreatArea

func _ready():
	# Set up collision layers for wave physics
	set_collision_layer_value(10, true)  # Wave layer
	set_collision_mask_value(1, true)    # Collide with world
	set_collision_mask_value(5, true)    # Interact with critters
	
	# Configure physics areas if they exist
	if surge_area:
		surge_area.set_collision_layer_value(11, true)    # Surge effect layer
		surge_area.body_entered.connect(_on_surge_area_entered)
		surge_area.body_exited.connect(_on_surge_area_exited)
	
	if retreat_area:
		retreat_area.set_collision_layer_value(12, true)  # Retreat effect layer
		retreat_area.body_entered.connect(_on_retreat_area_entered)
		retreat_area.body_exited.connect(_on_retreat_area_exited)

func initialize_wave(base_speed: float, shore_position: float, start_y: float, randomize_speed: bool = true):
	"""Initialize all wave properties at spawn time - everything computed ONCE"""
	
	# Set shore position
	shore_y = shore_position
	
	# Compute wave speed (with optional randomization)
	if randomize_speed:
		var speed_multiplier = randf_range(speed_variation_range.x, speed_variation_range.y)
		wave_speed = base_speed * speed_multiplier
		print("Wave initialized with randomized speed: ", wave_speed, " (", speed_multiplier, "x base)")
	else:
		wave_speed = base_speed
		print("Wave initialized with base speed: ", wave_speed)
	
	# Pre-calculate ALL physics values
	surge_velocity = wave_speed * 1.5  # Surge velocity based on wave speed
	deceleration = wave_speed * 2.0    # Deceleration proportional to speed
	
	# Pre-calculate surge peak position using physics equation: v² = u² + 2as
	# At peak: final velocity = 0, initial velocity = surge_velocity, acceleration = deceleration
	# 0 = surge_velocity² - 2 * deceleration * distance
	# distance = surge_velocity² / (2 * deceleration)
	var surge_distance = (surge_velocity * surge_velocity) / (2.0 * deceleration)
	var surge_peak_y = shore_y - surge_distance
	
	# Set initial position
	global_position.y = start_y
	
	# Start traveling toward shore
	current_phase = WavePhase.TRAVELING
	velocity.y = -wave_speed
	
	# Notify CritterSpawner immediately with pre-calculated values
	_notify_critter_spawner_early(shore_y, surge_peak_y)
	
	print("Wave fully initialized - speed:", wave_speed, " surge_vel:", surge_velocity, " decel:", deceleration, " surge_peak:", surge_peak_y)

func _physics_process(delta):
	match current_phase:
		WavePhase.TRAVELING:
			_update_traveling(delta)
		WavePhase.SURGING:
			_update_surging(delta)
		WavePhase.RETREATING:
			_update_retreating(delta)
		WavePhase.CALM:
			_update_calm(delta)
	
	# Apply movement
	move_and_slide()

func _update_traveling(delta):
	# DEAD SIMPLE - just constant speed toward shore
	velocity.y = -wave_speed
	
	# Check if reached shore
	if global_position.y <= shore_y:
		global_position.y = shore_y  # Lock to shore position
		_start_surge()

func _update_surging(delta):
	# ONLY apply constant deceleration - nothing else
	velocity.y += deceleration * delta  # Positive deceleration reduces upward (negative) velocity
	
	# Stop when velocity reaches zero (natural physics stopping point)
	if velocity.y >= 0:
		velocity.y = 0
		_start_retreat()

func _update_retreating(delta):
	# Gravity pulls wave back down
	velocity.y += deceleration * delta * 1.5  # Faster retreat
	
	# Stop when back at shore
	if global_position.y >= shore_y:
		velocity.y = 0
		global_position.y = shore_y
		_start_calm()

func _update_calm(delta):
	# Wait period before next wave
	velocity = Vector2.ZERO

func _start_surge():
	current_phase = WavePhase.SURGING
	
	# Use pre-calculated surge velocity - NO computation during surge!
	velocity.y = -surge_velocity  # Negative because moving up
	
	print("Wave surging with pre-calculated velocity: ", surge_velocity)

func _start_retreat():
	current_phase = WavePhase.RETREATING
	print("Wave retreating from y=", global_position.y)

func _start_calm():
	current_phase = WavePhase.CALM
	print("Wave calm")

# Removed surge height calculation - not needed for simple physics

# Physics interaction methods
func _on_surge_area_entered(body):
	if body.has_method("apply_wave_force"):
		var push_force = _calculate_surge_force()
		body.apply_wave_force(Vector2(0, push_force))
	print("Object entered surge area: ", body.name, " force=", _calculate_surge_force())

func _on_surge_area_exited(body):
	if body.has_method("apply_wave_force"):
		body.apply_wave_force(Vector2.ZERO)
	print("Object exited surge area: ", body.name)

func _on_retreat_area_entered(body):
	if body.has_method("apply_wave_force"):
		var pull_force = _calculate_retreat_force()
		body.apply_wave_force(Vector2(0, pull_force))
	print("Object entered retreat area: ", body.name, " force=", pull_force)

func _on_retreat_area_exited(body):
	if body.has_method("apply_wave_force"):
		body.apply_wave_force(Vector2.ZERO)
	print("Object exited retreat area: ", body.name)

func _calculate_surge_force() -> float:
	"""Calculate push force based on pre-calculated surge velocity"""
	return -surge_velocity * force_multiplier  # Negative = up the beach

func _calculate_retreat_force() -> float:
	"""Calculate pull force back to ocean (stronger than push)"""
	var base_force = surge_velocity * force_multiplier
	return base_force * retreat_bonus  # Positive = toward ocean

# Public interface for spawning system
func get_wave_info() -> Dictionary:
	return {
		"phase": WavePhase.keys()[current_phase],
		"position": global_position,
		"velocity": velocity,
		"shore_y": shore_y
	}

func is_at_shore() -> bool:
	return current_phase == WavePhase.SURGING and global_position.y <= shore_y + 10.0

func _notify_critter_spawner_early(calculated_shore_y: float, calculated_surge_peak_y: float):
	"""Notify CritterSpawner to calculate debug zones early to prevent jerks"""
	var beach_scene = get_parent()
	if beach_scene and beach_scene.has_method("prepare_spawn_zones_early"):
		beach_scene.prepare_spawn_zones_early(calculated_shore_y, calculated_surge_peak_y)
	
	# Alternative: find CritterSpawner directly
	var critter_spawner = get_parent().get_node_or_null("CritterSpawner")
	if critter_spawner and critter_spawner.has_method("prepare_debug_zones_early"):
		critter_spawner.prepare_debug_zones_early(calculated_shore_y, calculated_surge_peak_y)