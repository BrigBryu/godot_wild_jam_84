class_name CritterSpawner
extends Node2D

# Generic organism spawning system for wave-based spawning

@export var spawning_enabled: bool = true
@export var spawn_chance: float = 0.3  # Chance per wave to spawn organisms (0.0 to 1.0)
@export var spawn_count_range: Vector2i = Vector2i(1, 3)  # Min/max organisms per wave

# Organism scene paths - much simpler now
@export var organism_scenes: Array[String] = []

# Spawn zone configuration (between water max and shore)
@export var spawn_zone_padding: float = 160.0  # 8x scaled - Distance from edges to avoid spawning
@export var organism_spacing: float = 400.0  # 8x scaled - Minimum distance between organisms
@export var max_spawn_attempts: int = 20  # Max attempts to find a non-overlapping position

# Critters are now permanently visible - no fade animation needed

# Debug settings
@export var debug_spawning: bool = false  # Show debug info
@export var debug_draw_spawn_zone: bool = false  # Draw spawn zone rectangle

# Note: Critter sizing is now managed by each critter individually

# Internal state
var active_organisms: Array[Node2D] = []
var beach_scene: Node2D  # Reference to beach scene
var viewport_size: Vector2

# Debug state
var debug_spawn_zone_rect: Rect2 = Rect2()
var last_spawn_attempt: bool = false
var spawn_attempts: int = 0
var successful_spawns: int = 0


func _ready():
	# Get reference to beach scene (parent)
	beach_scene = get_parent()
	viewport_size = get_viewport().get_visible_rect().size
	
	# Set up default organism scenes if none provided
	if organism_scenes.is_empty():
		_setup_default_scenes()
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Connect to wave peak signal through SignalBus for decoupled spawning
	if SignalBus.has_signal("wave_peak_reached"):
		SignalBus.wave_peak_reached.connect(spawn_organisms_in_rectangle)

func _setup_default_scenes():
	"""Set up default organism scene paths"""
	organism_scenes = [
		"res://entities/organisms/starfish/starfish_simple.tscn",
		"res://entities/organisms/crab/crab_simple.tscn"
	]

func should_spawn_organisms() -> bool:
	"""Check if organisms should spawn this wave"""
	return spawning_enabled and randf() < spawn_chance

# Removed _update_debug_spawn_zone - using signal-based rectangle system

func spawn_organisms_in_rectangle(spawn_rectangle: Rect2):
	"""Spawn organisms in the given rectangle - clean, simple, signal-based"""
	# Update debug state for drawing
	debug_spawn_zone_rect = spawn_rectangle
	spawn_attempts += 1
	
	
	# Force redraw to show the rectangle
	if debug_draw_spawn_zone:
		queue_redraw()
	
	last_spawn_attempt = should_spawn_organisms()
	if not last_spawn_attempt:
		return
	
	var count = randi_range(spawn_count_range.x, spawn_count_range.y)
	
	var new_organisms: Array[Node2D] = []
	
	# Simple spawning - organisms handle their own setup
	for i in range(count):
		var organism = _create_random_organism()
		if organism:
			# Add to scene tree - _ready() handles all setup automatically
			add_child(organism)
			
			# Position in the spawn rectangle
			_position_organism_in_rectangle(organism, spawn_rectangle)
			
			new_organisms.append(organism)
			active_organisms.append(organism)
			successful_spawns += 1

func _create_random_organism() -> Node2D:
	"""Create a random organism based on spawn weights"""
	if organism_scenes.is_empty():
		push_warning("No organism scenes available for spawning")
		return null
	
	# Simple random selection - no complex weights needed
	var random_scene = organism_scenes[randi() % organism_scenes.size()]
	return _instantiate_organism_from_path(random_scene)

func _instantiate_organism_from_path(scene_path: String) -> Node2D:
	"""Instantiate an organism from its scene path"""
	if not ResourceLoader.exists(scene_path):
		push_error("Organism scene not found: " + scene_path)
		return null
	
	var organism_scene = load(scene_path)
	if not organism_scene:
		push_error("Failed to load organism scene: " + scene_path)
		return null
	
	var organism = organism_scene.instantiate()
	if not organism:
		push_error("Failed to instantiate organism from: " + scene_path)
		return null
	
	# Set a unique name
	var scene_name = scene_path.get_file().get_basename()
	organism.name = scene_name + "_" + str(randi())
	return organism

func _position_organism_in_rectangle(organism: Node2D, rect: Rect2):
	"""Position organism randomly within the rectangle, avoiding overlaps"""
	var attempts = 0
	var valid_position = false
	var final_position = Vector2.ZERO
	
	while not valid_position and attempts < max_spawn_attempts:
		# Generate random position within rectangle
		var x_pos = randf_range(rect.position.x, rect.position.x + rect.size.x)
		var y_pos = randf_range(rect.position.y, rect.position.y + rect.size.y)
		var test_position = Vector2(x_pos, y_pos)
		
		# Check if this position overlaps with existing organisms
		if _is_position_clear(test_position):
			final_position = test_position
			valid_position = true
		
		attempts += 1
	
	# If we couldn't find a clear position, use the last attempt
	if not valid_position:
		final_position = Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
	
	# Position the organism - simple and clean
	organism.global_position = final_position
	
	# Reset physics state for clean spawning
	if organism is RigidBody2D:
		organism.linear_velocity = Vector2.ZERO
		organism.angular_velocity = 0.0
		organism.sleeping = false

func _is_position_clear(test_position: Vector2) -> bool:
	"""Check if a position is clear of other organisms"""
	for existing_organism in active_organisms:
		if is_instance_valid(existing_organism):
			var distance = test_position.distance_to(existing_organism.position)
			if distance < organism_spacing:
				return false
	return true

# Scale and transparency are now handled by each critter's setup_for_spawning() method

# Critters are now permanent - no visibility management needed

func clear_all_organisms():
	"""Clear all active organisms immediately"""
	for organism in active_organisms:
		if is_instance_valid(organism):
			organism.queue_free()
	active_organisms.clear()

func get_active_organism_count() -> int:
	"""Get number of currently active organisms"""
	return active_organisms.size()

func _draw():
	"""Draw debug information - simplified for signal-based system"""
	if not debug_draw_spawn_zone or not debug_spawning:
		return
		
	if debug_spawn_zone_rect.size.x > 0 and debug_spawn_zone_rect.size.y > 0:
		# Draw wave rectangle (actual bounds from signal)
		draw_rect(debug_spawn_zone_rect, Color.YELLOW, false, 3.0)
		
		# Draw spawn zone fill (semi-transparent)
		draw_rect(debug_spawn_zone_rect, Color(Color.YELLOW.r, Color.YELLOW.g, Color.YELLOW.b, 0.1), true)
		
		# Draw debug text
		var debug_text = "Wave Rectangle\nAttempts: %d | Successful: %d\nLast attempt: %s" % [
			spawn_attempts, successful_spawns, 
			"YES" if last_spawn_attempt else "NO"
		]
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(10, 30), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _process(_delta):
	"""Update debug drawing"""
	if debug_draw_spawn_zone and debug_spawning:
		queue_redraw()

func _on_viewport_size_changed():
	"""Handle viewport size changes"""
	viewport_size = get_viewport().get_visible_rect().size
