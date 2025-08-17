extends CharacterBody2D

# Movement
@export_group("Movement")
@export var speed: float = 200.0
@export var acceleration: float = 10.0  # How quickly we reach target speed
@export var friction: float = 10.0  # How quickly we stop
@export var wave_influence: float = 1.5  # How much waves affect movement (increased for more effect)

# Shore boundary - SIMPLE HARD WALL
@export_group("Boundaries")
@export var shore_y: float = 420.0  # Hard wall position - player cannot go past this

# Interaction
@export_group("Interaction")
@export var interaction_distance: float = 30.0

# REMOVED: Water zones not needed with hard wall
# Player never enters water

# State
var accumulated_forces: Vector2 = Vector2.ZERO  # Forces applied this frame
var nearby_organisms: Array = []
var highlighted_organism: Node2D = null
var hint_shown: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var wave_detector: WaveDetector = $WaveDetector
@onready var water_sound_player: WaterSoundPlayer = $WaterSoundPlayer
# Water sounds removed - will be reworked later
# @onready var water_sound_main: AudioStreamPlayer2D = $WaterSoundMain
# @onready var water_sound_alt1: AudioStreamPlayer2D = $WaterSoundAlt1
# @onready var water_sound_alt2: AudioStreamPlayer2D = $WaterSoundAlt2

func _ready():
	# Add to group FIRST before any other setup
	add_to_group("player")
	
	setup_collision_layers()
	setup_interaction_area()
	# setup_water_sounds() # Will be restored in Phase 2
	
	# Set up wave detector if not present
	if not wave_detector:
		wave_detector = WaveDetector.new()
		wave_detector.name = "WaveDetector"
		add_child(wave_detector)

func setup_collision_layers():
	# Player is on layer 1, collides with world (layer 2) but NOT interactables (layer 5)
	set_collision_layer_value(1, true)  # Player layer
	set_collision_mask_value(2, true)   # Collide with world
	set_collision_mask_value(5, false)  # Don't collide with interactables (can walk through)
	# Note: Wave detection happens through Area2D overlap, not collision mask

func setup_interaction_area():
	if interaction_area:
		interaction_area.area_entered.connect(_on_organism_entered_range)
		interaction_area.area_exited.connect(_on_organism_exited_range)
		interaction_area.collision_layer = 0  # Area2D doesn't need to be on any layer
		interaction_area.collision_mask = 16  # Layer 5 - Detect interactables only

func _physics_process(delta: float) -> void:
	var old_position = global_position
	var old_velocity = velocity
	
	# DEBUG: Simple status every 2 seconds
	#if Engine.is_editor_hint() == false and Engine.get_process_frames() % 120 == 0:
	#	print("Player Y: %.1f | Shore: %.1f | In Wave: %s" % [global_position.y, shore_y, wave_detector.is_in_wave if wave_detector else false])
	
	# Apply accumulated forces ONCE at the start of frame
	if accumulated_forces.length() > 0:
		velocity += accumulated_forces * wave_influence
		accumulated_forces = Vector2.ZERO  # Reset immediately after applying
	
	# Handle all movement (input + boundaries)
	handle_movement(delta)
	
	# PREVENT TELEPORTATION: Clamp position BEFORE move_and_slide
	# This prevents the collision system from causing jumps
	if global_position.y > shore_y - 5:  # Give 5 pixel buffer
		global_position.y = shore_y - 5
		if velocity.y > 0:
			velocity.y = 0  # Stop downward movement at shore
	
	# Use Godot's built-in physics
	var pre_move_pos = global_position
	move_and_slide()
	var post_move_pos = global_position
	
	# SCREEN BOUNDARY CLAMPING - Use camera limits directly
	# Get camera limits and use them as hard boundaries
	var camera = get_node_or_null("Camera2D") as Camera2D
	if camera:
		# Simple rectangle boundaries matching camera limits
		# Camera limits are: left=0, right=1280, top=0, bottom=720
		var player_half_width = 10.0  # Small buffer for player sprite
		
		# Left boundary
		if global_position.x < camera.limit_left + player_half_width:
			global_position.x = camera.limit_left + player_half_width
			if velocity.x < 0:
				velocity.x = 0
		
		# Right boundary
		if global_position.x > camera.limit_right - player_half_width:
			global_position.x = camera.limit_right - player_half_width
			if velocity.x > 0:
				velocity.x = 0
		
		# Top boundary
		if global_position.y < camera.limit_top + player_half_width:
			global_position.y = camera.limit_top + player_half_width
			if velocity.y < 0:
				velocity.y = 0
	
	# SECOND SAFETY CHECK: Fix any teleportation that happened
	if abs(post_move_pos.y - pre_move_pos.y) > 15:  # Teleport detected
		#print("🔴 Teleport prevented! Jump was: %.1f pixels" % abs(post_move_pos.y - pre_move_pos.y))
		pass
		# Revert to pre-move position to prevent teleport
		global_position = pre_move_pos
		# Dampen velocity to prevent repeated attempts
		velocity *= 0.5
	
	# Final boundary enforcement (gentle)
	if global_position.y > shore_y:
		global_position.y = shore_y
		velocity.y = min(velocity.y, 0)
	
	# Update visuals
	update_animation()
	update_organism_highlighting()
	
	# Emit position changes for camera following, minimap, etc.
	if global_position != old_position:
		SignalBus.player_moved.emit(global_position)

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Calculate target velocity from input
	var target_velocity = input_dir * speed
	
	# Smoothly interpolate to target velocity FIRST
	if input_dir.length() > 0:
		# Accelerate towards target
		velocity = velocity.lerp(target_velocity, acceleration * delta)
	else:
		# Apply friction when no input
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	
	# Apply boundary forces AFTER movement (so it can override if needed)
	apply_boundary_forces(delta)

