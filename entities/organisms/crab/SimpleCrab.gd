extends "res://entities/organisms/SimpleOrganism.gd"

## Simple crab - just 3 lines of configuration!

func _configure() -> void:
	organism_name = "Crab"
	points_value = 20
	wave_influence = 0.3  # Heavy, less affected by waves