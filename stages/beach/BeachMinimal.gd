extends Node2D

@onready var sand      : Sprite2D = $Sand
@onready var ocean     : Sprite2D = $Ocean      # Static ocean background
@onready var wave      : Sprite2D = $Wave       # Dynamic wave (can spawn anywhere)
@onready var foam      : Sprite2D = $Foam       # Foam on the wave
# Debug node disabled for production
# @onready var debug     : Node2D = $ShorelineDebug

@export var shore_y: float = 420.0  # baseline shoreline position  
@export var Rmax: float = 120.0   # max run-up distance for natural waves
@export var w: float = 0.45
@export var k: float = 0.0
@export var lock_vertical: bool = true
@export var wave_front: Color = Color(0.08, 0.55, 0.62, 0.85)  # Front edge of wave (lighter blue-green, more transparent)
@export var wave_tail: Color  = Color(0.04, 0.42, 0.56, 0.98)  # Tail edge of wave (darker blue-green, less transparent)
@export var refract_strength: float = 0.006
@export var foam_edge_width: float = 12.0
@export var crest_offset: float = 7.0
@export var foam_alpha: float = 0.85

@export var normalA_path: String = "res://stages/beach/art/water_normal_map_tileable_looped.jpeg"
@export var normalB_path: String = "res://stages/beach/art/water_normal_map_tileable_looped_more_wavy.jpeg"
@export var foamNoise_path: String = "res://stages/beach/art/foam.jpg"

# Simple Speed-based Wave System
@export_group("Wave Properties")
@export var wave_height: float = 100.0  # Wave height in pixels
@export var wave_speed: float = 110.0   # Base wave speed in pixels/second
@export var surge_multiplier: float = 1.4  # How much wave speed affects surge height (physics-based)

@export_group("Wave Randomization")
@export var speed_randomization: bool = true  # Enable random wave speeds
@export var speed_variation_range: Vector2 = Vector2(0.7, 1.5)  # Min/max speed multipliers (70% to 150%)

# Critter spawner (replaces old starfish system)
@onready var critter_spawner: CritterSpawner = $CritterSpawner

# Single wave state
var wave_position_y: float = 0.0     # Current Y position of wave bottom
var wave_phase: String = "calm"      # "calm", "traveling", "surging", "retreating"
var wave_phase_progress: float = 0.0 # Progress within current phase (0.0 to 1.0)
var wave_edge_y: float = 420.0       # Current wave edge (top) position
var wave_alpha: float = 0.15         # Wave transparency
var wave_foam_alpha: float = 0.15    # Foam transparency

# Current wave's randomized properties
var current_wave_speed: float = 110.0    # This wave's speed (randomized)
var current_wave_height: float = 100.0   # This wave's height (calculated from speed)
var critters_spawned_this_wave: bool = false  # Track if critters spawned to prevent double-spawning
var actual_peak_y: float = 0.0  # Store where wave actually peaked for retreat
var pause_timer: float = 0.0  # Timer for pause at peak

# Wave signals
signal wave_reached_peak(wave_rectangle: Rect2)

# Physics-based surge motion
var surge_velocity: float = 0.0          # Current surge velocity (pixels/second)
var surge_initial_velocity: float = 0.0  # Initial velocity when surge starts
var surge_deceleration: float = 0.0      # Constant deceleration rate

# Wave timing
var next_wave_time: float = 3.0      # When to spawn next wave

