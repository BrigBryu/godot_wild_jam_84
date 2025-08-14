extends Node2D

@onready var sand      : Sprite2D = $Sand
@onready var ocean     : Sprite2D = $Ocean      # Static ocean background
@onready var wave      : Sprite2D = $Wave       # Dynamic wave (can spawn anywhere)
@onready var foam      : Sprite2D = $Foam       # Foam on the wave
@onready var debug     : Node2D = $ShorelineDebug

@export var shore_y: float = 420.0  # baseline shoreline position  
@export var Rmax: float = 120.0   # max run-up distance for natural waves
@export var w: float = 0.45
@export var k: float = 0.0
@export var lock_vertical: bool = true
@export var wave_front: Color = Color(0.08, 0.55, 0.62, 0.95)  # Front edge of wave (lighter blue-green)
@export var wave_tail: Color  = Color(0.05, 0.45, 0.58, 0.95)  # Tail edge of wave (slightly darker blue-green)
@export var refract_strength: float = 0.006
@export var foam_edge_width: float = 12.0
@export var crest_offset: float = 7.0
@export var foam_alpha: float = 0.85

@export var normalA_path: String = "res://stages/beach/art/water_normal_map_tileable_looped.jpeg"
@export var normalB_path: String = "res://stages/beach/art/water_normal_map_tileable_looped_more_wavy.jpeg"
@export var foamNoise_path: String = "res://stages/beach/art/foam.jpg"

# Wave State System
enum WaveState { ON_BEACH, ON_OCEAN }
@export var wave_state: WaveState = WaveState.ON_OCEAN
@export var ocean_wave_height: float = 100.0  # Fixed height for ocean waves
@export var wave_speed_multiplier: float = 1.0  # Controls wave travel speed (affects shore height)

# Physics-based ocean wave system
@export var physics_wave_enabled: bool = true
var ocean_wave_scene = preload("res://stages/beach/OceanWave.tscn")
var current_physics_wave: RigidBody2D = null
var physics_wave_active: bool = false

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

	# --- Wave shader uniforms (dynamic wave only) ---
	var wmat := wave.material as ShaderMaterial
	wmat.set_shader_parameter("rect_size", vp_size)
	wmat.set_shader_parameter("shore_y", shore_y)
	wmat.set_shader_parameter("Rmax", Rmax)
	wmat.set_shader_parameter("w", w)
	wmat.set_shader_parameter("k", k)
	wmat.set_shader_parameter("lock_vertical", lock_vertical)
	wmat.set_shader_parameter("wave_front", wave_front)
	wmat.set_shader_parameter("wave_tail", wave_tail)
	wmat.set_shader_parameter("refract_strength", refract_strength)
	var normalA := load(normalA_path) if normalA_path != "" else null
	var normalB := load(normalB_path) if normalB_path != "" else null
	if normalA: wmat.set_shader_parameter("normalA", normalA)
	if normalB: wmat.set_shader_parameter("normalB", normalB)

	# --- Foam uniforms ---
	var fmat := foam.material as ShaderMaterial
	fmat.set_shader_parameter("rect_size", vp_size)
	fmat.set_shader_parameter("shore_y", shore_y)
	fmat.set_shader_parameter("Rmax", Rmax)
	fmat.set_shader_parameter("w", w)
	fmat.set_shader_parameter("k", k)
	fmat.set_shader_parameter("lock_vertical", lock_vertical)
	fmat.set_shader_parameter("edge_width", foam_edge_width)
	fmat.set_shader_parameter("crest_offset", crest_offset)
	fmat.set_shader_parameter("foam_alpha", foam_alpha)
	var foamNoise := load(foamNoise_path) if foamNoise_path != "" else null
	if foamNoise: fmat.set_shader_parameter("foamNoise", foamNoise)

	get_viewport().size_changed.connect(_on_size_changed)

