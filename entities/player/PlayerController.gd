extends CharacterBody2D

@export var speed: float = 200.0
@export var interaction_distance: float = 30.0

var nearby_organisms: Array = []
var highlighted_organism: Node2D = null
var hint_shown: bool = false  # Track if hint is currently shown

# Separate tracking for wave forces and player input
var wave_velocity: Vector2 = Vector2.ZERO
var input_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
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

# Water sounds removed for rework
# func setup_water_sounds():
# 	# Connect to the animation player to detect frame changes
# 	if animation_player:
# 		# Connect to animation_started to reset frame tracking
# 		animation_player.animation_started.connect(_on_animation_started)

func _physics_process(delta):
	var old_position = global_position
	
	handle_movement()
	update_animation()
	# Wave detection now handled by WaveDetector component
	update_organism_highlighting()
	move_and_slide()
	
	# Shore barrier - prevent player from going too far into water
	enforce_shore_barrier()
	
	# Emit position changes for camera following, minimap, etc.
	if global_position != old_position:
		SignalBus.player_moved.emit(global_position)

func handle_movement():
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction.length() > 0:
		# Apply wave detector's movement multiplier
		var speed_multiplier = 1.0
		if wave_detector:
			speed_multiplier = wave_detector.get_movement_multiplier()
		# Set player input velocity
		input_velocity = direction * speed * speed_multiplier
	else:
		# No player input
		input_velocity = Vector2.ZERO
	
	# Combine player input with wave forces
	# Wave forces are accumulated in wave_velocity by WaveArea
	velocity = input_velocity + wave_velocity
	
	# Apply dampening to wave forces over time (so they don't accumulate forever)
	wave_velocity *= 0.95  # Gradually reduce wave forces

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

func update_animation():
	if not animation_player or not sprite:
		return
		
	# Only play walk animation based on PLAYER INPUT, not wave forces
	# This prevents the player from "walking" when being pushed by waves
	if input_velocity.length() > 10:
		# Update sprite direction based on input
		if input_velocity.x < 0:
			sprite.flip_h = false
		elif input_velocity.x > 0:
			sprite.flip_h = true
		
		if animation_player.has_animation("walk_left"):
			if animation_player.current_animation != "walk_left":
				animation_player.play("walk_left")
			# Water sound tracking removed for rework
	else:
		# Player is idle (even if being moved by waves)
		if animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
			# Water sound tracking removed for rework

func _unhandled_input(event):
	if event.is_action_pressed("interact"):
		SignalBus.player_interaction_attempted.emit()
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

# Wave interaction methods
func on_entered_wave():
	"""Called by WaveArea when player enters wave"""
	# Wave forces will start being applied
	pass

func on_exited_wave():
	"""Called by WaveArea when player exits wave"""
	# Reset wave velocity when leaving water
	wave_velocity = Vector2.ZERO

func enforce_shore_barrier():
	"""Simple hard barrier - player cannot go past shore line at all"""
	# Shore is at Y = 420
	var shore_y = 420.0
	
	# Simple: Cannot go past shore into water
	if global_position.y > shore_y:
		# Hard stop at shore
		global_position.y = shore_y
		
		# Cancel any downward velocity
		if velocity.y > 0:
			velocity.y = 0
		if wave_velocity.y > 0:
			wave_velocity.y = 0  # Complete stop at shore

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
