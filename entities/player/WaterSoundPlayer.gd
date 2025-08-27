class_name WaterSoundPlayer
extends Node

## Handles water footstep sounds for the player
## Uses pattern-based sound variation for realism
## Syncs with foot-down frame of walk animation

@export var enabled: bool = true
@export var volume_range: Vector2 = Vector2(-10.0, -7.0)  # dB range
@export var pitch_variation: float = 0.05  # ±5% pitch variation
@export var footstep_frame: int = 1  # Frame index for foot-down (walk_right_2)

# Sound patterns for variety
var water_pattern: Array = [1, 1, 1]  # Current 3-step pattern
var water_step_count: int = 0
var frame_triggered: bool = false  # Prevents multiple triggers per frame

# Sound nodes
@onready var water_sound_main: AudioStreamPlayer2D = get_parent().get_node_or_null("WaterSoundMain")
@onready var water_sound_alt1: AudioStreamPlayer2D = get_parent().get_node_or_null("WaterSoundAlt1")
@onready var water_sound_alt2: AudioStreamPlayer2D = get_parent().get_node_or_null("WaterSoundAlt2")

# Parent references
var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var wave_detector: WaveDetector

func _ready() -> void:
	# Get parent references
	player = get_parent() as CharacterBody2D
	if not player:
		push_error("WaterSoundPlayer must be child of CharacterBody2D")
		return
	
	animated_sprite = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	wave_detector = player.get_node_or_null("WaveDetector") as WaveDetector
	
	# Connect to animation changes for frame tracking reset
	if animated_sprite:
		animated_sprite.animation_changed.connect(_on_animation_changed)
		animated_sprite.frame_changed.connect(_on_frame_changed)

func _process(_delta: float) -> void:
	if not enabled or not animated_sprite or not wave_detector:
		return
	
	# Only play sounds when in water, walking, and on the correct frame
	if not wave_detector.is_in_water():
		frame_triggered = false  # Reset when not in water
		return
	
	# Check if we're on the walk animation and foot-down frame
	if animated_sprite.animation == "walk" and animated_sprite.frame == footstep_frame:
		if not frame_triggered:
			play_water_footstep()
			frame_triggered = true

func play_water_footstep() -> void:
	"""Play water footstep sound with pattern variation"""
	if not enabled:
		return
	
	# Get current sound from pattern
	var current_sound = water_pattern[water_step_count % 3]
	
	# Play the appropriate sound with variation
	match current_sound:
		1:
			if water_sound_main and water_sound_main.stream:
				water_sound_main.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
				water_sound_main.volume_db = randf_range(volume_range.x, volume_range.y)
				water_sound_main.play()
		2:
			if water_sound_alt1 and water_sound_alt1.stream:
				water_sound_alt1.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
				water_sound_alt1.volume_db = randf_range(volume_range.x, volume_range.y)
				water_sound_alt1.play()
		3:
			if water_sound_alt2 and water_sound_alt2.stream:
				water_sound_alt2.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
				water_sound_alt2.volume_db = randf_range(volume_range.x, volume_range.y)
				water_sound_alt2.play()
	
	# Increment step counter
	water_step_count += 1
	
	# Every 3 steps, determine the next pattern
	if water_step_count % 3 == 0:
		_determine_next_pattern()

func _determine_next_pattern() -> void:
	"""Randomly select next sound pattern for variety"""
	# Pattern probabilities:
	# [1,1,1] = 40% - Most common, natural rhythm
	# [1,2,2] = 20% - Some variation
	# [2,2,2] = 10% - Different sound
	# [1,3,1] = 10% - Accent pattern
	# [1,2,1] = 10% - Symmetric variation
	# [1,2,3] = 10% - All different
	
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

func _on_animation_changed() -> void:
	"""Reset frame tracking when animation changes"""
	frame_triggered = false
	
	# Reset pattern when starting to walk in water
	if animated_sprite.animation == "walk" and wave_detector and wave_detector.is_in_water():
		water_step_count = 0
		water_pattern = [1, 1, 1]  # Always start with base pattern

func _on_frame_changed() -> void:
	"""Reset trigger flag when frame changes"""
	# Only reset if we're not on the footstep frame anymore
	if animated_sprite.frame != footstep_frame:
		frame_triggered = false

func on_entered_water() -> void:
	"""Called when player enters water"""
	# Reset sound pattern
	water_step_count = 0
	water_pattern = [1, 1, 1]
	frame_triggered = false

func on_exited_water() -> void:
	"""Called when player exits water"""
	# Stop any playing sounds
	if water_sound_main and water_sound_main.playing:
		water_sound_main.stop()
	if water_sound_alt1 and water_sound_alt1.playing:
		water_sound_alt1.stop()
	if water_sound_alt2 and water_sound_alt2.playing:
		water_sound_alt2.stop()