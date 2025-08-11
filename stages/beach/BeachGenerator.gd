extends Node2D

@export var world_width: int = 80
@export var world_height: int = 25  # Much smaller - mostly beach
@export var tile_size: int = 16
@export var ocean_height: int = 5   # Small strip of ocean at bottom
@export var deep_water_height: int = 2  # Only bottom 2 rows are impassable deep water
@export var starfish_density: float = 0.015  # Slightly higher density for smaller beach
@export var enable_wet_sand: bool = false
@export var low_tide_mode: bool = false

var sand_texture: Texture2D
var water_texture: Texture2D
var starfish_texture: Texture2D

var sand_tiles: Node2D
var ocean_tiles: Node2D
var water_collision: Node2D
var world_boundaries: Node2D
var starfish_container: Node2D
var wet_sand_overlay: Sprite2D
var deep_water_overlay: ColorRect

var wet_sand_generator: WetSandGenerator
var wetness_map: Array

func _ready():
	load_textures()
	setup_containers()
	setup_wet_sand_generator()
	SignalBus.stage_generation_started.emit()
	generate_beach()

func load_textures():
	sand_texture = load("res://stages/tilesets/sand_tile_full_16by16.png")
	water_texture = load("res://stages/tilesets/water_tile_full_16by16.png")
	starfish_texture = load("res://entities/organisms/critters/starfish/art/star_fish.png")

func setup_containers():
	sand_tiles = Node2D.new()
	sand_tiles.name = "SandTiles"
	sand_tiles.y_sort_enabled = true
	add_child(sand_tiles)
	
	ocean_tiles = Node2D.new()
	ocean_tiles.name = "OceanTiles"
	ocean_tiles.z_index = -1
	add_child(ocean_tiles)
	
	# Water collision container
	water_collision = Node2D.new()
	water_collision.name = "WaterCollision"
	add_child(water_collision)
	
	# World boundaries container
	world_boundaries = Node2D.new()
	world_boundaries.name = "WorldBoundaries"
	add_child(world_boundaries)
	
	# Wet sand overlay container
	wet_sand_overlay = Sprite2D.new()
	wet_sand_overlay.name = "WetSandOverlay"
	wet_sand_overlay.z_index = 1
	add_child(wet_sand_overlay)
	
	# Deep water overlay - only for the deepest water rows
	deep_water_overlay = ColorRect.new()
	deep_water_overlay.name = "DeepWaterOverlay"
	deep_water_overlay.color = Color(0, 0, 0.3, 0.5)  # Darker blue, more transparent
	deep_water_overlay.position = Vector2(0, (world_height - deep_water_height) * tile_size)
	deep_water_overlay.size = Vector2(world_width * tile_size, deep_water_height * tile_size)
	deep_water_overlay.z_index = 0
	add_child(deep_water_overlay)
	
	starfish_container = Node2D.new()
	starfish_container.name = "Starfish"
	starfish_container.y_sort_enabled = true
	starfish_container.z_index = 2
	add_child(starfish_container)

func setup_wet_sand_generator():
	wet_sand_generator = WetSandGenerator.new()
	
	if low_tide_mode:
		# Low tide - many tide lines extending far up the beach
		wet_sand_generator.num_tide_lines = 8
		wet_sand_generator.base_amplitude = 35.0
		wet_sand_generator.frequency_variation = Vector2(0.3, 2.0)
		wet_sand_generator.noise_strength = 0.5
		wet_sand_generator.fade_distance = 120.0
		wet_sand_generator.tide_spacing = 35.0  # Wider spacing for low tide
		wet_sand_generator.extend_far_inland = true
	else:
		# Normal tide
		wet_sand_generator.num_tide_lines = 4
		wet_sand_generator.base_amplitude = 25.0
		wet_sand_generator.frequency_variation = Vector2(0.5, 1.5)
		wet_sand_generator.noise_strength = 0.4
		wet_sand_generator.fade_distance = 80.0
		wet_sand_generator.tide_spacing = 20.0
		wet_sand_generator.extend_far_inland = false
	
	# Darker wet sand color
	wet_sand_generator.wet_color = Color(0.65, 0.58, 0.45, 1.0)
	# Lighter dry sand
	wet_sand_generator.dry_color = Color(1.0, 0.95, 0.85, 0.0)

func generate_beach():
	generate_ocean()
	generate_sand()
	generate_world_boundaries()
	if enable_wet_sand:
		generate_wet_sand_patterns()
	var critter_count = spawn_starfish()
	
	# Emit completion signal with critter count
	SignalBus.stage_generation_completed.emit(critter_count)
	
	print("Beach generated: ", world_width, "x", world_height, " tiles")
	print("Ocean height: ", ocean_height, " tiles (", deep_water_height, " deep water, ", ocean_height - deep_water_height, " shallow water)")
	print("Wet sand patterns: ", "Enabled" if enable_wet_sand else "Disabled")
	print("Total tiles: ", world_width * world_height)
	print("Critters spawned: ", critter_count)

func generate_ocean():
	for x in range(world_width):
		for y in range(ocean_height):
			var sprite = Sprite2D.new()
			sprite.texture = water_texture
			sprite.position = Vector2(x * tile_size, (world_height - y - 1) * tile_size)
			# No color variation - just basic tile
			ocean_tiles.add_child(sprite)
			
			# Only add collision for deep water (bottom rows)
			if y < deep_water_height:
				var static_body = StaticBody2D.new()
				static_body.position = Vector2(x * tile_size, (world_height - y - 1) * tile_size)
				static_body.name = "DeepWaterCollision_" + str(x) + "_" + str(y)
				
				var collision_shape = CollisionShape2D.new()
				var rect_shape = RectangleShape2D.new()
				rect_shape.size = Vector2(tile_size, tile_size)
				collision_shape.shape = rect_shape
				collision_shape.position = Vector2(tile_size/2, tile_size/2)  # Center the collision
				
				static_body.add_child(collision_shape)
				water_collision.add_child(static_body)

