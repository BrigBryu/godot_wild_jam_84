extends BaseCritter

# Starfish specific implementation

func _ready():
	super._ready()
	
	# Set starfish specific properties
	organism_name = "Starfish"
	scientific_name = "Asteroidea"
	critter_type = "starfish"
	collection_value = 10
	rarity = "common"
	description = "A five-armed marine echinoderm commonly found in tidal pools."
	
	# Starfish spawning properties
	spawn_scale = 0.05  # Scale to 5% of original size
	spawn_weight = 1.0  # Common spawn rate
	spawn_transparency = 0.0  # Not used anymore
	
	# Starfish specific behavior disabled for this game
	pass