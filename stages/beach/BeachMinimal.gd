extends Node2D

# Wave state management
var wave_state: WaveState

# All constants now centralized in GameConstants class

@onready var sand      : Sprite2D = $Sand
@onready var ocean     : Sprite2D = $Ocean      # Static ocean background
@onready var wave      : Sprite2D = $Wave       # Dynamic wave (can spawn anywhere)
@onready var foam      : Sprite2D = $Foam       # Foam on the wave
# Debug node disabled for production
# @onready var debug     : Node2D = $ShorelineDebug

@export var shore_y: float = GameConstants.SHORE_Y  # Y position where ocean meets sand (pixels from top)
@export var Rmax: float = GameConstants.DEFAULT_SURGE_DISTANCE  # Maximum wave run-up distance (pixels)
@export var w: float = 0.45  # Wave shape parameter (0-1, affects curvature)
@export var k: float = 0.0  # Wave skew parameter (affects asymmetry)
@export var lock_vertical: bool = true
@export var wave_front: Color = Color(0.08, 0.55, 0.62, 0.85)  # Front edge of wave (lighter blue-green, more transparent)
@export var wave_tail: Color  = Color(0.04, 0.42, 0.56, 0.98)  # Tail edge of wave (darker blue-green, less transparent)
@export var refract_strength: float = 0.006  # Water refraction shader strength (0-1)
@export var foam_edge_width: float = GameConstants.FOAM_EDGE_WIDTH  # Width of foam edge in pixels
@export var crest_offset: float = GameConstants.FOAM_CREST_OFFSET  # Foam offset from wave crest in pixels
@export var foam_alpha: float = 0.85  # Maximum foam opacity (0-1)

@export var normalA_path: String = "res://stages/beach/art/water_normal_map_tileable_looped.jpeg"
@export var normalB_path: String = "res://stages/beach/art/water_normal_map_tileable_looped_more_wavy.jpeg"
@export var foamNoise_path: String = "res://stages/beach/art/foam.jpg"

# Simple Speed-based Wave System
@export_group("Wave Properties")
@export var wave_height: float = GameConstants.DEFAULT_WAVE_HEIGHT  # Wave height in pixels
@export var wave_speed: float = GameConstants.DEFAULT_WAVE_SPEED  # Base wave speed in pixels/second
@export var surge_multiplier: float = 1.4  # How much wave speed affects surge height (physics-based)

@export_group("Wave Randomization")
@export var speed_randomization: bool = true  # Enable random wave speeds
@export var speed_variation_range: Vector2 = Vector2(GameConstants.WAVE_SPEED_MIN_MULTIPLIER, GameConstants.WAVE_SPEED_MAX_MULTIPLIER)  # Min/max speed multipliers

# Critter spawner (replaces old starfish system)
@onready var critter_spawner: CritterSpawner = $CritterSpawner
# Game timer for managing game duration
@onready var game_timer: Node = $GameTimer
# Wave collision area
@onready var wave_area: WaveArea = $WaveArea

# Single wave state
var wave_position_y: float = 0.0     # Current Y position of wave bottom
var wave_phase: GameConstants.WavePhase = GameConstants.WavePhase.CALM
var wave_phase_progress: float = 0.0 # Progress within current phase (0.0 to 1.0)
var wave_edge_y: float = GameConstants.SHORE_Y       # Current wave edge (top) position
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
	_initialize_wave_state()
	_setup_sand_tiling()
	_setup_ocean_background()
	_setup_wave_and_foam_sprites()
	_initialize_shader_parameters()
	_initialize_wave_system()
	_connect_signals_and_start_game()

func _initialize_wave_state() -> void:
	"""Initialize wave state configuration"""
	wave_state = WaveState.new()
	wave_state.shore_y = shore_y
	wave_state.surge_height = Rmax

func _setup_sand_tiling() -> void:
	"""Configure sand sprite for proper world tiling"""
	var world_size = Vector2(GameConstants.SCREEN_WIDTH, GameConstants.SCREEN_HEIGHT)
	
	sand.centered = false
	sand.position = Vector2.ZERO
	sand.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sand.region_enabled = true
	sand.region_rect = Rect2(0, 0, world_size.x, world_size.y)
	sand.scale = Vector2.ONE
	sand.z_index = -30  # Bottom layer