func _ready():
	# --- Setup sand tiling with Sprite2D ---
	var vp_size = get_viewport_rect().size
	
	# Setup sand for proper tiling
	sand.centered = false
	sand.position = Vector2.ZERO
	
	# Enable texture repeat mode for tiling
	sand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# Use region to tile the texture across the viewport
	sand.region_enabled = true
	sand.region_rect = Rect2(0, 0, vp_size.x, vp_size.y)
	
	# Keep sand at scale 1,1 since we're using region for tiling
	sand.scale = Vector2.ONE

	# Setup z-ordering: sand -> ocean -> wave -> foam
	sand.z_index = -30   # Bottom layer
	ocean.z_index = -20  # Static ocean background  
	wave.z_index = -10   # Dynamic wave layer
	foam.z_index = 10    # Foam on top
	
	# Setup static ocean with wave tail color
	var transparent_tex = _create_transparent_texture()
	ocean.texture = transparent_tex
	ocean.centered = false
	ocean.position = Vector2(0, shore_y)  # Start at baseline shore
	ocean.scale = Vector2(vp_size.x, vp_size.y - shore_y)  # Fill bottom half
	
	# Setup ocean shader with wave tail color
	var ocean_shader = load("res://stages/beach/shaders/ocean_background.gdshader")
	var ocean_material = ShaderMaterial.new()
	ocean_material.shader = ocean_shader
	ocean_material.set_shader_parameter("ocean_color", Color(wave_tail.r, wave_tail.g, wave_tail.b, 1.0))  # Wave tail color, fully opaque
	ocean.material = ocean_material
	
	# Setup dynamic wave and foam sprites
	_setup_shader_sprite(wave, transparent_tex, vp_size)
	_setup_shader_sprite(foam, transparent_tex, vp_size)

	# --- Initialize shader parameters ---
	var wmat := wave.material as ShaderMaterial
	var fmat := foam.material as ShaderMaterial
	
	# Set static shader parameters
	for m in [wmat, fmat]:
		m.set_shader_parameter("rect_size", vp_size)
		m.set_shader_parameter("shore_y", shore_y)
		m.set_shader_parameter("Rmax", get_computed_surge_height())
		m.set_shader_parameter("w", w)
		m.set_shader_parameter("k", k)
		m.set_shader_parameter("lock_vertical", lock_vertical)
	
	# Wave-specific parameters
	wmat.set_shader_parameter("wave_front", wave_front)
	wmat.set_shader_parameter("wave_tail", wave_tail)
	wmat.set_shader_parameter("refract_strength", refract_strength)
	var normalA := load(normalA_path) if normalA_path != "" else null
	var normalB := load(normalB_path) if normalB_path != "" else null
	if normalA: wmat.set_shader_parameter("normalA", normalA)
	if normalB: wmat.set_shader_parameter("normalB", normalB)
	
	# Foam-specific parameters
	fmat.set_shader_parameter("edge_width", foam_edge_width)
	fmat.set_shader_parameter("crest_offset", crest_offset)
	fmat.set_shader_parameter("foam_alpha", foam_alpha)
	var foamNoise := load(foamNoise_path) if foamNoise_path != "" else null
	if foamNoise: fmat.set_shader_parameter("foamNoise", foamNoise)
	
	# Initialize single wave system
	wave_position_y = shore_y
	wave_edge_y = shore_y
	wave_phase = "calm"
	next_wave_time = 3.0  # First wave in 3 seconds

	get_viewport().size_changed.connect(_on_size_changed)
	
	# Connect wave signal to spawner via beach mediation
	wave_reached_peak.connect(_on_wave_reached_peak)

func _process(delta: float):
	# Handle wave timing
	next_wave_time -= delta
	
	# Update single wave
	_update_single_wave(delta)
	
	# Critters are now permanent - no need for visibility updates or cleanup
	
	# Set shader values directly from single wave
	_current_edge_y = wave_edge_y
	_current_wave_alpha = wave_alpha
	_current_foam_alpha = wave_foam_alpha
	_current_wave_bottom_y = wave_position_y
	
	# Update shaders with computed wave properties
	_update_shader_parameters()
	
	# Sync debug visualization (disabled for production)
	# if debug:
	#	debug.shore_y = shore_y
	#	debug.Rmax = surge_height
	#	debug.w = w
	#	debug.k = k
	#	debug.lock_vertical = lock_vertical
	#	debug._current_edge_y = _current_edge_y

# Cache previous values to avoid unnecessary shader updates
var _prev_shore_y: float = -1
var _prev_surge_height: float = -1
var _prev_w: float = -1

