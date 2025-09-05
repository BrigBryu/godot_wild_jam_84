extends Node

# Global signal bus for decoupled communication between systems
# Use this when direct connections would require multiple steps or create tight coupling

# === PLAYER SIGNALS ===
# Emitted when player position changes (for camera, minimap, etc.)
signal player_moved(new_position: Vector2)
# Water signals
signal player_entered_water()  ## Emitted by WaveArea and WaveDetector
signal player_exited_water()  ## Emitted by WaveArea and WaveDetector
signal wave_area_ready(wave_area: Area2D)  ## Emitted by BeachMinimal

# === CRITTER SIGNALS ===
# Emitted when a critter is successfully collected
signal critter_collected(critter_info: Dictionary)
# Emitted when a critter becomes highlighted
signal critter_highlighted(critter: Node2D)  ## Emitted by PlayerController
# Emitted when critter highlight is removed
signal critter_unhighlighted(critter: Node2D)  ## Emitted by PlayerController
# Emitted when player gets near enough to interact with critter
signal critter_interaction_available(critter: Node2D)
# Emitted when player moves away from critter
signal critter_interaction_unavailable(critter: Node2D)

# === GAME STATE SIGNALS ===
# Emitted when game ends (all critters collected or player quits)
signal game_ended(final_score: int, critters_collected: int)
# Emitted when score changes
signal score_changed(new_score: int, score_change: int)  ## Emitted by ScoreManager

# === UI SIGNALS ===
# Show/hide interaction hint ("Press E to collect")
signal ui_show_interaction_hint(show: bool, hint_text: String)
# Show collection celebration effect
signal ui_show_collection_effect(world_position: Vector2, points: int)
# Show game completion message
signal ui_show_completion_message(total_score: int, total_collected: int)

# === STAGE SIGNALS ===
# Wave signal for spawning
signal wave_peak_reached(spawn_rectangle: Rect2)  ## Emitted by BeachMinimal

# (Debug and system signals removed - were never used)

# Helper functions for common event combinations

func collect_critter(critter_type: String, critter_name: String, points: int, world_pos: Vector2):
	"""Emit all signals related to critter collection"""
	var critter_info = {
		"type": critter_type,
		"name": critter_name, 
		"points": points,
		"position": world_pos
	}
	
	critter_collected.emit(critter_info)
	# Note: ScoreManager will handle score_changed emission
	ui_show_collection_effect.emit(world_pos, points)
	
func update_interaction_state(available: bool, critter: Node2D = null, hint_text: String = ""):
	"""Update interaction availability and UI hints"""
	if available and critter:
		critter_interaction_available.emit(critter)
		ui_show_interaction_hint.emit(true, hint_text)
	else:
		if critter:
			critter_interaction_unavailable.emit(critter)
		ui_show_interaction_hint.emit(false, "")

func complete_game(final_score: int, critters_collected: int):
	"""Handle game completion"""
	game_ended.emit(final_score, critters_collected)
	ui_show_completion_message.emit(final_score, critters_collected)
