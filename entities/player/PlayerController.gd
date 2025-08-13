extends CharacterBody2D

@export var speed: float = 200.0
@export var interaction_distance: float = 30.0

var nearby_critters: Array = []
var highlighted_critter: Node2D = null
var is_in_water: bool = false
var hint_shown: bool = false  # Track if hint is currently shown
var last_water_sound_frame: int = -1  # Track last frame to prevent duplicate sounds
var water_step_count: int = 0  # Track which step in the pattern we're on
var water_pattern: Array = [1, 1, 1]  # Current 3-step pattern

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var water_sound_main: AudioStreamPlayer2D = $WaterSoundMain
@onready var water_sound_alt1: AudioStreamPlayer2D = $WaterSoundAlt1
@onready var water_sound_alt2: AudioStreamPlayer2D = $WaterSoundAlt2

func _ready():
	add_to_group("player")
	setup_collision_layers()
	setup_interaction_area()
	setup_water_sounds()
	print("Player ready with speed: ", speed)

func setup_collision_layers():
	# Player is on layer 1, collides with world (layer 2) but NOT interactables (layer 5)
	set_collision_layer_value(1, true)  # Player layer
	set_collision_mask_value(2, true)   # Collide with world
	set_collision_mask_value(5, false)  # Don't collide with interactables (can walk through)

func setup_interaction_area():
	if interaction_area:
		interaction_area.area_entered.connect(_on_critter_entered_range)
		interaction_area.area_exited.connect(_on_critter_exited_range)
		interaction_area.collision_layer = 0  # Area2D doesn't need to be on any layer
		interaction_area.collision_mask = 16  # Layer 5 - Detect interactables only

func setup_water_sounds():
	# Connect to the animation player to detect frame changes
	if animation_player:
		# Connect to animation_started to reset frame tracking
		animation_player.animation_started.connect(_on_animation_started)

func _physics_process(delta):
	var old_position = global_position
	
	handle_movement()
	update_animation()
	check_water_collision()
	update_critter_highlighting()
	move_and_slide()
	
	# Emit position changes for camera following, minimap, etc.
	if global_position != old_position:
		SignalBus.player_moved.emit(global_position)

func handle_movement():
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction.length() > 0:
		velocity = direction * speed
		
		# Slow down in water
		if is_in_water:
			velocity *= 0.5
	else:
		velocity = Vector2.ZERO

func check_water_collision():
	# Check if player is in water zone based on position
	var beach_gen = get_node_or_null("/root/Beach/BeachGenerator")
	if beach_gen:
		var water_boundary = (beach_gen.world_height - beach_gen.ocean_height) * beach_gen.tile_size
		
		if global_position.y > water_boundary and not is_in_water:
			is_in_water = true
			SignalBus.player_entered_water.emit()
			# Update shader to show water tint on bottom half
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("in_water", true)
			# Reset pattern when entering water
			water_step_count = 0
			water_pattern = [1, 1, 1]  # Always start with pattern 1,1,1
		elif global_position.y <= water_boundary and is_in_water:
			is_in_water = false
			SignalBus.player_exited_water.emit()
			# Remove water tint
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("in_water", false)

func update_animation():
	if not animation_player or not sprite:
		return
		
	if velocity.length() > 10:
		if velocity.x < 0:
			sprite.flip_h = false
		elif velocity.x > 0:
			sprite.flip_h = true
		
		if animation_player.has_animation("walk_left"):
			if animation_player.current_animation != "walk_left":
				animation_player.play("walk_left")
				last_water_sound_frame = -1  # Reset frame tracking when starting walk
			
			# Check if we should play water sound on frame 63
			if is_in_water and sprite.frame == 63 and last_water_sound_frame != 63:
				play_water_footstep_sound()
				last_water_sound_frame = 63
			elif sprite.frame != 63:
				last_water_sound_frame = sprite.frame
	else:
		if animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
				last_water_sound_frame = -1  # Reset frame tracking when idle

func _unhandled_input(event):
	if event.is_action_pressed("interact"):
		SignalBus.player_interaction_attempted.emit()
		attempt_pickup()

func attempt_pickup():
	if highlighted_critter:
		collect_critter(highlighted_critter)

func collect_critter(critter: Node2D):
	if not critter:
		return
	
	# Get critter information
	var critter_type = "unknown"
	var critter_name = "Unknown Critter"
	var points = 10
	
	if critter.get("critter_type"):
		critter_type = critter.critter_type
	if critter.get("organism_name"):
		critter_name = critter.organism_name
	if critter.has_method("get_score_value"):
		points = critter.get_score_value()
	elif critter.get("collection_value"):
		points = critter.collection_value
	
	# Use SignalBus helper function for collection
	SignalBus.collect_critter(critter_type, critter_name, points, critter.global_position)
	
	# Clean up references
	nearby_critters.erase(critter)
	if highlighted_critter == critter:
		highlighted_critter = null
		# Hide hint after collection
		SignalBus.ui_show_interaction_hint.emit(false, "")
		hint_shown = false
	
	# Trigger critter's collection behavior
	if critter.has_method("collect"):
		critter.collect()
	else:
		critter.queue_free()