# Current wave state for shader display
var _current_edge_y: float = 420.0
var _current_foam_alpha: float = 1.0
var _current_wave_alpha: float = 1.0
var _current_wave_bottom_y: float = 420.0

# ============================================================================
# SIMPLE SINGLE WAVE SYSTEM
# ============================================================================

func _update_single_wave(delta: float):
	match wave_phase:
		"calm":
			_update_calm_phase(delta)
		"traveling":
			_update_traveling_phase(delta)
		"surging":
			_update_surging_phase(delta)
		"pausing":
			_update_pausing_phase(delta)
		"retreating":
			_update_retreating_phase(delta)

func _update_calm_phase(delta: float):
	# Wait for next wave
	if next_wave_time <= 0.0:
		# Randomize wave properties for this new wave
		_randomize_wave_properties()
		
		# Start new wave off-screen
		var viewport_height = get_viewport_rect().size.y
		wave_position_y = viewport_height + current_wave_height * 1.5
		wave_edge_y = wave_position_y - current_wave_height
		wave_phase = "traveling"
		wave_phase_progress = 0.0
		wave_alpha = 1.0
		wave_foam_alpha = 1.0
		critters_spawned_this_wave = false  # Reset for new wave
		next_wave_time = 8.0  # Next wave in 8 seconds after this one completes

func _update_traveling_phase(delta: float):
	# Realistic wave physics: smooth speed changes based on water depth
	var distance_to_shore = wave_position_y - shore_y
	var current_speed: float
	
	# Create smooth speed curve using smoothstep for natural deceleration
	if distance_to_shore > 300.0:
		# Far from shore - full speed
		current_speed = current_wave_speed * 1.5
	else:
		# Smooth transition from fast (300px away) to slow (0px at shore)
		var distance_factor = clamp(distance_to_shore / 300.0, 0.0, 1.0)  # 1.0 to 0.0
		# Use smoothstep for natural curve (fast -> gradual slowdown -> slower at end)
		var speed_curve = smoothstep(0.0, 1.0, distance_factor)
		# Speed ranges from 0.7x (at shore) to 1.5x (far from shore)
		current_speed = current_wave_speed * lerp(0.7, 1.5, speed_curve)
	
	# Move wave toward shore
	var old_pos = wave_position_y
	wave_position_y -= current_speed * delta
	wave_edge_y = wave_position_y - current_wave_height
	
	# Check if wave has reached shore
	if wave_position_y <= shore_y:
		wave_phase = "surging"
		wave_phase_progress = 0.0
		wave_position_y = shore_y  # Lock to shore
		wave_edge_y = shore_y - current_wave_height  # Start surge from here
		
		# Initialize surge physics - transition from ocean velocity to deceleration on sand
		print("Wave transitioned to sand - will decelerate from velocity: ", current_wave_speed)

func _update_surging_phase(delta: float):
	# PURE PHYSICS - Only velocity and negative acceleration until natural stop
	
	# Simple physics: position = position + velocity * time, velocity = velocity + acceleration * time
	var acceleration = 200.0  # Constant positive acceleration (slows down upward movement)
	
	# Move wave edge by current velocity (negative velocity = upward movement)
	wave_edge_y += (-current_wave_speed) * delta
	
	# Apply acceleration to slow down the upward movement
	current_wave_speed -= acceleration * delta
	
	# Natural physics stop when velocity reaches zero
	if current_wave_speed <= 0:
		current_wave_speed = 0
		
		# Store actual peak position for retreat
		actual_peak_y = wave_edge_y
		
		# Emit signal with actual wave rectangle at peak
		var wave_rect = _get_wave_rectangle()
		if not critters_spawned_this_wave:
			critters_spawned_this_wave = true
			wave_reached_peak.emit(wave_rect)
			print("Wave reached natural peak at: ", wave_edge_y, " emitting rectangle: ", wave_rect)
		
		wave_phase = "pausing"
		pause_timer = 0.5  # Pause for half second at peak
		wave_phase_progress = 0.0
		return
	
	# Simple foam fade as wave slows down
	var speed_factor = current_wave_speed / wave_speed  # 1.0 to 0.0
	wave_foam_alpha = lerp(0.3, 1.0, speed_factor)