func _process(_dt):
	# Calculate ALL wave properties using time-based system (single source of truth)
	var time = Time.get_ticks_msec() / 1000.0
	var cycle_time = fmod(time, _total_cycle_time)
	
	# Update wave based on current state
	if wave_state == WaveState.ON_BEACH:
		_update_beach_wave(cycle_time)
	else:  # ON_OCEAN
		_update_simple_ocean_wave(cycle_time)
	
	# Update shaders with computed edge position
	_update_shader_parameters()
	
	# Sync debug visualization
	if debug:
		debug.shore_y = shore_y
		debug.Rmax = Rmax
		debug.w = w
		debug.k = k
		debug.lock_vertical = lock_vertical
		debug._current_edge_y = _current_edge_y  # Pass computed edge to debug

# Cache previous values to avoid unnecessary shader updates
var _prev_shore_y: float = -1
var _prev_Rmax: float = -1
var _prev_w: float = -1

# Single source of truth for wave timing
var _current_edge_y: float = 420.0
var _current_phase: float = 0.0
var _current_foam_alpha: float = 1.0
var _current_wave_alpha: float = 1.0

# Wave State System
var _current_wave_bottom_y: float = 420.0  # Bottom edge of wave

# Track actual surge end position for seamless retreat
var _actual_surge_end_position: float = 420.0

# TIME-BASED WAVE TIMING (much clearer!)
const UPRUSH_TIME = 1.0      # seconds to reach peak
const PEAK_HOLD_TIME = 0.3   # seconds at peak
const BACKWASH_TIME = 2.5    # seconds to retreat to baseline (slower!)
const CALM_TIME = 3.0        # seconds between waves

var _total_cycle_time = UPRUSH_TIME + PEAK_HOLD_TIME + BACKWASH_TIME + CALM_TIME

# SINGLE SOURCE OF TRUTH: All wave behavior computed here
func runup_from_time(cycle_time: float, R: float) -> float:
	if cycle_time < UPRUSH_TIME:
		# Uprush phase with slight deceleration as wave climbs higher
		var t = cycle_time / UPRUSH_TIME
		return pow(t, 0.8) * R  # Changed from 0.6 to 0.8 for more deceleration
	elif cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME:
		# Peak hold phase
		return R
	elif cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME + BACKWASH_TIME:
		# Backwash phase (slower retreat)
		var t = (cycle_time - UPRUSH_TIME - PEAK_HOLD_TIME) / BACKWASH_TIME
		return (1.0 - pow(t, 1.2)) * R
	else:
		# Calm phase
		return 0.0

func get_foam_alpha_from_time(cycle_time: float) -> float:
	if cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME:
		# Full strength during uprush and peak
		return 1.0
	elif cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME + BACKWASH_TIME:
		# Fade during backwash
		var t = (cycle_time - UPRUSH_TIME - PEAK_HOLD_TIME) / BACKWASH_TIME
		return lerp(1.0, 0.3, t)
	else:
		# Very faint during calm period
		return 0.15

func get_wave_alpha_from_time(cycle_time: float) -> float:
	if cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME:
		# Full strength during uprush and peak
		return 1.0
	elif cycle_time < UPRUSH_TIME + PEAK_HOLD_TIME + BACKWASH_TIME:
		# Fade during backwash
		var t = (cycle_time - UPRUSH_TIME - PEAK_HOLD_TIME) / BACKWASH_TIME
		return lerp(1.0, 0.15, t)  # Fade to subtle visibility
	else:
		# Subtle during calm period
		return 0.15

# Wave State Functions
func _update_beach_wave(cycle_time: float):
	# Original beach wave logic - wave drags up from shore baseline
	var r = runup_from_time(cycle_time, Rmax)
	_current_edge_y = shore_y - r
	_current_phase = cycle_time / _total_cycle_time
	_current_foam_alpha = get_foam_alpha_from_time(cycle_time)
	_current_wave_alpha = get_wave_alpha_from_time(cycle_time)
	_current_wave_bottom_y = shore_y  # Bottom always at shore baseline

