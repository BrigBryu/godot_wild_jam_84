class_name WaveDetector
extends Node

## Component that handles player's interaction with waves and ocean water
## Tracks both dynamic waves and static ocean water

@export var enabled: bool = true
@export var movement_slowdown: float = 0.5  # Speed multiplier when in water
@export var debug_mode: bool = false  # Print debug information - OFF to reduce spam
@export var ocean_threshold_y: float = 420.0  # Y position where ocean water starts

# State - Track both wave and ocean separately
var is_in_wave: bool = false
var is_in_ocean: bool = false
var wave_area: WaveArea = null

# Signals
signal entered_wave()
signal exited_wave()

# Parent references (set in _ready)
var player: CharacterBody2D
var sprite: Sprite2D

# Debug tracking for wave forces
var force_print_timer: float = 0.0
var force_print_interval: float = 0.5  # Print force message every 0.5 seconds

func _ready() -> void:
	# Get parent player node
	player = get_parent() as CharacterBody2D
	if not player:
		push_error("WaveDetector must be child of CharacterBody2D")
		return
	
	# Find sprite for visual effects
	sprite = player.get_node_or_null("Sprite2D") as Sprite2D
	
	# Connect to SignalBus for wave events
	if SignalBus.has_signal("wave_area_ready"):
		SignalBus.connect("wave_area_ready", _on_wave_area_ready)

func _process(delta: float) -> void:
	# Check if player is in ocean water (simple Y position check)
	if player:
		var was_in_ocean = is_in_ocean
		is_in_ocean = player.global_position.y > ocean_threshold_y
		
		# Handle ocean water transitions
		if is_in_ocean != was_in_ocean:
			if is_in_ocean and not is_in_wave:
				# Entered ocean water (only notify if not already in wave)
				_notify_water_entry()
			elif not is_in_ocean and not is_in_wave:
				# Exited ocean water (only notify if not in any water)
				_notify_water_exit()
	
	# Debug force prints only if debug_mode is enabled
	if debug_mode and is_in_wave and wave_area and wave_area.wave_state:
		force_print_timer += delta
		if force_print_timer >= force_print_interval:
			force_print_timer = 0.0
			
			var wave_state = wave_area.wave_state
			
			# Print based on wave phase (only in debug mode)
			if wave_state.phase == "surging":
				print("   ↑ WAVE PUSHING UP BEACH")
			elif wave_state.phase == "retreating":
				print("   ↓ WAVE PULLING TO OCEAN")
			elif wave_state.phase == "pausing":
				print("   ~ WAVE HOLDING")

func _on_wave_area_ready(area: Area2D) -> void:
	"""Connect to wave area when it's ready"""
	wave_area = area as WaveArea
	if wave_area:
		wave_area.body_entered_wave.connect(_on_body_entered_wave)
		wave_area.body_exited_wave.connect(_on_body_exited_wave)

func _on_body_entered_wave(body: Node2D) -> void:
	"""Handle entering wave"""
	if body != player or not enabled:
		return
	
	var was_in_water = is_in_water()
	is_in_wave = true
	entered_wave.emit()
	
	# Only notify water entry if we weren't already in water
	if not was_in_water:
		_notify_water_entry()

func _on_body_exited_wave(body: Node2D) -> void:
	"""Handle exiting wave"""
	if body != player or not enabled:
		return
	
	is_in_wave = false
	exited_wave.emit()
	
	# Only notify water exit if we're not still in ocean water
	if not is_in_ocean:
		_notify_water_exit()

# Removed body_depth_changed - we don't need depth tracking!

func _apply_water_effects(in_water: bool) -> void:
	"""Apply visual effects for being in water"""
	if not sprite or not sprite.material:
		return
	
	# Update shader parameter - simple on/off
	sprite.material.set_shader_parameter("in_water", in_water)

func get_movement_multiplier() -> float:
	"""Get the movement speed multiplier when in water"""
	if not enabled or not is_in_water():
		return 1.0
	return movement_slowdown  # You're in water, you're slow!

func is_in_water() -> bool:
	"""Check if player is in any water (wave OR ocean)"""
	return is_in_wave or is_in_ocean

func _notify_water_entry() -> void:
	"""Unified notification when entering any water"""
	_apply_water_effects(true)
	
	# Notify water sound player
	var sound_player = player.get_node_or_null("WaterSoundPlayer")
	if sound_player and sound_player.has_method("on_entered_water"):
		sound_player.on_entered_water()
	
	# Emit to SignalBus for other systems
	SignalBus.player_entered_water.emit()

func _notify_water_exit() -> void:
	"""Unified notification when exiting all water"""
	_apply_water_effects(false)
	
	# Notify water sound player
	var sound_player = player.get_node_or_null("WaterSoundPlayer")
	if sound_player and sound_player.has_method("on_exited_water"):
		sound_player.on_exited_water()
	
	# Emit to SignalBus for other systems
	SignalBus.player_exited_water.emit()

# Public methods called by WaveArea
func on_entered_wave() -> void:
	"""Called by WaveArea when player enters wave"""
	if not enabled:
		return
	
	var was_in_water = is_in_water()
	is_in_wave = true
	entered_wave.emit()
	
	# Only notify water entry if we weren't already in water
	if not was_in_water:
		_notify_water_entry()

func on_exited_wave() -> void:
	"""Called by WaveArea when player exits wave"""
	if not enabled:
		return
	
	is_in_wave = false
	exited_wave.emit()
	
	# Only notify water exit if we're not still in ocean water
	if not is_in_ocean:
		_notify_water_exit()