func _update_pausing_phase(delta: float):
	# Pause at peak for a moment
	pause_timer -= delta
	
	# Keep wave stationary at peak
	wave_edge_y = actual_peak_y
	
	# Gentle foam animation during pause
	wave_foam_alpha = 0.7 + 0.2 * sin(Time.get_time_dict_from_system()["second"] * 3.0)
	
	if pause_timer <= 0.0:
		wave_phase = "retreating"
		wave_phase_progress = 0.0
		print("Wave starting retreat from pause at: ", actual_peak_y)

func _update_retreating_phase(delta: float):
	# Calculate retreat progress (slower - takes 4 seconds to complete)
	var retreat_duration = 4.0  # Slower retreat after pause
	wave_phase_progress += delta / retreat_duration
	
	if wave_phase_progress >= 1.0:
		wave_phase = "calm"
		wave_phase_progress = 0.0
		wave_edge_y = shore_y
		wave_alpha = 0.15
		wave_foam_alpha = 0.15
		return
	
	# Smooth retreat movement (from actual peak back to shore)
	var retreat_factor = pow(wave_phase_progress, 1.2)
	# Use the stored actual peak position where the wave naturally stopped
	var retreat_start_y = actual_peak_y  # Actual peak position from physics
	var retreat_end_y = shore_y  # Shore baseline
	wave_edge_y = lerp(retreat_start_y, retreat_end_y, retreat_factor)
	
	# Fade out during retreat
	wave_alpha = lerp(1.0, 0.15, wave_phase_progress)
	wave_foam_alpha = lerp(1.0, 0.0, wave_phase_progress * 1.5)

# ============================================================================
# WAVE RANDOMIZATION
# ============================================================================

func _randomize_wave_properties():
	"""Randomize wave speed and calculate corresponding height"""
	if speed_randomization:
		# Randomize wave speed
		var speed_multiplier = randf_range(speed_variation_range.x, speed_variation_range.y)
		current_wave_speed = wave_speed * speed_multiplier
		
		# Calculate wave height based on speed (faster waves = taller waves)
		# Using physics relationship where height is related to wave energy/speed
		current_wave_height = wave_height * speed_multiplier
		
		print("New wave: Speed=", current_wave_speed, " (", speed_multiplier, "x), Height=", current_wave_height, " (calculated from speed)")
	else:
		# Use base values
		current_wave_speed = wave_speed
		current_wave_height = wave_height

func _get_wave_rectangle() -> Rect2:
	"""Get the actual wave rectangle at current position"""
	var viewport_width = get_viewport_rect().size.x
	var spawn_padding = 20.0  # Small padding from edges
	
	return Rect2(
		spawn_padding,
		wave_edge_y,
		viewport_width - (spawn_padding * 2),
		shore_y - wave_edge_y
	)

func _on_wave_reached_peak(wave_rectangle: Rect2):
	"""Beach mediates between wave signal and spawner"""
	if critter_spawner and critter_spawner.has_method("spawn_critters_in_rectangle"):
		critter_spawner.spawn_critters_in_rectangle(wave_rectangle)
	else:
		print("Warning: CritterSpawner doesn't have spawn_critters_in_rectangle method")

# ============================================================================
# PHYSICS-BASED SURGE CALCULATION
# ============================================================================

func get_computed_surge_height() -> float:
	# Physics-based surge height calculation using current wave's properties
	# Based on wave energy: E = 0.5 * speed^2 (simplified)
	# Faster waves have more energy and surge higher up the beach
	var base_surge = current_wave_speed * surge_multiplier
	
	# Add wave height influence (bigger waves surge higher)
	var height_factor = current_wave_height / 100.0  # Normalize to 100px baseline
	
	# Final surge height with realistic limits
	var computed_surge = base_surge * height_factor
	
	# Clamp to reasonable range (minimum 60px, maximum 350px - higher max for big waves)
	return clamp(computed_surge, 60.0, 350.0)

