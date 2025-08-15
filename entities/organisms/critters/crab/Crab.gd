extends BaseCritter

# Crab specific implementation

func _ready():
	super._ready()
	
	# Set crab specific properties
	organism_name = "Crab"
	scientific_name = "Brachyura"
	critter_type = "crab"
	collection_value = 15
	rarity = "common"
	description = "A decapod crustacean with a broad flat carapace and pincer claws."
	
	# Crab spawning properties - same size as starfish now
	spawn_scale = 0.05  # Scale to 5% of original size
	spawn_weight = 0.6  # Less common than starfish
	spawn_transparency = 0.0  # Not used anymore
	
	# Crab specific behavior can be added here
	pass