func generate_sand():
	# Generate wetness map first
	if enable_wet_sand:
		wetness_map = wet_sand_generator.generate_wetness_map(world_width, world_height, ocean_height)
	
	for x in range(world_width):
		for y in range(ocean_height, world_height):
			var sprite = Sprite2D.new()
			sprite.texture = sand_texture
			sprite.position = Vector2(x * tile_size, (world_height - y - 1) * tile_size)
			
			# Only apply color variation if wet sand is enabled
			if enable_wet_sand:
				# Base sand color variation
				var base_variation = randf_range(0.95, 1.0)
				var sand_color = Color(base_variation, base_variation, base_variation, 1)
				
				# Apply wetness if wetness map exists
				if wetness_map.size() > x and wetness_map[x].size() > y:
					var wetness = wetness_map[x][y]
					if wetness > 0.01:
						# Darken sand based on wetness
						var wet_darkness = 1.0 - (wetness * 0.35)  # Max 35% darker
						sand_color *= Color(wet_darkness, wet_darkness * 0.95, wet_darkness * 0.9, 1)
						
						# Add slight blue tint for very wet areas
						if wetness > 0.7:
							sand_color = sand_color.lerp(Color(0.7, 0.75, 0.8, 1), (wetness - 0.7) * 0.5)
				
				sprite.modulate = sand_color
			# else: no modulation, just basic tile
			
			sand_tiles.add_child(sprite)

func generate_world_boundaries():
	var world_width_pixels = world_width * tile_size
	var world_height_pixels = world_height * tile_size
	var boundary_thickness = 32  # Make boundaries thick enough to prevent escapes
	
	# Top boundary
	var top_boundary = StaticBody2D.new()
	top_boundary.name = "TopBoundary"
	top_boundary.position = Vector2(world_width_pixels / 2, -boundary_thickness / 2)
	
	var top_collision = CollisionShape2D.new()
	var top_shape = RectangleShape2D.new()
	top_shape.size = Vector2(world_width_pixels + boundary_thickness * 2, boundary_thickness)
	top_collision.shape = top_shape
	
	top_boundary.add_child(top_collision)
	world_boundaries.add_child(top_boundary)
	
	# Left boundary
	var left_boundary = StaticBody2D.new()
	left_boundary.name = "LeftBoundary"
	left_boundary.position = Vector2(-boundary_thickness / 2, world_height_pixels / 2)
	
	var left_collision = CollisionShape2D.new()
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(boundary_thickness, world_height_pixels + boundary_thickness * 2)
	left_collision.shape = left_shape
	
	left_boundary.add_child(left_collision)
	world_boundaries.add_child(left_boundary)
	
	# Right boundary - match camera limit_right (1264)
	var camera_limit_right = 1264
	var right_boundary = StaticBody2D.new()
	right_boundary.name = "RightBoundary"
	right_boundary.position = Vector2(camera_limit_right + boundary_thickness / 2, world_height_pixels / 2)
	
	var right_collision = CollisionShape2D.new()
	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(boundary_thickness, world_height_pixels + boundary_thickness * 2)
	right_collision.shape = right_shape
	
	right_boundary.add_child(right_collision)
	world_boundaries.add_child(right_boundary)

func generate_wet_sand_patterns():
	# Generate a texture overlay for additional detail
	var overlay_texture = wet_sand_generator.generate_wet_sand_texture(
		world_width * tile_size, 
		world_height * tile_size,
		(world_height - ocean_height) * tile_size
	)
	
	# Apply the overlay
	wet_sand_overlay.texture = overlay_texture
	wet_sand_overlay.position = Vector2(world_width * tile_size / 2, world_height * tile_size / 2)
	wet_sand_overlay.centered = true
	
	# Set blend mode for better integration
	var material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	wet_sand_overlay.material = material

func spawn_starfish() -> int:
	var sand_area_height = world_height - ocean_height
	var total_sand_tiles = world_width * sand_area_height
	var starfish_count = int(total_sand_tiles * starfish_density)
	
	# Load the starfish scene
	var starfish_scene = preload("res://entities/organisms/critters/starfish/StarFish.tscn")
	
	for i in range(starfish_count):
		var starfish = starfish_scene.instantiate()
		
		# Random position on sand
		var x = randf() * world_width * tile_size
		var y = randf_range(0, sand_area_height * tile_size)
		starfish.position = Vector2(x, y)
		
		# Random rotation
		starfish.rotation = randf() * TAU
		
		# Slight scale variation
		var scale_var = randf_range(0.8, 1.2)
		starfish.scale = Vector2(scale_var, scale_var)
		
		# Get sprite for color variation
		var sprite = starfish.get_node("Sprite2D")
		if sprite:
			var color_var = randf_range(0.9, 1.0)
			sprite.modulate = Color(1, color_var, color_var, 1)
		
		starfish_container.add_child(starfish)
		
		# Emit spawn event
		SignalBus.critter_spawned.emit(starfish)
	
	print("Spawned ", starfish_count, " starfish")
	return starfish_count

func regenerate():
	# Clear existing tiles
	for child in sand_tiles.get_children():
		child.queue_free()
	for child in ocean_tiles.get_children():
		child.queue_free()
	for child in water_collision.get_children():
		child.queue_free()
	for child in world_boundaries.get_children():
		child.queue_free()
	for child in starfish_container.get_children():
		child.queue_free()
	
	# Re-randomize the wet sand generator
	if wet_sand_generator:
		wet_sand_generator.noise.seed = randi()
	
	# Generate new beach
	generate_beach()