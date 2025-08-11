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
	
	# Starfish specific behavior disabled for this game
	pass