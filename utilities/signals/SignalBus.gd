extends Node

# Global signal bus for decoupled communication between systems
# Use this when direct connections would require multiple steps or create tight coupling

# === PLAYER SIGNALS ===
# Emitted when player position changes (for camera, minimap, etc.)
signal player_moved(new_position: Vector2)
# Emitted when player enters water
signal player_entered_water()
# Emitted when player exits water  
signal player_exited_water()
# Emitted when player interacts (presses E)
signal player_interaction_attempted()

# === CRITTER SIGNALS ===
# Emitted when a critter is successfully collected
signal critter_collected(critter_info: Dictionary)
# Emitted when a critter is spawned in the world
signal critter_spawned(critter: Node2D)
# Emitted when a critter becomes highlighted
signal critter_highlighted(critter: Node2D)
# Emitted when critter highlight is removed
signal critter_unhighlighted(critter: Node2D)
# Emitted when player gets near enough to interact with critter
signal critter_interaction_available(critter: Node2D)
# Emitted when player moves away from critter
signal critter_interaction_unavailable(critter: Node2D)

# === GAME STATE SIGNALS ===
# Emitted when the game session starts
signal game_started()
# Emitted when game is paused
signal game_paused()
# Emitted when game is resumed
signal game_resumed()
# Emitted when game ends (all critters collected or player quits)
signal game_ended(final_score: int, critters_collected: int)
# Emitted when tutorial is completed
signal tutorial_completed()
# Emitted when game timer expires
signal game_over()
# Emitted when score changes
signal score_changed(new_score: int, score_change: int)
# Emitted when collection count changes
signal collection_count_changed(new_count: int, total_critters: int)

# === UI SIGNALS ===
# Show/hide interaction hint ("Press E to collect")
signal ui_show_interaction_hint(show: bool, hint_text: String)
# Update score display
signal ui_score_updated(score: int)
# Update collection counter
signal ui_collection_updated(collected: int, total: int)
# Show collection celebration effect
signal ui_show_collection_effect(world_position: Vector2, points: int)
# Show game completion message
signal ui_show_completion_message(total_score: int, total_collected: int)
# Show/hide tutorial UI
signal ui_show_tutorial(show: bool)
# Update game timer display
signal ui_timer_updated(time_remaining: float, formatted_time: String)
# Show final score screen
signal ui_show_final_score(score: int, collected: int, total: int, time_taken: float)

# === STAGE SIGNALS ===
# Emitted when beach generation starts
signal stage_generation_started()
# Emitted when beach generation completes
signal stage_generation_completed(critter_count: int)
# Emitted when transitioning to new stage
signal stage_transition_started(new_stage: String)
# Emitted when stage transition completes
signal stage_transition_completed()

# === DEBUG SIGNALS ===
# Emitted when debug mode is toggled
signal debug_mode_toggled(enabled: bool)
# Emitted when debug info should be updated
signal debug_info_updated(info: Dictionary)

# === SYSTEM SIGNALS ===
# Emitted when settings change
signal settings_changed(setting_key: String, new_value)
# Emitted when audio volume changes
signal audio_volume_changed(bus_name: String, volume: float)

func _ready():
	print("SignalBus ready - Global communication system active")
	print("Available signal categories: Player, Critter, Game State, UI, Stage, Debug, System")

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