# ============================================================================
# CRITTER SPAWNING SYSTEM (Now handled by CritterSpawner)
# ============================================================================

# ============================================================================
# PUBLIC API - Simple wave control
# ============================================================================

# Trigger a new wave immediately
func trigger_wave():
	if wave_phase == "calm":
		next_wave_time = 0.0  # Start immediately

# Get current wave info
func get_wave_info() -> Dictionary:
	return {
		"phase": wave_phase,
		"progress": wave_phase_progress,
		"edge_y": wave_edge_y,
		"position_y": wave_position_y,
		"alpha": wave_alpha,
		"foam_alpha": wave_foam_alpha
	}

# Reset to calm state
func reset_wave():
	wave_phase = "calm"
	wave_phase_progress = 0.0
	wave_edge_y = shore_y
	wave_alpha = 0.15
	wave_foam_alpha = 0.15
	next_wave_time = 3.0

func _update_shader_parameters():
	# Pass the computed wave properties to shaders (single source of truth)
	var wmat := wave.material as ShaderMaterial
	var fmat := foam.material as ShaderMaterial
	
	# Set the computed wave properties to shaders
	wmat.set_shader_parameter("current_edge_y", _current_edge_y)
	wmat.set_shader_parameter("computed_water_alpha", _current_wave_alpha)
	wmat.set_shader_parameter("wave_bottom_y", _current_wave_bottom_y)
	fmat.set_shader_parameter("current_edge_y", _current_edge_y)
	fmat.set_shader_parameter("computed_foam_alpha", _current_foam_alpha)
	fmat.set_shader_parameter("wave_bottom_y", _current_wave_bottom_y)
	
	# Only update other parameters when they change  
	var computed_surge = get_computed_surge_height()
	var needs_update = (_prev_shore_y != shore_y or _prev_surge_height != computed_surge or _prev_w != w)
	if needs_update:
		for m in [wmat, fmat]:
			m.set_shader_parameter("shore_y", shore_y)
			m.set_shader_parameter("Rmax", computed_surge)  # Use computed surge height
			m.set_shader_parameter("w", w)
			m.set_shader_parameter("k", k)
			m.set_shader_parameter("lock_vertical", lock_vertical)
		wmat.set_shader_parameter("wave_front", wave_front)
		wmat.set_shader_parameter("wave_tail", wave_tail)
		wmat.set_shader_parameter("refract_strength", refract_strength)
		
		# Update ocean color to match wave tail
		var ocean_mat := ocean.material as ShaderMaterial
		if ocean_mat:
			ocean_mat.set_shader_parameter("ocean_color", Color(wave_tail.r, wave_tail.g, wave_tail.b, 1.0))
		fmat.set_shader_parameter("edge_width", foam_edge_width)
		fmat.set_shader_parameter("crest_offset", crest_offset)
		fmat.set_shader_parameter("foam_alpha", foam_alpha)
		
		# Cache values
		_prev_shore_y = shore_y
		_prev_surge_height = computed_surge
		_prev_w = w

# Helper functions for cleaner code
func _create_transparent_texture() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Fully transparent
	return ImageTexture.create_from_image(img)

func _setup_shader_sprite(sprite: Sprite2D, texture: ImageTexture, size: Vector2):
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = size

func _on_size_changed():
	var vp_size = get_viewport_rect().size
	
	# Update sand's region rect for tiling (don't change scale!)
	if sand:
		sand.region_rect = Rect2(0, 0, vp_size.x, vp_size.y)
	
	# Update ocean region for new viewport size
	if ocean:
		ocean.region_rect = Rect2(0, 0, vp_size.x, vp_size.y - shore_y)
	
	# Update wave/foam scales
	for s in [wave, foam]:
		s.scale = vp_size
	
	# Update shader parameters
	var wmat := wave.material as ShaderMaterial
	var fmat := foam.material as ShaderMaterial
	wmat.set_shader_parameter("rect_size", vp_size)
	fmat.set_shader_parameter("rect_size", vp_size)