# Water collision detection removed for complete rework
# func check_water_collision():
# 	# Check if player is in water zone based on position
# 	var beach_scene = get_node_or_null("/root/BeachMinimal")
# 	if beach_scene and "shore_y" in beach_scene:
# 		var water_boundary = beach_scene.shore_y
# 		
# 		if global_position.y > water_boundary and not is_in_water:
# 			is_in_water = true
# 			SignalBus.player_entered_water.emit()
# 			# Update shader to show water tint on bottom half
# 			if sprite and sprite.material:
# 				sprite.material.set_shader_parameter("in_water", true)
# 			# Reset pattern when entering water
# 			water_step_count = 0
# 			water_pattern = [1, 1, 1]  # Always start with pattern 1,1,1
# 		elif global_position.y <= water_boundary and is_in_water:
# 			is_in_water = false
# 			SignalBus.player_exited_water.emit()
# 			# Remove water tint
# 			if sprite and sprite.material:
# 				sprite.material.set_shader_parameter("in_water", false)

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

func _unhandled_input(event):
	if event.is_action_pressed("interact"):
		# Note: player_interaction_attempted signal was removed (never had listeners)
		attempt_pickup()

func attempt_pickup():
	if highlighted_organism:
		collect_organism(highlighted_organism)

func collect_organism(organism: Node2D):
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

func _on_organism_entered_range(area: Area2D):
	if area.is_in_group("organisms"):
		nearby_organisms.append(area)
		SignalBus.critter_interaction_available.emit(area)

func _on_organism_exited_range(area: Area2D):
	if area.is_in_group("organisms"):
		nearby_organisms.erase(area)
		SignalBus.critter_interaction_unavailable.emit(area)
		
		if highlighted_organism == area:
			remove_highlight(area)
			highlighted_organism = null
		
		# Hide interaction hint if no organisms nearby
		if nearby_organisms.is_empty():
			SignalBus.ui_show_interaction_hint.emit(false, "")
			hint_shown = false

func update_organism_highlighting():
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
			apply_highlight(highlighted_organism)
			SignalBus.critter_highlighted.emit(highlighted_organism)
			
			# Show interaction hint only if not already shown
			if not hint_shown:
				var hint_text = "Press E to collect"
				if highlighted_organism.has_method("_get_interaction_prompt"):
					hint_text = highlighted_organism._get_interaction_prompt()
				SignalBus.ui_show_interaction_hint.emit(true, hint_text)
				hint_shown = true

func apply_highlight(organism: Node2D):
	if organism and organism.has_method("set_highlighted"):
		organism.set_highlighted(true)

