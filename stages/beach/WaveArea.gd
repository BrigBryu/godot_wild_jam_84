class_name WaveArea
extends Area2D

## Wave collision area that follows visual wave position
## Handles detection of bodies entering/exiting the wave

@export var wave_state: WaveState
@export var debug_draw: bool = false  # Disabled for release
@export var debug_print: bool = false  # Disable spam - use targeted prints instead

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
	
	# DON'T lock Area2D position - let collision shape move freely!
	# This was preventing the collision from following the wave!
	# global_position = Vector2.ZERO  # REMOVED - this was the bug!
	
	# Connect to wave state changes if available
	if wave_state:
		wave_state.bounds_changed.connect(_on_wave_bounds_changed)
		wave_state.position_changed.connect(_on_wave_position_changed)

func _physics_process(delta: float) -> void:
	# Apply forces to bodies in wave
	if wave_state:
		_apply_forces_to_bodies(delta)
	
	# DEBUG: Only print on state changes
	#if Engine.get_process_frames() % 120 == 0 and collision_shape:
	#	if bodies_in_wave.size() > 0:
	#		print("Wave area: %d bodies, Collision at Y=%.1f" % [bodies_in_wave.size(), collision_shape.position.y])
	
	# Debug: Check for position jumps (only if debug printing enabled)
	if debug_print:
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
							pass
							#print("⚠️ POSITION JUMP DETECTED!")
							#print("   From: ", last_player_pos)
							#print("   To: ", current_pos)
							#print("   Distance: ", distance)
							#print("   Wave Phase: ", wave_state.phase)
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
	
	# Force redraw for debug visualization
	if debug_draw:
		queue_redraw()
	
	# Debug: Report large changes
	if debug_print:
		var size_change = old_size.distance_to(rect_shape.size)
		var pos_change = old_pos.distance_to(collision_shape.position)
		if size_change > 100 or pos_change > 100:
			pass
			#print("📐 COLLISION SHAPE CHANGE:")
			#print("   Size: ", old_size, " -> ", rect_shape.size, " (delta: ", size_change, ")")
			#print("   Pos: ", old_pos, " -> ", collision_shape.position, " (delta: ", pos_change, ")")

func _apply_forces_to_bodies(delta: float) -> void:
	"""Apply SIMPLE wave forces to all bodies currently in the wave"""
	if not wave_state:
		return
	
	for body in bodies_in_wave.keys():
		if not is_instance_valid(body):
			bodies_in_wave.erase(body)
			continue
		
		var force = Vector2.ZERO
		
		# DEAD SIMPLE - just apply force based on wave phase, no position factors!
		match wave_state.phase:
			"surging", "traveling":
				# Push up the beach (negative Y) - INCREASED for more effect
				force.y = -350.0  # Strong upward push (was 150)
				
			"retreating":
				# Pull toward ocean (positive Y) - INCREASED for more effect
				force.y = 280.0  # Strong pull back (was 120)
				
			"pausing":
				# No forces - wave is holding still at peak
				pass
				
			_:  # "calm"
				# No forces when calm
				pass
		
		# Apply force consistently to all bodies
		# Force is in pixels/second, we multiply by delta to get pixels/frame
		var frame_force = force * delta
		
		# Apply to player
		if body.is_in_group("player"):
			if body.has_method("apply_wave_force"):
				# Player expects force in pixels/frame (will be added to velocity)
				body.apply_wave_force(frame_force)
			else:
				# Fallback: directly modify velocity
				if body is CharacterBody2D:
					body.velocity += frame_force
		
		# Apply to organisms
		elif body.is_in_group("organisms"):
			if body.has_method("apply_wave_force"):
				# Organisms also get force in pixels/frame for consistency
				body.apply_wave_force(frame_force)

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
		# Always print player wave entry
		#print("🌊 PLAYER ENTERED WAVE at Y=%.1f (Phase: %s)" % [body.global_position.y, wave_state.phase if wave_state else "unknown"])
		pass
		if body not in bodies_in_wave:  # Prevent duplicate entries
			bodies_in_wave[body] = true
			body_entered_wave.emit(body)
			
			# Call method on body if it exists
			if body.has_method("on_entered_wave"):
				body.on_entered_wave()
	elif is_organism:
		#if debug_print:
		#	print("🦀 ORGANISM ENTERED WAVE: ", body.name)
		pass
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
		if is_player:
			# Always print player wave exit with more info
			#print("🌊 PLAYER EXITED WAVE at Y=%.1f" % body.global_position.y)
			#if wave_state:
			#	print("   Wave was in phase: %s" % wave_state.phase)
			#	print("   Wave edge Y: %.1f, bottom Y: %.1f" % [wave_state.edge_y, wave_state.bottom_y])
			pass
		
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
		# Draw the collision shape relative to its actual position
		# Since Area2D is no longer locked at origin, use local coordinates
		var rect = Rect2(
			collision_shape.position - rect_shape.size / 2,
			rect_shape.size
		)
		draw_rect(rect, Color.CYAN, false, 3.0)  # Thicker line for visibility
		
		# Draw center cross for debugging
		var center = collision_shape.position
		draw_line(center - Vector2(20, 0), center + Vector2(20, 0), Color.CYAN, 2.0)
		draw_line(center - Vector2(0, 20), center + Vector2(0, 20), Color.CYAN, 2.0)
		
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
