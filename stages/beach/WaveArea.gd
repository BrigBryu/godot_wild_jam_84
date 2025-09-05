class_name WaveArea
extends Area2D

## Simple wave collision area using standard Godot Area2D
## Eliminated ForceZone dependency - clean and focused

@export var wave_state: WaveState
@export var wave_debug_draw: bool = false
@export var debug_organisms: bool = true  # Debug organism wave interactions

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _bodies_in_wave: Array[Node2D] = []

# Debug tracking - intelligent rate limiting
var _debug_last_print_time: float = 0.0
var _debug_print_interval: float = 2.0  # Print every 2 seconds max
var _debug_organism_count: int = 0

func _ready() -> void:
	# Set up collision detection
	set_collision_layer_value(10, true)  # Wave layer
	set_collision_mask_value(1, true)    # Player
	set_collision_mask_value(6, true)    # Organisms
	
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up collision shape
	if collision_shape and not collision_shape.shape:
		var rect_shape = RectangleShape2D.new()
		# Wave area should cover full water zone: shore to ocean edge
		var wave_zone_height = GameConstants.OCEAN_EDGE_Y - GameConstants.SHORE_Y
		rect_shape.size = Vector2(GameConstants.SCREEN_WIDTH, wave_zone_height)
		collision_shape.shape = rect_shape

func _physics_process(_delta: float) -> void:
	if wave_state and _bodies_in_wave.size() > 0:
		_apply_wave_forces()

func _apply_wave_forces() -> void:
	var force = _get_wave_force()
	if force == Vector2.ZERO:
		return
		
	for body in _bodies_in_wave:
		if is_instance_valid(body):
			_apply_force_to_body(body, force)

func _get_wave_force() -> Vector2:
	match wave_state.phase:
		GameConstants.WavePhase.SURGING, GameConstants.WavePhase.TRAVELING:
			return Vector2.UP * abs(GameConstants.SURGE_FORCE)
		GameConstants.WavePhase.RETREATING:
			return Vector2.DOWN * abs(GameConstants.RETREAT_FORCE)
		_:
			return Vector2.ZERO

func _apply_force_to_body(body: Node2D, force: Vector2) -> void:
	"""Apply wave force to body through ExternalForceComponent or direct method"""
	var force_component = _get_force_component(body)
	if force_component:
		force_component.add_force(force, "wave", ExternalForceComponent.ForceMode.CONSTANT)
		# Debug for organisms with rate limiting
		if debug_organisms and body.is_in_group("organisms"):
			_debug_log_force_application(body, force, "ExternalForceComponent")
	elif body.has_method("apply_wave_force"):
		body.apply_wave_force(force)
		# Debug for organisms with rate limiting
		if debug_organisms and body.is_in_group("organisms"):
			_debug_log_force_application(body, force, "apply_wave_force")
	else:
		# Debug missing force handling
		if debug_organisms and body.is_in_group("organisms"):
			_debug_log("⚠️  ORGANISM NO FORCE HANDLING: %s (no ExternalForceComponent or apply_wave_force method)" % body.name)

func _get_force_component(body: Node2D) -> ExternalForceComponent:
	# If body is an organism or player, get its force component directly
	if body.has_method("get_force_component"):
		return body.get_force_component()
	
	# Fallback - look for component as child
	return body.get_node_or_null("ExternalForceComponent")


func _on_body_entered(body: Node2D) -> void:
	# Debug ALL body entries first
	if debug_organisms:
		_debug_log("🔍 BODY DETECTED: %s | Groups: %s | Layer: %d" % [
			body.name,
			str(body.get_groups()),
			body.collision_layer if "collision_layer" in body else -1
		])
	
	if not _is_wave_body(body):
		if debug_organisms:
			_debug_log("❌ BODY REJECTED: %s (not wave body)" % body.name)
		return
		
	_bodies_in_wave.append(body)
	_notify_body_entered(body)
	
	# Debug logging for organisms
	if debug_organisms and body.is_in_group("organisms"):
		_debug_organism_count += 1
		_debug_log("🌊 ORGANISM ENTERED WAVE: %s (Total: %d)" % [body.name, _debug_organism_count])
	
	if body.is_in_group("player"):
		SignalBus.player_entered_water.emit()