func remove_highlight(organism: Node2D):
	if organism and organism.has_method("set_highlighted"):
		organism.set_highlighted(false)

# Removed update_water_zone - not needed with hard wall

# Wave interaction methods
func apply_wave_force(force: Vector2) -> void:
	"""Accumulate wave forces to be applied in physics process"""
	# Actually accumulate the force
	accumulated_forces += force
	
	# Print significant forces occasionally
	#if abs(force.y) > 3.0:  # Only print larger forces
	#	var frame_count = Engine.get_process_frames()
	#	if frame_count % 60 == 0:  # Print every second
	#		if force.y < 0:
	#			print("⬆️🌊 Wave PUSHING player UP: %.1f pixels/frame" % abs(force.y))
	#		elif force.y > 0:
	#			print("⬇️🌊 Wave PULLING player DOWN: %.1f pixels/frame" % force.y)

func on_entered_wave() -> void:
	"""Called by WaveArea when player enters wave"""
	# Handled by update_water_state now
	pass

func on_exited_wave() -> void:
	"""Called by WaveArea when player exits wave"""
	# Don't clear accumulated_forces here - let physics_process handle it
	pass

func apply_boundary_forces(delta: float) -> void:
	"""SOFT BOUNDARY - Apply gentle resistance near shore"""
	# Apply soft resistance as player approaches shore
	var distance_to_shore = shore_y - global_position.y
	
	if distance_to_shore < 20 and distance_to_shore > 0:
		# Getting close to shore - apply gentle upward resistance
		# This helps prevent hard collisions
		var resistance_strength = 1.0 - (distance_to_shore / 20.0)  # 0 to 1 as we approach shore
		velocity.y -= resistance_strength * 100.0 * delta  # Gentle upward push

# Water sound functions removed for complete rework
# func _on_animation_started(anim_name: StringName):
# 	# Reset frame tracking when a new animation starts
# 	last_water_sound_frame = -1
# 
# func play_water_footstep_sound():
# 	# Get current sound from pattern
# 	var current_sound = water_pattern[water_step_count % 3]
# 	
# 	# Play the appropriate sound with ±5% pitch variation and quieter volume
# 	if current_sound == 1:
# 		if water_sound_main and water_sound_main.stream:
# 			water_sound_main.pitch_scale = randf_range(0.95, 1.05)
# 			water_sound_main.volume_db = randf_range(-10.0, -7.0)
# 			water_sound_main.play()
# 	elif current_sound == 2:
# 		if water_sound_alt1 and water_sound_alt1.stream:
# 			water_sound_alt1.pitch_scale = randf_range(0.95, 1.05)
# 			water_sound_alt1.volume_db = randf_range(-10.0, -7.0)
# 			water_sound_alt1.play()
# 	elif current_sound == 3:
# 		if water_sound_alt2 and water_sound_alt2.stream:
# 			water_sound_alt2.pitch_scale = randf_range(0.95, 1.05)
# 			water_sound_alt2.volume_db = randf_range(-10.0, -7.0)
# 			water_sound_alt2.play()
# 	
# 	# Increment step counter
# 	water_step_count += 1
# 	
# 	# Every 3 steps, determine the next pattern
# 	if water_step_count % 3 == 0:
# 		determine_next_pattern()
# 
# func determine_next_pattern():
# 	# Pattern probabilities:
# 	# [1,1,1] = 40%
# 	# [1,2,2] = 20%
# 	# [2,2,2] = 10%
# 	# [1,3,1] = 10%
# 	# [1,2,1] = 10%
# 	# [1,2,3] = 10%
# 	
# 	var roll = randf()
# 	
# 	if roll < 0.4:  # 40% chance
# 		water_pattern = [1, 1, 1]
# 	elif roll < 0.6:  # 20% chance
# 		water_pattern = [1, 2, 2]
# 	elif roll < 0.7:  # 10% chance
# 		water_pattern = [2, 2, 2]
# 	elif roll < 0.8:  # 10% chance
# 		water_pattern = [1, 3, 1]
# 	elif roll < 0.9:  # 10% chance
# 		water_pattern = [1, 2, 1]
# 	else:  # 10% chance
# 		water_pattern = [1, 2, 3]
