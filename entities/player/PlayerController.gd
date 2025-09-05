extends CharacterBody2D

# Movement
@export_group("Movement")
@export var speed: float = GameConstants.PLAYER_SPEED
@export var acceleration: float = GameConstants.PLAYER_ACCELERATION
@export var friction: float = GameConstants.PLAYER_FRICTION
@export var wave_influence: float = GameConstants.PLAYER_WAVE_INFLUENCE

# Shore boundary - SIMPLE HARD WALL
@export_group("Boundaries")
@export var shore_y: float = GameConstants.SHORE_Y
@export var boundary_buffer: float = GameConstants.BOUNDARY_BUFFER
@export var screen_width: float = GameConstants.SCREEN_WIDTH
@export var screen_height: float = GameConstants.SCREEN_HEIGHT

# Interaction
@export_group("Interaction")
@export var interaction_distance: float = GameConstants.PLAYER_INTERACTION_DISTANCE


# Player state
var nearby_organisms: Array = []
var highlighted_organism: Node2D = null
var hint_shown: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var wave_detector: WaveDetector = $WaveDetector
@onready var water_sound_player: WaterSoundPlayer = $WaterSoundPlayer

# External force component for wave physics
var external_force_component: ExternalForceComponent = null

func _ready() -> void:
	# Add to group FIRST before any other setup
	add_to_group("player")
	
	setup_collision_layers()
	setup_interaction_area()
	
	# Set up wave detector if not present
	if not wave_detector:
		wave_detector = WaveDetector.new()
		wave_detector.name = "WaveDetector"
		add_child(wave_detector)
	
	# Set up external force component for wave physics
	setup_external_force_component()
	
	# CRITICAL FIX: Force refresh all existing organisms collision settings
	call_deferred("_fix_existing_organism_collisions")

func setup_collision_layers() -> void:
	# CRITICAL: Clear all layers and masks first, then set ONLY what we want
	collision_layer = 0  # Clear all layers
	collision_mask = 0   # Clear all masks
	
	# Player is ONLY on layer 1, collides ONLY with world (layer 2)
	set_collision_layer_value(1, true)   # Player layer ONLY
	set_collision_mask_value(2, true)    # Collide with world ONLY
	set_collision_mask_value(1, false)   # Don't collide with other players
	set_collision_mask_value(5, false)   # Don't collide with interactables (can walk through)
	set_collision_mask_value(6, false)   # Don't collide with organism physics bodies - CRITICAL FIX
	# Note: Wave detection happens through Area2D overlap, not collision mask

func setup_interaction_area() -> void:
	if interaction_area:
		interaction_area.area_entered.connect(_on_organism_entered_range)
		interaction_area.area_exited.connect(_on_organism_exited_range)
		interaction_area.collision_layer = 0  # Area2D doesn't need to be on any layer
		interaction_area.collision_mask = 16  # Layer 5 - Detect interactables only (2^4 = 16)
		interaction_area.monitoring = true   # Player monitors for organisms
		interaction_area.monitorable = false # Player doesn't need to be detected
		
		print("🔧 Player InteractionArea: Mask=%d, Monitoring=%s, Radius=%.1f" % [
			interaction_area.collision_mask,
			interaction_area.monitoring,
			240.0  # We set this in Player.tscn
		])

func setup_external_force_component() -> void:
	"""Initialize external force component for wave physics"""
	external_force_component = ExternalForceComponent.new()
	external_force_component.name = "ExternalForceComponent"
	external_force_component.mass = 1.0  # Player mass
	external_force_component.max_velocity = GameConstants.PLAYER_SPEED * 3  # Allow wave boosts
	add_child(external_force_component)
	external_force_component.set_physics_body(self)
	external_force_component.activate()

