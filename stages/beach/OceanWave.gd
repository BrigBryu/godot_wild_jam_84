extends RigidBody2D
class_name OceanWave

# Wave physics properties
@export var wave_height: float = 100.0
@export var initial_speed: float = 200.0  # pixels per second
@export var shore_y: float = 420.0
@export var max_surge_height: float = 120.0

# Wave state
var is_traveling: bool = true
var has_hit_shore: bool = false
var surge_target_y: float = 0.0
var wave_body: CollisionShape2D

# Signals for integration with main beach system
signal wave_hit_shore(wave_speed: float, wave_height: float)
signal wave_retreating
signal wave_complete

# Shore collision detection
var shore_detector: Area2D

func _ready():
	# Setup physics body for the wave
	_setup_wave_physics()
	_setup_shore_detection()
	
	# Start moving toward shore
	linear_velocity = Vector2(0, -initial_speed)  # Move upward toward shore
	
	# Calculate surge target based on initial speed (realistic wave physics)
	surge_target_y = shore_y - (max_surge_height * sqrt(initial_speed / 200.0))

func _setup_wave_physics():
	# Create collision shape for the wave body
	wave_body = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	# Use fixed viewport size since get_viewport() might not be available yet
	rect_shape.size = Vector2(1280, wave_height)  # Full width, wave height
	wave_body.shape = rect_shape
	add_child(wave_body)
	
	# Physics settings for realistic wave behavior
	mass = 10.0
	gravity_scale = 0.0  # Waves aren't affected by gravity the same way
	linear_damp = 0.1  # Slight water resistance
	angular_damp = 5.0  # Prevent rotation
	
	print("Physics wave body created with size: ", rect_shape.size)

func _setup_shore_detection():
	# Create area to detect when wave reaches shore
	shore_detector = Area2D.new()
	var detector_shape = CollisionShape2D.new()
	var detector_rect = RectangleShape2D.new()
	detector_rect.size = Vector2(1280, 10)  # Thin detection line
	detector_shape.shape = detector_rect
	shore_detector.add_child(detector_shape)
	add_child(shore_detector)
	
	# Position detector at the front of the wave
	shore_detector.position = Vector2(0, -wave_height / 2)
	
	# Connect collision detection
	shore_detector.body_entered.connect(_on_shore_detected)
	
	print("Shore detector created at position: ", shore_detector.position)

func _physics_process(delta):
	# Debug output every few frames
	if Engine.get_process_frames() % 120 == 0:  # Every 2 seconds
		print("Wave position: ", global_position, ", velocity: ", linear_velocity, ", traveling: ", is_traveling, ", hit_shore: ", has_hit_shore)
	
	if is_traveling and not has_hit_shore:
		# Check if front edge has reached shore
		var front_edge_y = global_position.y - wave_height / 2
		if front_edge_y <= shore_y:
			print("Wave hit shore! Front edge at: ", front_edge_y, ", shore at: ", shore_y)
			_hit_shore()
	
	elif has_hit_shore and is_traveling:
		# Wave is slowing down and surging - use physics for natural deceleration
		_apply_shore_physics(delta)

func _hit_shore():
	has_hit_shore = true
	
	# Calculate final surge height based on impact speed
	var impact_speed = abs(linear_velocity.y)
	var computed_surge = max_surge_height * (impact_speed / initial_speed)
	surge_target_y = shore_y - computed_surge
	
	# Emit signal with wave characteristics
	wave_hit_shore.emit(impact_speed, wave_height)
	
	# Begin natural deceleration using physics
	linear_damp = 2.0  # Increase resistance as wave hits shallow water

func _apply_shore_physics(delta):
	# Natural wave physics when hitting shore
	var front_edge_y = global_position.y - wave_height / 2
	
	if front_edge_y > surge_target_y:
		# Still surging upward - apply upward force
		var surge_force = (surge_target_y - front_edge_y) * 500  # Proportional force
		apply_central_force(Vector2(0, surge_force))
	else:
		# Reached peak - begin retreat
		if is_traveling:
			_begin_retreat()

func _begin_retreat():
	is_traveling = false
	wave_retreating.emit()
	
	# Apply gentle retreat force
	linear_velocity = Vector2(0, 50)  # Slow retreat
	linear_damp = 0.5  # Less resistance during retreat

func _on_shore_detected(body):
	# Additional collision detection if needed
	pass

# Method to get current wave edge position (for shader integration)
func get_wave_edge_y() -> float:
	return global_position.y - wave_height / 2

func get_wave_bottom_y() -> float:
	return global_position.y + wave_height / 2

# Clean up when wave is complete
func cleanup():
	wave_complete.emit()
	queue_free()