func _update_ocean_wave(cycle_time: float):
	# Ocean wave - three distinct phases: travel → slow down → retreat
	var viewport_height = get_viewport_rect().size.y
	
	# Calculate ocean spawn position and shore height - start well off-screen
	var ocean_spawn_y = viewport_height + ocean_wave_height  # Start below viewport bottom
	var wave_speed = clamp(wave_speed_multiplier, 0.1, 3.0)  # Prevent extreme speeds
	var computed_shore_height = _calculate_shore_height_from_speed(wave_speed)
	
	# Three phase timing
	var travel_time = UPRUSH_TIME * 3.0  # Ocean travel phase (slower for more dramatic effect)
	var slowdown_time = PEAK_HOLD_TIME * 2.0  # Slowing down and surging phase
	var retreat_time = BACKWASH_TIME  # Use existing retreat logic
	
	if cycle_time < travel_time:
		# Phase 1: TRAVELING - Ocean wave moving toward shore
		var travel_progress = cycle_time / travel_time
		
		# Calculate base wave positions
		_current_wave_bottom_y = lerp(ocean_spawn_y, shore_y, travel_progress)
		var base_edge_y = _current_wave_bottom_y - ocean_wave_height
		
		# Calculate how close the water edge is to shore (smooth transition zone)
		var distance_to_shore = shore_y - base_edge_y
		var shore_approach_distance = ocean_wave_height * 0.8  # Start transition when edge is close
		
		if distance_to_shore <= shore_approach_distance:
			# Entering shore influence zone - gradual surge begins
			var approach_progress = clamp(1.0 - (distance_to_shore / shore_approach_distance), 0.0, 1.0)
			
			# Smooth surge curve that starts gently and builds up
			var smooth_surge_factor = smoothstep(0.0, 1.0, approach_progress)
			var surge_amount = smooth_surge_factor * computed_shore_height * 0.4  # Up to 40% early surge
			
			_current_edge_y = base_edge_y - surge_amount
		else:
			# Normal traveling wave - no surge yet
			_current_edge_y = base_edge_y
		
		# Full strength ocean wave
		_current_wave_alpha = 1.0
		_current_foam_alpha = 1.0
		
	elif cycle_time < travel_time + slowdown_time:
		# Phase 2: SLOWING_DOWN - Wave has reached shore, gradual transition to surge
		_current_wave_bottom_y = shore_y  # Bottom locked at shore
		
		var slowdown_cycle_time = cycle_time - travel_time
		var surge_progress = slowdown_cycle_time / slowdown_time
		
		# Gentler transition - start from where the traveling wave left off
		var travel_end_position = shore_y - ocean_wave_height  # Where traveling phase ended
		var target_surge_position = shore_y - computed_shore_height  # Where we want to end up
		
		# Use a gentler curve for more natural transition
		var gentle_curve = pow(surge_progress, 0.8)  # Slightly less dramatic than smoothstep
		_current_edge_y = lerp(travel_end_position, target_surge_position, gentle_curve)
		
		# Maintain full strength during surge
		_current_wave_alpha = 1.0
		_current_foam_alpha = 1.0
		
	else:
		# Phase 3: RETREATING - Use existing retreat logic (encapsulated and working great!)
		_current_wave_bottom_y = shore_y  # Bottom locked at shore
		
		var retreat_cycle_time = cycle_time - travel_time - slowdown_time
		var retreat_progress = clamp(retreat_cycle_time / retreat_time, 0.0, 1.0)
		
		# Use the same retreat math as the working beach wave system
		var retreat_amount = pow(retreat_progress, 1.2) * computed_shore_height
		_current_edge_y = shore_y - computed_shore_height + retreat_amount
		
		# Use the same alpha fade as the working beach wave system
		_current_wave_alpha = lerp(1.0, 0.15, retreat_progress)
		_current_foam_alpha = lerp(1.0, 0.3, retreat_progress)
		
		# Handle calm phase
		if retreat_cycle_time > retreat_time:
			_current_edge_y = shore_y
			_current_wave_alpha = 0.15
			_current_foam_alpha = 0.15
	
	_current_phase = cycle_time / _total_cycle_time

