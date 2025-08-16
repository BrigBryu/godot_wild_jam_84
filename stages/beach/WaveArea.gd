class_name WaveArea
extends Area2D

## Wave collision area that follows visual wave position
## Handles detection of bodies entering/exiting the wave

@export var wave_state: WaveState
@export var debug_draw: bool = false

# Cached references
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Tracking bodies in wave
var bodies_in_wave: Dictionary = {}  # Node2D -> bool (just tracking if they're in)

# Debug tracking
var last_player_pos: Vector2 = Vector2.ZERO
var position_check_timer: float = 0.0

signal body_entered_wave(body: Node2D)
signal body_exited_wave(body: Node2D)

func _ready() -> void:
	# Set up collision layers
	set_collision_layer_value(10, true)  # Wave is on layer 10
	set_collision_mask_value(1, true)  # Detect player (layer 1)
	
	# Enable monitoring
	monitoring = true
	monitorable = true
	
	# Connect to body detection (not area detection)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up collision shape
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
	
	var rect_shape = RectangleShape2D.new()
	# Set initial size to cover a reasonable area
	rect_shape.size = Vector2(1920, 200)  # Default size
	collision_shape.shape = rect_shape
	collision_shape.position = Vector2(960, 420)  # Center position
	
	# Connect to wave state changes if available
	if wave_state:
		wave_state.bounds_changed.connect(_on_wave_bounds_changed)
		wave_state.position_changed.connect(_on_wave_position_changed)

func _physics_process(delta: float) -> void:
	# Apply forces to bodies in wave
	if wave_state:
		_apply_forces_to_bodies(delta)
	
	# Debug: Check for position jumps
	if debug_draw:
		position_check_timer += delta
		if position_check_timer >= 0.1:  # Check every 0.1 seconds
			position_check_timer = 0.0
			
			# Find player in bodies
			for body in bodies_in_wave.keys():
				if body.is_in_group("player"):
					var current_pos = body.global_position
					if last_player_pos != Vector2.ZERO:
						var distance = current_pos.distance_to(last_player_pos)
						if distance > 50:  # Detect jumps greater than 50 pixels
							print("⚠️ POSITION JUMP DETECTED!")
							print("   From: ", last_player_pos)
							print("   To: ", current_pos)
							print("   Distance: ", distance)
							print("   Wave Phase: ", wave_state.phase)
					last_player_pos = current_pos
		
		queue_redraw()

func update_collision_shape(bounds: Rect2) -> void:
	"""Update collision shape to match wave bounds"""
	if not collision_shape or not collision_shape.shape:
		return
	
	var rect_shape = collision_shape.shape as RectangleShape2D
	if not rect_shape:
		return
	
	# Debug: Track significant shape changes
	var old_size = rect_shape.size
	var old_pos = collision_shape.position
	
	# Set shape size and position
	rect_shape.size = bounds.size
	collision_shape.position = bounds.get_center()
	
	# Debug: Report large changes
	if debug_draw:
		var size_change = old_size.distance_to(rect_shape.size)
		var pos_change = old_pos.distance_to(collision_shape.position)
		if size_change > 100 or pos_change > 100:
			print("📐 COLLISION SHAPE CHANGE:")
			print("   Size: ", old_size, " -> ", rect_shape.size, " (delta: ", size_change, ")")
			print("   Pos: ", old_pos, " -> ", collision_shape.position, " (delta: ", pos_change, ")")
	
	# Keep Area2D at origin - collision shape handles positioning
	if global_position != Vector2.ZERO:
		if debug_draw:
			print("⚠️ Resetting WaveArea global_position from ", global_position, " to (0, 0)")
		global_position = Vector2.ZERO