func _on_critter_entered_range(area: Area2D):
	if area.is_in_group("critters"):
		nearby_critters.append(area)
		SignalBus.critter_interaction_available.emit(area)

func _on_critter_exited_range(area: Area2D):
	if area.is_in_group("critters"):
		nearby_critters.erase(area)
		SignalBus.critter_interaction_unavailable.emit(area)
		
		if highlighted_critter == area:
			remove_highlight(area)
			highlighted_critter = null
		
		# Hide interaction hint if no critters nearby
		if nearby_critters.is_empty():
			SignalBus.ui_show_interaction_hint.emit(false, "")
			hint_shown = false

func update_critter_highlighting():
	if nearby_critters.is_empty():
		if highlighted_critter:
			remove_highlight(highlighted_critter)
			SignalBus.critter_unhighlighted.emit(highlighted_critter)
			highlighted_critter = null
		# Hide hint when no critters nearby
		if hint_shown:
			SignalBus.ui_show_interaction_hint.emit(false, "")
			hint_shown = false
		return
	
	var closest_critter = null
	var closest_distance = INF
	
	for critter in nearby_critters:
		if is_instance_valid(critter):
			var distance = global_position.distance_to(critter.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_critter = critter
	
	if closest_critter != highlighted_critter:
		# Remove old highlight
		if highlighted_critter:
			remove_highlight(highlighted_critter)
			SignalBus.critter_unhighlighted.emit(highlighted_critter)
		
		# Apply new highlight
		highlighted_critter = closest_critter
		if highlighted_critter:
			apply_highlight(highlighted_critter)
			SignalBus.critter_highlighted.emit(highlighted_critter)
			
			# Show interaction hint only if not already shown
			if not hint_shown:
				var hint_text = "Press E to collect"
				if highlighted_critter.has_method("_get_interaction_prompt"):
					hint_text = highlighted_critter._get_interaction_prompt()
				SignalBus.ui_show_interaction_hint.emit(true, hint_text)
				hint_shown = true

func apply_highlight(critter: Node2D):
	if not critter:
		return
	
	if critter.has_method("set_highlighted"):
		critter.set_highlighted(true)

func remove_highlight(critter: Node2D):
	if not critter:
		return
	
	if critter.has_method("set_highlighted"):
		critter.set_highlighted(false)

func _on_animation_started(anim_name: StringName):
	# Reset frame tracking when a new animation starts
	last_water_sound_frame = -1

func play_water_footstep_sound():
	# Get current sound from pattern
	var current_sound = water_pattern[water_step_count % 3]
	
	# Play the appropriate sound with ±5% pitch variation and quieter volume
	if current_sound == 1:
		if water_sound_main and water_sound_main.stream:
			water_sound_main.pitch_scale = randf_range(0.95, 1.05)
			water_sound_main.volume_db = randf_range(-10.0, -7.0)
			water_sound_main.play()
	elif current_sound == 2:
		if water_sound_alt1 and water_sound_alt1.stream:
			water_sound_alt1.pitch_scale = randf_range(0.95, 1.05)
			water_sound_alt1.volume_db = randf_range(-10.0, -7.0)
			water_sound_alt1.play()
	elif current_sound == 3:
		if water_sound_alt2 and water_sound_alt2.stream:
			water_sound_alt2.pitch_scale = randf_range(0.95, 1.05)
			water_sound_alt2.volume_db = randf_range(-10.0, -7.0)
			water_sound_alt2.play()
	
	# Increment step counter
	water_step_count += 1
	
	# Every 3 steps, determine the next pattern
	if water_step_count % 3 == 0:
		determine_next_pattern()

func determine_next_pattern():
	# Pattern probabilities:
	# [1,1,1] = 40%
	# [1,2,2] = 20%
	# [2,2,2] = 10%
	# [1,3,1] = 10%
	# [1,2,1] = 10%
	# [1,2,3] = 10%
	
	var roll = randf()
	
	if roll < 0.4:  # 40% chance
		water_pattern = [1, 1, 1]
	elif roll < 0.6:  # 20% chance
		water_pattern = [1, 2, 2]
	elif roll < 0.7:  # 10% chance
		water_pattern = [2, 2, 2]
	elif roll < 0.8:  # 10% chance
		water_pattern = [1, 3, 1]
	elif roll < 0.9:  # 10% chance
		water_pattern = [1, 2, 1]
	else:  # 10% chance
		water_pattern = [1, 2, 3]