func _setup_ocean_background() -> void:
	"""Configure static ocean background with shader"""
	var world_size = Vector2(GameConstants.SCREEN_WIDTH, GameConstants.SCREEN_HEIGHT)
	var transparent_tex = _create_transparent_texture()
	
	# Setup z-ordering
	ocean.z_index = -20  # Static ocean background
	wave.z_index = -10   # Dynamic wave layer
	foam.z_index = 10    # Foam on top
	
	# Configure ocean sprite
	ocean.texture = transparent_tex
	ocean.centered = false
	ocean.position = Vector2(0, shore_y)
	ocean.scale = Vector2(world_size.x, world_size.y - shore_y)
	
	# Setup ocean shader
	var ocean_shader = load("res://stages/beach/shaders/ocean_background.gdshader")
	var ocean_material = ShaderMaterial.new()
	ocean_material.shader = ocean_shader
	ocean_material.set_shader_parameter("ocean_color", Color(wave_tail.r, wave_tail.g, wave_tail.b, 1.0))
	ocean.material = ocean_material

func _setup_wave_and_foam_sprites() -> void:
	"""Setup dynamic wave and foam sprite materials"""
	var world_size = Vector2(GameConstants.SCREEN_WIDTH, GameConstants.SCREEN_HEIGHT)
	var transparent_tex = _create_transparent_texture()
	
	_setup_shader_sprite(wave, transparent_tex, world_size)
	_setup_shader_sprite(foam, transparent_tex, world_size)

func _initialize_shader_parameters() -> void:
	"""Configure all shader parameters for wave and foam materials"""
	var world_size = Vector2(GameConstants.SCREEN_WIDTH, GameConstants.SCREEN_HEIGHT)
	var wmat := wave.material as ShaderMaterial
	var fmat := foam.material as ShaderMaterial
	
	_set_common_shader_parameters(wmat, fmat, world_size)
	_set_wave_shader_parameters(wmat)
	_set_foam_shader_parameters(fmat)

func _set_common_shader_parameters(wmat: ShaderMaterial, fmat: ShaderMaterial, vp_size: Vector2) -> void:
	"""Set shared parameters for both wave and foam shaders"""
	for m in [wmat, fmat]:
		m.set_shader_parameter("rect_size", vp_size)
		m.set_shader_parameter("shore_y", shore_y)
		m.set_shader_parameter("Rmax", get_computed_surge_height())
		m.set_shader_parameter("w", w)
		m.set_shader_parameter("k", k)
		m.set_shader_parameter("lock_vertical", lock_vertical)

func _set_wave_shader_parameters(wmat: ShaderMaterial) -> void:
	"""Configure wave-specific shader parameters"""
	wmat.set_shader_parameter("wave_front", wave_front)
	wmat.set_shader_parameter("wave_tail", wave_tail)
	wmat.set_shader_parameter("refract_strength", refract_strength)
	
	var normalA: Resource = load(normalA_path) if normalA_path != "" else null
	var normalB: Resource = load(normalB_path) if normalB_path != "" else null
	if normalA:
		wmat.set_shader_parameter("normalA", normalA)
	if normalB:
		wmat.set_shader_parameter("normalB", normalB)

func _set_foam_shader_parameters(fmat: ShaderMaterial) -> void:
	"""Configure foam-specific shader parameters"""
	fmat.set_shader_parameter("edge_width", foam_edge_width)
	fmat.set_shader_parameter("crest_offset", crest_offset)
	fmat.set_shader_parameter("foam_alpha", foam_alpha)
	
	var foamNoise: Resource = load(foamNoise_path) if foamNoise_path != "" else null
	if foamNoise:
		fmat.set_shader_parameter("foamNoise", foamNoise)

func _initialize_wave_system() -> void:
	"""Initialize wave system state and connections"""
	wave_position_y = shore_y
	wave_edge_y = shore_y
	wave_phase = GameConstants.WavePhase.CALM
	next_wave_time = 3.0  # First wave in 3 seconds
	
	if wave_area:
		wave_area.wave_state = wave_state
		SignalBus.wave_area_ready.emit(wave_area)

func _connect_signals_and_start_game() -> void:
	"""Connect signals and start the game timer"""
	get_viewport().size_changed.connect(_on_size_changed)
	wave_reached_peak.connect(_on_wave_reached_peak)
	
	if game_timer:
		await get_tree().create_timer(0.5).timeout
		game_timer.start_timer()

func _process(delta: float):
	_update_wave_timing(delta)
	_update_single_wave(delta)
	_update_wave_state_tracking()
	_update_wave_area_collision()
	_update_shader_display_values()

func _update_wave_timing(delta: float) -> void:
	"""Handle wave timing progression"""
	next_wave_time -= delta