func _apply_forces_to_bodies(delta: float) -> void:
	"""Apply wave forces to all bodies currently in the wave"""
	if not wave_state:
		return
	
	for body in bodies_in_wave.keys():
		if not is_instance_valid(body):
			bodies_in_wave.erase(body)
			continue
		
		var force = Vector2.ZERO
		var force_strength = 1.0
		
		# Calculate depth factor (1.0 at surface, decreases with depth)
		var depth_in_wave = body.global_position.y - wave_state.edge_y
		var wave_height = wave_state.bottom_y - wave_state.edge_y
		if wave_height > 0:
			var depth_factor = 1.0 - (depth_in_wave / wave_height)
			depth_factor = clamp(depth_factor, 0.3, 1.0)  # Minimum 30% force at bottom
			force_strength *= depth_factor
		
		# Apply different forces based on wave phase
		match wave_state.phase:
			"surging", "traveling":
				# Same push force for both traveling and surging
				# This prevents the weird speed-up at transition
				force.y = -wave_state.surge_force * force_strength
				# Small sideways drift for realism
				force.x = sin(Time.get_ticks_msec() * 0.001) * 30.0
				
			"retreating":
				# Pull toward ocean (positive Y = downward)
				force.y = wave_state.retreat_force * force_strength
				# Stronger sideways pull during retreat
				force.x = cos(Time.get_ticks_msec() * 0.0015) * 50.0
				
			"pausing":
				# No forces - wave is holding still at peak
				pass
				
			_:  # "calm"
				# No forces when calm
				pass
		
		# Apply force to player (CharacterBody2D)
		if body.is_in_group("player"):
			if body is CharacterBody2D:
				# Sanity check: Make sure force is reasonable
				var force_magnitude = force.length()
				if force_magnitude > 1000:  # Cap extreme forces
					if debug_draw:
						print("⚠️ EXTREME FORCE DETECTED: ", force, " - CAPPING!")
					force = force.normalized() * 1000
				
				# Debug: Print player position before force
				if debug_draw and force.length() > 0:
					print("PLAYER POS BEFORE: ", body.global_position, " | Phase: ", wave_state.phase, " | Force: ", force * delta)
				
				# Set wave_velocity on player instead of modifying velocity directly
				# This allows PlayerController to properly combine wave forces with input
				if "wave_velocity" in body:
					var velocity_before = body.wave_velocity
					body.wave_velocity += force * delta
					
					# Sanity check: Cap wave velocity to prevent extreme speeds
					var max_wave_velocity = 300.0
					if body.wave_velocity.length() > max_wave_velocity:
						if debug_draw:
							print("⚠️ WAVE VELOCITY TOO HIGH: ", body.wave_velocity.length(), " - CAPPING!")
						body.wave_velocity = body.wave_velocity.normalized() * max_wave_velocity
					
					# Debug: Print wave velocity after force
					if debug_draw and force.length() > 0:
						print("PLAYER WAVE VEL AFTER: ", body.wave_velocity, " (was: ", velocity_before, ")")
						print("PLAYER TOTAL VEL: ", body.velocity)
				else:
					# Fallback: directly modify velocity if wave_velocity doesn't exist
					body.velocity += force * delta
					if debug_draw:
						print("⚠️ Using fallback velocity modification (no wave_velocity property)")
		
		# Apply force to organisms (Area2D with physics body)
		elif body.is_in_group("organisms"):
			if body.has_method("apply_wave_force"):
				body.apply_wave_force(force * delta)

func is_body_in_wave_zone(body: Node2D) -> bool:
	"""Simple check: is the body's Y position within the wave area?"""
	if not wave_state:
		return false
	var body_y = body.global_position.y
	return body_y > wave_state.edge_y and body_y < wave_state.bottom_y

func _on_body_entered(body: Node2D) -> void:
	"""Handle body entering wave area"""
	# Check by name if groups aren't set yet, or by group
	var is_player = body.name == "Player" or body.is_in_group("player")
	var is_organism = body.is_in_group("organisms")
	
	if is_player:
		if debug_draw:
			print("🌊 PLAYER ENTERED WAVE - Phase: %s" % wave_state.phase if wave_state else "unknown")
			print("   Entry Position: ", body.global_position)
			print("   Wave Edge Y: ", wave_state.edge_y if wave_state else "N/A")
			print("   Wave Bottom Y: ", wave_state.bottom_y if wave_state else "N/A")
		if body not in bodies_in_wave:  # Prevent duplicate entries
			bodies_in_wave[body] = true
			body_entered_wave.emit(body)
			
			# Call method on body if it exists
			if body.has_method("on_entered_wave"):
				body.on_entered_wave()
	elif is_organism:
		if debug_draw:
			print("🦀 ORGANISM ENTERED WAVE: ", body.name)
		if body not in bodies_in_wave:  # Prevent duplicate entries
			bodies_in_wave[body] = true
			body_entered_wave.emit(body)
			
			# Call method on body if it exists
			if body.has_method("on_entered_wave"):
				body.on_entered_wave()