func _physics_process(delta: float) -> void:
	var old_position: Vector2 = global_position
	
	# Calculate movement velocity (input + friction)
	handle_movement(delta)
	
	var _pre_slide_position: Vector2 = global_position
	var _pre_slide_velocity: Vector2 = velocity
	
	# Apply the fully calculated velocity to position
	move_and_slide()
	
	# CRITICAL: Immediate boundary validation after move_and_slide()
	# If physics pushes us past critical boundaries, crash immediately
	var ocean_limit = GameConstants.OCEAN_EDGE_Y
	var left_limit = boundary_buffer
	var right_limit = screen_width - boundary_buffer
	
	# These will crash the game if move_and_slide() violates critical boundaries
	# Use scaled tolerances for wave physics in large world
	var boundary_tolerance = GameConstants.BOUNDARY_BUFFER * 0.5  # 40px tolerance for scaled world
	assert(global_position.y <= ocean_limit + boundary_tolerance, "FATAL: move_and_slide() pushed player past ocean! Y=%.2f > limit=%.2f" % [global_position.y, ocean_limit])
	assert(global_position.x >= left_limit - boundary_tolerance, "FATAL: move_and_slide() pushed player past left edge! X=%.2f < limit=%.2f" % [global_position.x, left_limit])
	assert(global_position.x <= right_limit + boundary_tolerance, "FATAL: move_and_slide() pushed player past right edge! X=%.2f > limit=%.2f" % [global_position.x, right_limit])
	
	# Enforce boundaries AFTER physics movement
	enforce_boundaries()
	
	# Update visuals
	update_animation()
	update_organism_highlighting()
	
	# Emit position changes for camera following, minimap, etc.
	if global_position != old_position:
		SignalBus.player_moved.emit(global_position)

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Calculate target velocity from input
	var target_velocity: Vector2 = input_dir * speed
	
	# Get accumulated external forces (waves, etc.)
	var external_velocity: Vector2 = Vector2.ZERO
	if external_force_component:
		external_velocity = external_force_component.get_accumulated_force("wave") * wave_influence * delta
	
	# Smoothly interpolate to target velocity
	if input_dir.length() > 0:
		# Accelerate towards target
		velocity = velocity.lerp(target_velocity, acceleration * delta)
	else:
		# Apply friction when no input
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	
	# Add external forces to final velocity
	velocity += external_velocity
	
	# Apply boundary forces to modify velocity before it's used
	apply_boundary_forces(delta)


func update_animation() -> void:
	if not sprite:
		return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Play animation based on actual input (not wave movement)
	if input_dir.length() > 0.1:
		# Update sprite direction
		if input_dir.x < -0.1:
			sprite.flip_h = true  # Flip for left movement
		elif input_dir.x > 0.1:
			sprite.flip_h = false  # Normal for right movement
		
		# Play walk animation
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		# Idle animation
		if sprite.animation != "idle":
			sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# Note: player_interaction_attempted signal was removed (never had listeners)
		attempt_pickup()

func attempt_pickup() -> void:
	print("🎯 ATTEMPT PICKUP: Highlighted=%s | Nearby count=%d" % [
		highlighted_organism.name if highlighted_organism else "None",
		nearby_organisms.size()
	])
	if highlighted_organism:
		collect_organism(highlighted_organism)
	else:
		print("❌ NO HIGHLIGHTED ORGANISM TO COLLECT")

func collect_organism(organism: Node2D) -> void:
	if not organism:
		return
	
	# Clean up references BEFORE collection (since organism will queue_free)
	nearby_organisms.erase(organism)
	if highlighted_organism == organism:
		highlighted_organism = null
		# Hide hint after collection
		SignalBus.ui_show_interaction_hint.emit(false, "")
		hint_shown = false
	
	# Let the organism handle its own collection
	# This will emit signals through SignalBus and play animation
	if organism.has_method("collect"):
		organism.collect()
	else:
		# Fallback if somehow not a proper organism
		organism.queue_free()

func _on_organism_entered_range(area: Area2D) -> void:
	print("🎯 PLAYER DETECTED AREA: %s | Groups: %s | Layer: %d | Parent: %s" % [
		area.name,
		str(area.get_groups()),
		area.collision_layer,
		area.get_parent().name if area.get_parent() else "None"
	])
	
	# Check if this is an InteractionArea of an organism
	if area.is_in_group("organisms") or (area.get_parent() and area.get_parent().is_in_group("organisms")):
		# CRITICAL FIX: Always get the parent organism, not the InteractionArea itself!
		var organism = area.get_parent() if area.name == "InteractionArea" else area
		nearby_organisms.append(organism)
		print("✅ ORGANISM ADDED TO NEARBY: %s (Total: %d)" % [organism.name, nearby_organisms.size()])
		SignalBus.critter_interaction_available.emit(organism)

func _on_organism_exited_range(area: Area2D) -> void:
	print("🎯 PLAYER LOST AREA: %s | Parent: %s" % [area.name, area.get_parent().name if area.get_parent() else "None"])
	
	# Check if this is an InteractionArea of an organism  
	if area.is_in_group("organisms") or (area.get_parent() and area.get_parent().is_in_group("organisms")):
		# CRITICAL FIX: Always get the parent organism, not the InteractionArea itself!
		var organism = area.get_parent() if area.name == "InteractionArea" else area
		nearby_organisms.erase(organism)
		print("❌ ORGANISM REMOVED FROM NEARBY: %s (Remaining: %d)" % [organism.name, nearby_organisms.size()])
		SignalBus.critter_interaction_unavailable.emit(organism)
		
		if highlighted_organism == organism:
			remove_highlight(organism)
			highlighted_organism = null
		
		# Hide interaction hint if no organisms nearby
		if nearby_organisms.is_empty():
			SignalBus.ui_show_interaction_hint.emit(false, "")
			hint_shown = false

