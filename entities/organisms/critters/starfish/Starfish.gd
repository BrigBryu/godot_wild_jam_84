extends BaseOrganism

# Starfish - a common and colorful beach organism!

func _organism_ready():
	# Set starfish-specific properties
	organism_name = "Starfish"
	organism_type = "starfish"
	scientific_name = "Asteroidea"
	description = "A five-armed marine echinoderm commonly found in tidal pools."
	
	# Gameplay values
	collection_value = 10  # Standard points
	rarity = "common"
	
	# Spawning properties
	spawn_scale = 0.05  # 5% of original size
	spawn_weight = 1.0  # Most common spawn
	
	# Visual customization (if not set in scene)
	# sprite_texture = preload("res://entities/organisms/critters/starfish/starfish_sprite.png")
	# sprite_color = Color(1.0, 0.6, 0.8)  # Pinkish color
	collision_shape_radius = 10.0  # Standard collection area