func _update_wave_state_tracking() -> void:
	"""Update wave state object with current wave properties"""
	if wave_state:
		wave_state.update_position(wave_edge_y, wave_position_y)
		wave_state.alpha = wave_alpha
		wave_state.foam_alpha = wave_foam_alpha
		wave_state.update_bounds(get_viewport_rect().size.x)

func _update_wave_area_collision() -> void:
	"""Update wave area collision shape to match visual wave"""
	if not wave_area:
		return
		
	var world_width = GameConstants.SCREEN_WIDTH
	var visible_wave_height = wave_position_y - wave_edge_y
	
	if visible_wave_height > 0 and wave_phase != GameConstants.WavePhase.CALM:
		var wave_bounds = Rect2(0, wave_edge_y, world_width, visible_wave_height)
		wave_area.update_collision_shape(wave_bounds)
	elif wave_phase == GameConstants.WavePhase.CALM:
		# Minimal collision area when calm
		var wave_bounds = Rect2(0, shore_y - 50, world_width, 100)
		wave_area.update_collision_shape(wave_bounds)

func _update_shader_display_values() -> void:
	"""Set current wave values for shader rendering"""
	_current_edge_y = wave_edge_y
	_current_wave_alpha = wave_alpha
	_current_foam_alpha = wave_foam_alpha
	_current_wave_bottom_y = wave_position_y
	
	# Update shaders with computed wave properties
	_update_shader_parameters()

# Cache previous values to avoid unnecessary shader updates
var _prev_shore_y: float = -1
var _prev_surge_height: float = -1
var _prev_w: float = -1

# Current wave state for shader display
var _current_edge_y: float = GameConstants.SHORE_Y
var _current_foam_alpha: float = 1.0
var _current_wave_alpha: float = 1.0
var _current_wave_bottom_y: float = GameConstants.SHORE_Y

# ============================================================================
# SIMPLE SINGLE WAVE SYSTEM
# ============================================================================

func _update_single_wave(delta: float):
	match wave_phase:
		GameConstants.WavePhase.CALM:
			_update_calm_phase(delta)
		GameConstants.WavePhase.TRAVELING:
			_update_traveling_phase(delta)
		GameConstants.WavePhase.SURGING:
			_update_surging_phase(delta)
		GameConstants.WavePhase.PAUSING:
			_update_pausing_phase(delta)
		GameConstants.WavePhase.RETREATING:
			_update_retreating_phase(delta)

func _update_calm_phase(_delta: float):
	# Wait for next wave
	if next_wave_time <= 0.0:
		# Randomize wave properties for this new wave
		_randomize_wave_properties()
		
		# Start new wave off-screen
		var world_height = GameConstants.SCREEN_HEIGHT
		wave_position_y = world_height + current_wave_height * 1.5
		wave_edge_y = wave_position_y - current_wave_height
		wave_phase = GameConstants.WavePhase.TRAVELING
		wave_phase_progress = 0.0
		wave_alpha = 1.0
		wave_foam_alpha = 1.0
		critters_spawned_this_wave = false  # Reset for new wave
		next_wave_time = 8.0  # Next wave in 8 seconds after this one completes
		
		# Update wave state
		if wave_state:
			wave_state.set_phase(GameConstants.WavePhase.TRAVELING)

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
		# Speed ranges from min multiplier (at shore) to max multiplier (far from shore)
		current_speed = current_wave_speed * lerp(GameConstants.WAVE_SPEED_MIN_MULTIPLIER, GameConstants.WAVE_SPEED_MAX_MULTIPLIER, speed_curve)
	
	# Move wave toward shore
	wave_position_y -= current_speed * delta
	wave_edge_y = wave_position_y - current_wave_height
	
	# Check if wave has reached shore
	if wave_position_y <= shore_y:
		wave_phase = GameConstants.WavePhase.SURGING
		wave_phase_progress = 0.0
		wave_position_y = shore_y  # Lock to shore
		wave_edge_y = shore_y - current_wave_height  # Start surge from here
		
		# Update wave state
		if wave_state:
			wave_state.set_phase(GameConstants.WavePhase.SURGING)
		
		# Initialize surge physics - transition from ocean velocity to deceleration on sand