func update_organism_highlighting() -> void:
	if nearby_organisms.is_empty():
		if highlighted_organism:
			remove_highlight(highlighted_organism)
			SignalBus.critter_unhighlighted.emit(highlighted_organism)
			highlighted_organism = null
		# Hide hint when no organisms nearby
		if hint_shown:
			SignalBus.ui_show_interaction_hint.emit(false, "")
			hint_shown = false
		return
	
	var closest_organism = null
	var closest_distance = INF
	
	for organism in nearby_organisms:
		if is_instance_valid(organism):
			var distance = global_position.distance_to(organism.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_organism = organism
	
	if closest_organism != highlighted_organism:
		# Remove old highlight
		if highlighted_organism:
			remove_highlight(highlighted_organism)
			SignalBus.critter_unhighlighted.emit(highlighted_organism)
		
		# Apply new highlight
		highlighted_organism = closest_organism
		if highlighted_organism:
			print("🌟 HIGHLIGHTING ORGANISM: %s at distance %.1f" % [highlighted_organism.name, closest_distance])
			apply_highlight(highlighted_organism)
			SignalBus.critter_highlighted.emit(highlighted_organism)
			
			# Show interaction hint only if not already shown
			if not hint_shown:
				var hint_text = "Press E to collect"
				if highlighted_organism.has_method("_get_interaction_prompt"):
					hint_text = highlighted_organism._get_interaction_prompt()
				SignalBus.ui_show_interaction_hint.emit(true, hint_text)
				hint_shown = true

func apply_highlight(organism: Node2D) -> void:
	if organism and organism.has_method("set_highlighted"):
		organism.set_highlighted(true)

func remove_highlight(organism: Node2D) -> void:
	if organism and organism.has_method("set_highlighted"):
		organism.set_highlighted(false)

func get_force_component() -> ExternalForceComponent:
	"""Get the external force component for this player"""
	return external_force_component

# Wave interaction methods
func apply_wave_force(force: Vector2) -> void:
	"""Apply wave forces via ExternalForceComponent"""
	if external_force_component:
		external_force_component.add_force(force, "wave", ExternalForceComponent.ForceMode.CONSTANT)
	else:
		push_error("CRITICAL: Player missing ExternalForceComponent - wave forces ignored")

func apply_external_force(force: Vector2, source: String = "unknown", mode: ExternalForceComponent.ForceMode = ExternalForceComponent.ForceMode.CONSTANT) -> void:
	"""Apply external force using force system"""
	if external_force_component:
		external_force_component.add_force(force, source, mode)
	

func on_entered_wave() -> void:
	"""Called by WaveArea when player enters wave"""
	pass  # Wave forces applied through apply_wave_force()

func on_exited_wave() -> void:
	"""Called by WaveArea when player exits wave"""
	if external_force_component:
		external_force_component.clear_forces("wave")

func apply_boundary_forces(delta: float) -> void:
	"""SOFT BOUNDARY - Apply gentle resistance near shore"""
	# Apply soft resistance as player approaches shore
	var distance_to_shore: float = shore_y - global_position.y
	
	if distance_to_shore < GameConstants.SOFT_BOUNDARY_DISTANCE and distance_to_shore > 0:
		# Getting close to shore - apply gentle upward resistance
		# This helps prevent hard collisions
		var resistance_strength: float = 1.0 - (distance_to_shore / GameConstants.SOFT_BOUNDARY_DISTANCE)  # 0 to 1 as we approach shore
		velocity.y -= resistance_strength * GameConstants.RESISTANCE_FORCE * delta  # Gentle upward push

func _fix_existing_organism_collisions() -> void:
	"""Fix collision settings for all existing organisms in the scene"""
	# Find all organisms in the scene
	for organism in get_tree().get_nodes_in_group("organisms"):
		if organism.has_method("setup_collision_layers"):
			organism.setup_collision_layers()
		elif organism.has_node("PhysicsBody"):
			# Manually fix collision settings for organisms without setup method
			var physics_body = organism.get_node("PhysicsBody")
			if physics_body:
				# CRITICAL: Clear all layers and set ONLY layer 6
				physics_body.collision_layer = 0  # Clear all layers
				physics_body.set_collision_layer_value(6, true)  # ONLY Physics organisms layer
				physics_body.set_collision_layer_value(1, false)  # NOT on player layer
				
				# Clear all masks and set ONLY world collision
				physics_body.collision_mask = 0  # Clear all masks
				physics_body.set_collision_mask_value(2, true)   # Collide with world only
				physics_body.set_collision_mask_value(1, false)  # NO collision with player

func enforce_boundaries() -> void:
	"""Mixed boundary enforcement - hard clamps for critical boundaries, soft for others"""
	var boundary_push_force = 2400.0  # 8x scaled from 300.0
	var delta_time = get_physics_process_delta_time()
	var original_position = global_position
	
	_enforce_hard_boundaries()
	_validate_boundary_enforcement(original_position)
	_apply_soft_boundaries(boundary_push_force, delta_time)

func _enforce_hard_boundaries() -> void:
	"""Apply hard position clamps that cannot be violated"""
	var ocean_edge_y = GameConstants.OCEAN_EDGE_Y
	
	# Ocean barrier - HARD position clamp with velocity stop
	if global_position.y > ocean_edge_y:
		global_position.y = ocean_edge_y
		if velocity.y > 0:
			velocity.y = 0
		assert(global_position.y <= ocean_edge_y + 1.0, "FATAL: Ocean boundary violation after clamp! Position: %s, Limit: %s" % [global_position.y, ocean_edge_y])
	
	# Screen edge boundaries - HARD position clamps
	if global_position.x < boundary_buffer:
		global_position.x = boundary_buffer
		if velocity.x < 0:
			velocity.x = 0
		assert(global_position.x >= boundary_buffer - 1.0, "FATAL: Left boundary violation after clamp! Position: %s, Limit: %s" % [global_position.x, boundary_buffer])
	
	if global_position.x > screen_width - boundary_buffer:
		global_position.x = screen_width - boundary_buffer
		if velocity.x > 0:
			velocity.x = 0
		assert(global_position.x <= screen_width - boundary_buffer + 1.0, "FATAL: Right boundary violation after clamp! Position: %s, Limit: %s" % [global_position.x, screen_width - boundary_buffer])

func _validate_boundary_enforcement(original_position: Vector2) -> void:
	"""Final validation - crash if any boundary is violated"""
	var ocean_edge_y = GameConstants.OCEAN_EDGE_Y
	
	# Critical boundary violations - allow small tolerance after hard clamps
	var validation_tolerance = 20.0  # Small tolerance for floating-point precision
	assert(global_position.y <= ocean_edge_y + validation_tolerance, "FATAL BOUNDARY VIOLATION: Player in deep ocean! Y=%.2f > limit=%.2f" % [global_position.y, ocean_edge_y])
	assert(global_position.x >= boundary_buffer - validation_tolerance, "FATAL BOUNDARY VIOLATION: Player past left edge! X=%.2f < limit=%.2f" % [global_position.x, boundary_buffer])
	assert(global_position.x <= screen_width - boundary_buffer + validation_tolerance, "FATAL BOUNDARY VIOLATION: Player past right edge! X=%.2f > limit=%.2f" % [global_position.x, screen_width - boundary_buffer])
	
	# Sanity checks for impossible positions
	assert(not is_nan(global_position.x) and not is_nan(global_position.y), "FATAL: Player position contains NaN! Position: %s" % global_position)
	assert(not is_inf(global_position.x) and not is_inf(global_position.y), "FATAL: Player position contains infinity! Position: %s" % global_position)
	# Allow larger jumps for wave physics in scaled world
	var max_frame_jump = GameConstants.PLAYER_SPEED * 2.0  # 2 frames worth of max player speed
	assert(global_position.distance_to(original_position) < max_frame_jump, "FATAL: Massive position jump detected! From: %s To: %s Distance: %.2f" % [original_position, global_position, global_position.distance_to(original_position)])

func _apply_soft_boundaries(boundary_push_force: float, delta_time: float) -> void:
	"""Apply gentle resistance near boundary limits"""
	var ocean_edge_y = GameConstants.OCEAN_EDGE_Y
	
	# Ocean approach warning - apply resistance as you get close
	var ocean_warning_zone = ocean_edge_y - 100.0  # 100 pixels before hard limit (tighter play area)
	if global_position.y > ocean_warning_zone and global_position.y <= ocean_edge_y:
		var approach_factor = (global_position.y - ocean_warning_zone) / 100.0  # 0 to 1
		velocity.y -= boundary_push_force * approach_factor * delta_time
	
	# Shore boundary REMOVED - player can now explore full beach area above shore
	# (No longer pushing player back to water)