# Simple ocean wave - travel to shore, then use beach wave logic
func _update_simple_ocean_wave(cycle_time: float):
	var computed_shore_height = _calculate_shore_height_from_speed(wave_speed_multiplier)
	var viewport_height = get_viewport_rect().size.y
	var ocean_spawn_y = viewport_height + ocean_wave_height  # Start below viewport bottom
	
	# Split into two simple phases: travel then beach behavior
	var travel_time = UPRUSH_TIME * 2.5  # Time to travel from ocean to shore (slower)
	var beach_behavior_time = _total_cycle_time - travel_time  # Remaining time for beach behavior
	
	if cycle_time < travel_time:
		# Phase 1: Simple linear travel from ocean spawn to shore
		var travel_progress = cycle_time / travel_time
		_current_wave_bottom_y = lerp(ocean_spawn_y, shore_y, travel_progress)
		_current_edge_y = _current_wave_bottom_y - ocean_wave_height
		
		_current_wave_alpha = 1.0
		_current_foam_alpha = 1.0
		
		if Engine.get_process_frames() % 60 == 0:
			print("TRAVEL PHASE - progress: ", "%.2f" % travel_progress, ", edge_y: ", "%.1f" % _current_edge_y)
		
	else:
		# Phase 2: Use beach wave logic BUT start from where travel ended
		_current_wave_bottom_y = shore_y
		
		# Calculate where travel phase ended
		var travel_end_edge_y = shore_y - ocean_wave_height
		
		# Adjust cycle time for beach behavior (start from 0 when hitting shore)
		var beach_cycle_time = cycle_time - travel_time
		
		# Use the proven beach wave runup function
		var r = runup_from_time(beach_cycle_time, computed_shore_height)
		
		# Calculate target positions
		var surge_peak_y = travel_end_edge_y - computed_shore_height  # Highest point wave reaches
		var current_surge_y = travel_end_edge_y - r  # Current position from runup function
		
		# Smooth interpolation to ensure wave reaches shore baseline
		if beach_cycle_time >= UPRUSH_TIME + PEAK_HOLD_TIME + BACKWASH_TIME:
			# Calm phase - ensure we're exactly at shore baseline
			_current_edge_y = shore_y
		elif beach_cycle_time >= UPRUSH_TIME + PEAK_HOLD_TIME:
			# Backwash phase - smooth retreat from current position toward shore
			var backwash_time = beach_cycle_time - UPRUSH_TIME - PEAK_HOLD_TIME
			var backwash_progress = backwash_time / BACKWASH_TIME
			
			# Calculate where we should be based on smooth retreat
			var retreat_start_y = travel_end_edge_y - computed_shore_height  # Peak position
			var smooth_retreat_y = lerp(retreat_start_y, shore_y, pow(backwash_progress, 1.2))
			
			_current_edge_y = smooth_retreat_y
		else:
			# Uprush and peak phases - use normal runup calculation
			_current_edge_y = current_surge_y
		
		# Aggressive foam fade during retreat
		if beach_cycle_time >= UPRUSH_TIME + PEAK_HOLD_TIME:
			# During backwash - foam fades quickly based on retreat progress
			var backwash_time = beach_cycle_time - UPRUSH_TIME - PEAK_HOLD_TIME
			var backwash_progress = clamp(backwash_time / BACKWASH_TIME, 0.0, 1.0)
			
			# Aggressive fade: mostly gone at 50% retreat, completely gone at 100%
			if backwash_progress < 0.5:
				# First half of retreat: fade from 1.0 to 0.1 (mostly gone)
				_current_foam_alpha = lerp(1.0, 0.1, backwash_progress * 2.0)
			else:
				# Second half of retreat: fade from 0.1 to 0.0 (completely gone)
				_current_foam_alpha = lerp(0.1, 0.0, (backwash_progress - 0.5) * 2.0)
		else:
			# During uprush and peak - full foam visibility
			_current_foam_alpha = 1.0
		
		# Water stays visible until it reaches shore baseline
		if _current_edge_y >= shore_y:
			# Wave has retreated to shore - water can fade
			_current_wave_alpha = get_wave_alpha_from_time(beach_cycle_time)
		else:
			# Wave is still above shore - keep water fully visible
			_current_wave_alpha = 1.0
		
		if Engine.get_process_frames() % 60 == 0:
			print("BEACH PHASE - beach_time: ", "%.2f" % beach_cycle_time, ", travel_end: ", "%.1f" % travel_end_edge_y, ", runup: ", "%.1f" % r, ", edge_y: ", "%.1f" % _current_edge_y)
	
	_current_phase = cycle_time / _total_cycle_time