func _update_surging_phase(delta: float):
	# PURE PHYSICS - Only velocity and negative acceleration until natural stop
	
	# Simple physics: position = position + velocity * time, velocity = velocity + acceleration * time
	var acceleration: float = GameConstants.SURGE_DECELERATION  # Constant positive acceleration (slows down upward movement)
	
	# Move wave edge by current velocity (negative velocity = upward movement)
	wave_edge_y += (-current_wave_speed) * delta
	
	# Apply acceleration to slow down the upward movement
	current_wave_speed -= acceleration * delta
	
	# Natural physics stop when velocity reaches zero
	if current_wave_speed <= 0:
		current_wave_speed = 0
		
		# Store actual peak position for retreat
		actual_peak_y = wave_edge_y
		
		#print("🌊🔝 WAVE PEAK REACHED at Y=%.1f" % wave_edge_y)
		
		# Emit signal with actual wave rectangle at peak
		var wave_rect = _get_wave_rectangle()
		if not critters_spawned_this_wave:
			critters_spawned_this_wave = true
			wave_reached_peak.emit(wave_rect)
		
		wave_phase = GameConstants.WavePhase.PAUSING
		pause_timer = GameConstants.WAVE_PAUSE_DURATION  # Pause at peak
		wave_phase_progress = 0.0
		
		# Update wave state
		if wave_state:
			wave_state.set_phase(GameConstants.WavePhase.PAUSING)
		return
	
	# Simple foam fade as wave slows down
	var speed_factor = current_wave_speed / wave_speed  # 1.0 to 0.0
	wave_foam_alpha = lerp(GameConstants.WAVE_FOAM_FADE_MIN, GameConstants.WAVE_FOAM_FADE_MAX, speed_factor)

func _update_pausing_phase(delta: float):
	# Pause at peak for a moment
	pause_timer -= delta
	
	# Keep wave stationary at peak
	wave_edge_y = actual_peak_y
	wave_position_y = shore_y  # Keep bottom at shore line
	
	# Gentle foam animation during pause
	wave_foam_alpha = 0.7 + 0.2 * sin(Time.get_time_dict_from_system()["second"] * GameConstants.WAVE_FOAM_ANIMATION_SPEED)
	
	if pause_timer <= 0.0:
		#print("🌊⬇️ WAVE RETREATING from Y=%.1f" % actual_peak_y)
		wave_phase = GameConstants.WavePhase.RETREATING
		wave_phase_progress = 0.0
		
		# Update wave state
		if wave_state:
			wave_state.set_phase(GameConstants.WavePhase.RETREATING)

func _update_retreating_phase(delta: float):
	# Calculate retreat progress
	var retreat_duration: float = GameConstants.WAVE_RETREAT_DURATION  # Time for wave to retreat
	wave_phase_progress += delta / retreat_duration
	
	if wave_phase_progress >= 1.0:
		wave_phase = GameConstants.WavePhase.CALM
		wave_phase_progress = 0.0
		wave_edge_y = shore_y
		wave_alpha = 0.15
		wave_foam_alpha = 0.15
		
		# Update wave state
		if wave_state:
			wave_state.set_phase(GameConstants.WavePhase.CALM)
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
	else:
		# Use base values
		current_wave_speed = wave_speed
		current_wave_height = wave_height

func _get_wave_rectangle() -> Rect2:
	"""Get the actual wave rectangle at current position"""
	var world_width = GameConstants.SCREEN_WIDTH
	var spawn_padding: float = GameConstants.SPAWN_EDGE_PADDING  # Padding from edges
	
	return Rect2(
		spawn_padding,
		wave_edge_y,
		world_width - (spawn_padding * 2),
		shore_y - wave_edge_y
	)

func _on_wave_reached_peak(wave_rectangle: Rect2) -> void:
	"""Emit wave peak through SignalBus for decoupled spawning"""
	# Use SignalBus instead of direct spawner reference
	SignalBus.wave_peak_reached.emit(wave_rectangle)

# Removed _on_game_started - signal no longer exists
# Wave system resets in _ready() instead

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
	if wave_phase == GameConstants.WavePhase.CALM:
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
	wave_phase = GameConstants.WavePhase.CALM
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

func _on_size_changed() -> void:
	var world_size = Vector2(GameConstants.SCREEN_WIDTH, GameConstants.SCREEN_HEIGHT)
	
	# Update sand's region rect for tiling (don't change scale!)
	if sand:
		sand.region_rect = Rect2(0, 0, world_size.x, world_size.y)
	
	# Update ocean region for new world size
	if ocean:
		ocean.region_rect = Rect2(0, 0, world_size.x, world_size.y - shore_y)
	
	# Update wave/foam scales
	for s in [wave, foam]:
		s.scale = world_size
	
	# Update shader parameters
	var wmat := wave.material as ShaderMaterial
	var fmat := foam.material as ShaderMaterial
	wmat.set_shader_parameter("rect_size", world_size)
	fmat.set_shader_parameter("rect_size", world_size)
