extends BaseOrganism

# Crab - a simple beach organism that's fun to collect!

func _organism_ready():
	# Set crab-specific properties
	organism_name = "Crab"
	organism_type = "crab"
	scientific_name = "Brachyura"
	description = "A decapod crustacean with a broad flat carapace and pincer claws."
	
	# Gameplay values
	collection_value = 15  # Worth more points than starfish
	rarity = "common"
	
	# Spawning properties
	spawn_scale = 0.05  # 5% of original size
	spawn_weight = 0.6  # Less common than starfish
	
	# Visual customization (if not set in scene)
	# sprite_texture = preload("res://entities/organisms/critters/crab/crab_sprite.png")
	# sprite_color = Color(1.0, 0.8, 0.6)  # Slightly sandy color
	collision_shape_radius = 12.0  # Slightly larger collection area