# Calculate shore height based on wave speed using realistic wave physics
func _calculate_shore_height_from_speed(speed: float) -> float:
	# Based on shallow water wave theory: run-up height increases with wave speed
	# Formula inspired by: R = H * sqrt(speed) where R is run-up, H is base height
	
	var base_height = Rmax  # Use the base Rmax as reference
	
	# Speed-to-height relationship (non-linear for realism)
	var speed_factor: float
	if speed <= 0.5:
		# Very slow waves - minimal shore height
		speed_factor = speed * 0.4
	elif speed <= 1.0:
		# Normal speed waves - linear relationship
		speed_factor = 0.2 + (speed - 0.5) * 1.6  # Maps 0.5-1.0 to 0.2-1.0
	elif speed <= 2.0:
		# Fast waves - enhanced height with square root scaling
		var excess_speed = speed - 1.0
		speed_factor = 1.0 + sqrt(excess_speed) * 0.8  # Gradual increase for fast waves
	else:
		# Very fast waves - diminishing returns (wave breaks before reaching shore)
		var excess_speed = speed - 2.0
		speed_factor = 1.8 + excess_speed * 0.2  # Slower increase for very fast waves
	
	# Apply ocean wave height influence (bigger ocean waves = bigger shore surge)
	var wave_height_factor = ocean_wave_height / 100.0  # Normalize to 100px baseline
	
	# Final computed height with realistic constraints
	var computed_height = base_height * speed_factor * wave_height_factor
	
	# Clamp to reasonable limits (prevent unrealistic extremes)
	return clamp(computed_height, base_height * 0.1, base_height * 3.0)

func _update_shader_parameters():
	# Pass the computed wave properties to shaders (single source of truth)
	var wmat := wave.material as ShaderMaterial  # Now using 'wave'
	var fmat := foam.material as ShaderMaterial
	
	# Set the computed wave properties to shaders
	wmat.set_shader_parameter("current_edge_y", _current_edge_y)
	wmat.set_shader_parameter("computed_water_alpha", _current_wave_alpha)  # Wave fades to 0.15
	wmat.set_shader_parameter("wave_bottom_y", _current_wave_bottom_y)  # Wave bottom boundary
	fmat.set_shader_parameter("current_edge_y", _current_edge_y)
	fmat.set_shader_parameter("computed_foam_alpha", _current_foam_alpha)  # Foam fades to 0.15
	fmat.set_shader_parameter("wave_bottom_y", _current_wave_bottom_y)  # Wave bottom boundary
	
	# Only update other parameters when they change
	var needs_update = (_prev_shore_y != shore_y or _prev_Rmax != Rmax or _prev_w != w)
	if needs_update:
		for m in [wmat, fmat]:
			m.set_shader_parameter("shore_y", shore_y)
			m.set_shader_parameter("Rmax", Rmax)
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
		_prev_Rmax = Rmax
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
	var wmat := wave.material as ShaderMaterial  # Now using 'wave'
	var fmat := foam.material as ShaderMaterial
	wmat.set_shader_parameter("rect_size", vp_size)
	fmat.set_shader_parameter("rect_size", vp_size)
