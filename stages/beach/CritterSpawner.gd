class_name CritterSpawner
extends Node2D

# Generic critter spawning system for wave-based spawning

@export var spawning_enabled: bool = true
@export var spawn_chance: float = 0.3  # Chance per wave to spawn critters (0.0 to 1.0)
@export var spawn_count_range: Vector2i = Vector2i(1, 3)  # Min/max critters per wave

# Critter scene paths - much simpler now
@export var critter_scenes: Array[String] = []

# Spawn zone configuration (between water max and shore)
@export var spawn_zone_padding: float = 20.0  # Distance from edges to avoid spawning
@export var spawn_y_offset_from_shore: float = 10.0  # Offset from shore line
@export var critter_spacing: float = 50.0  # Minimum distance between critters
@export var max_spawn_attempts: int = 20  # Max attempts to find a non-overlapping position

# Critters are now permanently visible - no fade animation needed

# Debug settings
@export var debug_spawning: bool = true  # Show debug info
@export var debug_draw_spawn_zone: bool = true  # Draw spawn zone rectangle

# Note: Critter sizing is now managed by each critter individually

# Internal state
var active_critters: Array[Node2D] = []
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
	
	# Set up default critter scenes if none provided
	if critter_scenes.is_empty():
		_setup_default_scenes()
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _setup_default_scenes():
	"""Set up default critter scene paths"""
	critter_scenes = [
		"res://entities/organisms/critters/starfish/StarFish.tscn",
		"res://entities/organisms/critters/crab/crab.tscn"
	]

func should_spawn_critters() -> bool:
	"""Check if critters should spawn this wave"""
	return spawning_enabled and randf() < spawn_chance

# Removed _update_debug_spawn_zone - using signal-based rectangle system

func spawn_critters_in_rectangle(spawn_rectangle: Rect2):
	"""Spawn critters in the given rectangle - clean, simple, signal-based"""
	# Update debug state for drawing
	debug_spawn_zone_rect = spawn_rectangle
	spawn_attempts += 1
	
	if debug_spawning:
		print("CritterSpawner: Received wave rectangle - attempt #", spawn_attempts)
		print("  Spawn rectangle: ", spawn_rectangle)
	
	# Force redraw to show the rectangle
	if debug_draw_spawn_zone:
		queue_redraw()
	
	last_spawn_attempt = should_spawn_critters()
	if not last_spawn_attempt:
		if debug_spawning:
			print("  Spawn chance failed (", spawn_chance, ")")
		return
	
	var count = randi_range(spawn_count_range.x, spawn_count_range.y)
	if debug_spawning:
		print("  Spawning ", count, " critters")
	
	var new_critters: Array[Node2D] = []
	
	# First pass: create critters invisibly and let _ready() run
	for i in range(count):
		var critter = _create_random_critter()
		if critter:
			# Make invisible immediately to prevent flash of large critter
			critter.modulate.a = 0.0
			# Add to scene tree so _ready() runs and sets spawn properties
			add_child(critter)
			new_critters.append(critter)
		else:
			if debug_spawning:
				print("    Failed to create critter #", i)
	
	# Wait one frame for all _ready() functions to complete
	await get_tree().process_frame
	
	# Second pass: setup spawning properties, position, and make visible
	for critter in new_critters:
		# Apply scaling now that _ready() has run
		critter.setup_for_spawning()
		
		# Position the properly scaled critter in the rectangle
		_position_critter_in_rectangle(critter, spawn_rectangle)
		
		# Now make it visible at the correct size and position
		critter.modulate.a = 1.0
		
		active_critters.append(critter)
		successful_spawns += 1
		if debug_spawning:
			print("    Spawned ", critter.name, " at ", critter.position, " with scale ", critter.scale, " - permanent")

func _create_random_critter() -> Node2D:
	"""Create a random critter based on spawn weights"""
	if critter_scenes.is_empty():
		push_warning("No critter scenes available for spawning")
		return null
	
	# First, instantiate all possible critters to get their weights
	var available_critters: Array[Node2D] = []
	var weights: Array[float] = []
	
	for scene_path in critter_scenes:
		var critter = _instantiate_critter_from_path(scene_path)
		if critter:
			available_critters.append(critter)
			weights.append(critter.get_spawn_weight())
		
	if available_critters.is_empty():
		push_warning("No valid critters could be instantiated")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	# Select random critter based on weights
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for i in range(available_critters.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			# Free the other critters we don't need
			for j in range(available_critters.size()):
				if j != i:
					available_critters[j].queue_free()
			return available_critters[i]
	
	# Fallback to first critter (and free the rest)
	for j in range(1, available_critters.size()):
		available_critters[j].queue_free()
	return available_critters[0]

func _instantiate_critter_from_path(scene_path: String) -> Node2D:
	"""Instantiate a critter from its scene path"""
	if not ResourceLoader.exists(scene_path):
		push_error("Critter scene not found: " + scene_path)
		return null
	
	var critter_scene = load(scene_path)
	if not critter_scene:
		push_error("Failed to load critter scene: " + scene_path)
		return null
	
	var critter = critter_scene.instantiate()
	if not critter:
		push_error("Failed to instantiate critter from: " + scene_path)
		return null
	
	# Set a unique name
	var scene_name = scene_path.get_file().get_basename()
	critter.name = scene_name + "_" + str(randi())
	return critter

func _position_critter_in_rectangle(critter: Node2D, rect: Rect2):
	"""Position critter randomly within the rectangle, avoiding overlaps"""
	var attempts = 0
	var valid_position = false
	var final_position = Vector2.ZERO
	
	while not valid_position and attempts < max_spawn_attempts:
		# Generate random position within rectangle
		var x_pos = randf_range(rect.position.x, rect.position.x + rect.size.x)
		var y_pos = randf_range(rect.position.y, rect.position.y + rect.size.y)
		var test_position = Vector2(x_pos, y_pos)
		
		# Check if this position overlaps with existing critters
		if _is_position_clear(test_position):
			final_position = test_position
			valid_position = true
		
		attempts += 1
	
	# If we couldn't find a clear position, use the last attempt
	if not valid_position:
		if debug_spawning:
			print("    Warning: Couldn't find clear position after ", max_spawn_attempts, " attempts")
		final_position = Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
	
	critter.position = final_position

func _is_position_clear(test_position: Vector2) -> bool:
	"""Check if a position is clear of other critters"""
	for existing_critter in active_critters:
		if is_instance_valid(existing_critter):
			var distance = test_position.distance_to(existing_critter.position)
			if distance < critter_spacing:
				return false
	return true

# Scale and transparency are now handled by each critter's setup_for_spawning() method

# Critters are now permanent - no visibility management needed

func clear_all_critters():
	"""Clear all active critters immediately"""
	for critter in active_critters:
		if is_instance_valid(critter):
			critter.queue_free()
	active_critters.clear()

func get_active_critter_count() -> int:
	"""Get number of currently active critters"""
	return active_critters.size()

func _draw():
	"""Draw debug information - simplified for signal-based system"""
	if not debug_draw_spawn_zone:
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
	if debug_draw_spawn_zone:
		queue_redraw()

func _on_viewport_size_changed():
	"""Handle viewport size changes"""
	viewport_size = get_viewport().get_visible_rect().size