func _on_body_exited(body: Node2D) -> void:
	"""Handle body exiting wave area"""
	if body in bodies_in_wave:
		var is_player = body.name == "Player" or body.is_in_group("player")
		if is_player and debug_draw:
			print("🌊 PLAYER EXITED WAVE")
			print("   Exit Position: ", body.global_position)
		
		bodies_in_wave.erase(body)
		body_exited_wave.emit(body)
		
		# Call method on body if it exists
		if body.has_method("on_exited_wave"):
			body.on_exited_wave()

func _on_wave_bounds_changed(new_bounds: Rect2) -> void:
	"""Update collision when wave bounds change"""
	update_collision_shape(new_bounds)

func _on_wave_position_changed(_edge_y: float, _bottom_y: float) -> void:
	"""React to wave position changes"""
	# Update depths will happen in _physics_process
	pass

func get_bodies_in_wave() -> Array:
	"""Get all bodies currently in the wave"""
	return bodies_in_wave.keys()

func is_body_in_wave(body: Node2D) -> bool:
	"""Check if a specific body is in the wave"""
	return body in bodies_in_wave

func _draw() -> void:
	"""Debug visualization"""
	if not debug_draw or not collision_shape or not collision_shape.shape:
		return
	
	var rect_shape = collision_shape.shape as RectangleShape2D
	if rect_shape:
		var rect = Rect2(
			collision_shape.position - rect_shape.size / 2,
			rect_shape.size
		)
		draw_rect(rect, Color.CYAN, false, 2.0)
		
		# Draw wave phase indicator
		if wave_state:
			var phase_color = Color.WHITE
			var phase_text = wave_state.phase.to_upper()
			match wave_state.phase:
				"surging":
					phase_color = Color.GREEN
				"retreating":
					phase_color = Color.RED
				"pausing":
					phase_color = Color.YELLOW
				"traveling":
					phase_color = Color.BLUE
				"calm":
					phase_color = Color.GRAY
			
			# Draw phase text at top of wave area
			draw_string(ThemeDB.fallback_font, Vector2(10, collision_shape.position.y - rect_shape.size.y/2 + 20), 
				"WAVE: " + phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, phase_color)
		
		# Draw body positions and force vectors
		for body in bodies_in_wave:
			if is_instance_valid(body):
				var local_pos = to_local(body.global_position)
				
				# Draw body position
				var body_color = Color.YELLOW if body.is_in_group("player") else Color.ORANGE
				draw_circle(local_pos, 5.0, body_color)
				
				# Draw force vector if wave is active and applying forces
				if wave_state and wave_state.phase not in ["calm", "pausing"]:
					var force_dir = Vector2.ZERO
					match wave_state.phase:
						"surging", "traveling":
							force_dir = Vector2(0, -1)  # Full upward push for both
						"retreating":
							force_dir = Vector2(0, 1)   # Downward pull
					
					if force_dir.length() > 0:
						var arrow_end = local_pos + force_dir * 30.0
						draw_line(local_pos, arrow_end, Color.RED, 2.0)
						# Draw arrowhead
						var arrow_angle = force_dir.angle()
						var arrow_size = 8.0
						var arrow_point1 = arrow_end + Vector2.from_angle(arrow_angle + 2.5) * -arrow_size
						var arrow_point2 = arrow_end + Vector2.from_angle(arrow_angle - 2.5) * -arrow_size
						draw_line(arrow_end, arrow_point1, Color.RED, 2.0)
						draw_line(arrow_end, arrow_point2, Color.RED, 2.0)
