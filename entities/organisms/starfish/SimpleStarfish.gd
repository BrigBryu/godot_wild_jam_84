extends "res://entities/organisms/SimpleOrganism.gd"

## Simple starfish - just 3 lines of configuration!

func _configure() -> void:
	organism_name = "Starfish"
	points_value = 15
	wave_influence = 0.8  # Light, easily moved by waves