extends Node

# Centralized score management system

var current_score: int = 0
var high_score: int = 0
var session_critters_collected: int = 0

const SCORE_SAVE_FILE = "user://high_score.save"

func _ready():
	# Connect to SignalBus events
	SignalBus.critter_collected.connect(_on_critter_collected)
	SignalBus.game_started.connect(_on_game_started)
	SignalBus.game_ended.connect(_on_game_ended)
	
	load_high_score()

func _on_game_started():
	"""Reset score for new game"""
	current_score = 0
	session_critters_collected = 0
	SignalBus.score_changed.emit(current_score, 0)
	SignalBus.collection_count_changed.emit(0, -1)

func _on_critter_collected(critter_info: Dictionary):
	"""Handle scoring when critter is collected"""
	var points = 0
	
	# Get points from critter info
	if "points" in critter_info:
		points = critter_info.points
	else:
		# Fallback scoring based on type
		match critter_info.get("type", "unknown"):
			"starfish":
				points = 10
			_:
				points = 5
	
	# Apply any score multipliers
	points = calculate_final_points(points, critter_info)
	
	# Update score
	current_score += points
	session_critters_collected += 1
	
	# Emit score change
	SignalBus.score_changed.emit(current_score, points)
	
	# Emit collection count change (we don't track total critters yet, so use -1)
	SignalBus.collection_count_changed.emit(session_critters_collected, -1)

func calculate_final_points(base_points: int, critter_info: Dictionary) -> int:
	"""Calculate final points with any bonuses or multipliers"""
	var final_points = base_points
	
	# Rarity bonuses
	match critter_info.get("rarity", "common"):
		"uncommon":
			final_points = int(final_points * 1.5)
		"rare":
			final_points = int(final_points * 2.0)
		"legendary":
			final_points = int(final_points * 3.0)
	
	# Could add other bonuses here:
	# - Time bonuses
	# - Streak bonuses
	# - Perfect collection bonuses
	
	return final_points

func _on_game_ended(final_score: int, critters_collected: int):
	"""Handle game completion"""
	if final_score > high_score:
		high_score = final_score
		save_high_score()

func get_current_score() -> int:
	return current_score

func get_high_score() -> int:
	return high_score

func get_session_stats() -> Dictionary:
	return {
		"current_score": current_score,
		"critters_collected": session_critters_collected,
		"high_score": high_score
	}

func save_high_score():
	var file = FileAccess.open(SCORE_SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()
	else:
		push_error("Failed to save high score")

func load_high_score():
	if FileAccess.file_exists(SCORE_SAVE_FILE):
		var file = FileAccess.open(SCORE_SAVE_FILE, FileAccess.READ)
		if file:
			high_score = file.get_32()
			file.close()
		else:
			push_error("Failed to load high score")

# Debug functions
func add_debug_points(points: int):
	current_score += points
	SignalBus.score_changed.emit(current_score, points)

func reset_high_score():
	high_score = 0
	save_high_score()