func _on_body_exited(body: Node2D) -> void:
	_bodies_in_wave.erase(body)
	
	# Clear wave forces
	var force_component = _get_force_component(body)
	if force_component:
		force_component.clear_forces("wave")
	elif body.has_method("apply_wave_force"):
		body.apply_wave_force(Vector2.ZERO)  # Clear the force
	
	# Debug logging for organisms
	if debug_organisms and body.is_in_group("organisms"):
		_debug_organism_count = max(0, _debug_organism_count - 1)
		_debug_log("🌊 ORGANISM EXITED WAVE: %s (Remaining: %d)" % [body.name, _debug_organism_count])
	
	_notify_body_exited(body)
	if body.is_in_group("player"):
		SignalBus.player_exited_water.emit()

func _is_wave_body(body: Node2D) -> bool:
	# Check if body is player or RigidBody2D organism
	return body.is_in_group("player") or body.is_in_group("organisms")

func _notify_body_entered(body: Node2D) -> void:
	if body.has_method("on_entered_wave"):
		body.on_entered_wave()
	var wave_detector = body.get_node_or_null("WaveDetector")
	if wave_detector and wave_detector.has_method("on_entered_wave"):
		wave_detector.on_entered_wave()

func _notify_body_exited(body: Node2D) -> void:
	if body.has_method("on_exited_wave"):
		body.on_exited_wave()
	var wave_detector = body.get_node_or_null("WaveDetector")
	if wave_detector and wave_detector.has_method("on_exited_wave"):
		wave_detector.on_exited_wave()

func update_collision_shape(bounds: Rect2) -> void:
	if not collision_shape or not collision_shape.shape:
		return
	var rect_shape = collision_shape.shape as RectangleShape2D
	if rect_shape:
		rect_shape.size = bounds.size
		collision_shape.position.y = bounds.position.y + bounds.size.y * 0.5

func get_affected_bodies() -> Array[Node2D]:
	return _bodies_in_wave

func is_body_in_wave_zone(body: Node2D) -> bool:
	return body in _bodies_in_wave

func _draw() -> void:
	if not wave_debug_draw or not wave_state or not collision_shape:
		return
	var rect_shape = collision_shape.shape as RectangleShape2D
	if rect_shape:
		var rect = Rect2(-rect_shape.size * 0.5, rect_shape.size)
		rect.position += collision_shape.position  
		draw_rect(rect, Color(0.2, 0.5, 1.0, 0.3))

# ============================================================================
# INTELLIGENT DEBUG SYSTEM - Rate Limited & Informative
# ============================================================================

func _debug_log(message: String) -> void:
	"""Rate-limited debug logging to prevent spam"""
	if not debug_organisms:
		return
		
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time != _debug_last_print_time:
		print("WaveArea: " + message)
		_debug_last_print_time = current_time

func _debug_log_force_application(body: Node2D, force: Vector2, method: String) -> void:
	"""Debug force application with intelligent filtering"""
	if not debug_organisms:
		return
		
	# Only log when force is significant
	if force.length() > 10.0:
		var current_time = Time.get_time_dict_from_system()["second"] 
		if current_time != _debug_last_print_time:
			var wave_phase = "UNKNOWN"
			if wave_state:
				match wave_state.phase:
					GameConstants.WavePhase.SURGING: wave_phase = "SURGING"
					GameConstants.WavePhase.TRAVELING: wave_phase = "TRAVELING"  
					GameConstants.WavePhase.RETREATING: wave_phase = "RETREATING"
					GameConstants.WavePhase.CALM: wave_phase = "CALM"
					GameConstants.WavePhase.PAUSING: wave_phase = "PAUSING"
			
			print("WaveArea: 🌊 FORCE → %s | Force: %s | Phase: %s | Method: %s" % [
				body.name, 
				"(%.1f, %.1f)" % [force.x, force.y],
				wave_phase,
				method
			])
			_debug_last_print_time = current_time
