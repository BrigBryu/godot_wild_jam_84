extends Control

# Complete HUD system with tutorial, timer, and score screens

# UI Container references (with null checks)
var game_ui: Control
var tutorial_ui: Control  
var final_score_ui: Control

# Game UI elements
var score_label: Label
var timer_label: Label
var critter_count_label: Label
var interaction_hint: Label

# Tutorial UI elements
var tutorial_text: RichTextLabel
var tutorial_close_button: Button

# Final Score UI elements
var final_score_panel: Control
var final_score_label: Label
var final_time_label: Label
var final_collected_label: RichTextLabel
var play_again_button: Button
var exit_button: Button

var total_score: int = 0
var critters_collected: int = 0
var total_critters: int = 0

func _ready():
	# Get all node references safely
	setup_node_references()
	
	# Connect to SignalBus events
	SignalBus.ui_show_tutorial.connect(_on_show_tutorial)
	SignalBus.ui_show_interaction_hint.connect(_on_show_interaction_hint)
	SignalBus.ui_show_final_score.connect(_on_show_final_score)
	SignalBus.critter_collected.connect(_on_critter_collected)
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.stage_generation_completed.connect(_on_stage_completed)
	
	# Connect GameManager signals
	if GameManager:
		GameManager.game_timer_updated.connect(_on_timer_updated)
		GameManager.game_completed.connect(_on_game_completed)
	
	# Connect buttons
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again)
	if exit_button:
		exit_button.pressed.connect(_on_exit_game)
	if tutorial_close_button:
		tutorial_close_button.pressed.connect(_on_close_tutorial)
	
	# Start with game UI visible
	show_game_ui()

func setup_node_references():
	"""Get all node references with null checks"""
	# Main UI containers
	game_ui = get_node_or_null("GameUI")
	tutorial_ui = get_node_or_null("TutorialUI")
	final_score_ui = get_node_or_null("FinalScoreUI")
	
	# Game UI elements
	if game_ui:
		score_label = game_ui.get_node_or_null("TopBar/ScoreLabel")
		timer_label = game_ui.get_node_or_null("TopBar/TimerLabel") 
		critter_count_label = game_ui.get_node_or_null("TopBar/CritterCountLabel")
		interaction_hint = game_ui.get_node_or_null("InteractionHint")
	
	# Tutorial UI elements
	if tutorial_ui:
		var tutorial_panel = tutorial_ui.get_node_or_null("Panel")
		if tutorial_panel:
			tutorial_close_button = tutorial_panel.get_node_or_null("CloseButton")
			tutorial_text = tutorial_panel.get_node_or_null("TutorialText")
	
	# Final Score UI elements
	if final_score_ui:
		var score_panel = final_score_ui.get_node_or_null("Panel/VBoxContainer")
		if score_panel:
			final_score_label = score_panel.get_node_or_null("FinalScoreLabel")
			final_time_label = score_panel.get_node_or_null("TimeLabel")
			final_collected_label = score_panel.get_node_or_null("CollectedLabel")
			var button_container = score_panel.get_node_or_null("ButtonContainer")
			if button_container:
				play_again_button = button_container.get_node_or_null("PlayAgainButton")
				exit_button = button_container.get_node_or_null("ExitButton")

func show_game_ui():
	"""Show the main game HUD"""
	if game_ui:
		game_ui.visible = true
	if tutorial_ui:
		tutorial_ui.visible = false
	if final_score_ui:
		final_score_ui.visible = false
	
	if interaction_hint:
		interaction_hint.visible = false
	
	# Initialize timer display (will show 01:00 initially)
	if timer_label:
		timer_label.text = "Time: 01:00"
		timer_label.modulate = Color.WHITE
	
	update_display()

func _on_show_tutorial(show: bool):
	"""Show/hide tutorial overlay"""
	if tutorial_ui:
		tutorial_ui.visible = show
		
	if show:
		setup_tutorial_text()
		# Make sure game UI is visible underneath tutorial
		if game_ui:
			game_ui.visible = true

func setup_tutorial_text():
	"""Setup tutorial instructions"""
	if tutorial_text:
		var instructions = "[color=yellow]How to Play:[/color] "
		instructions += "Use [color=cyan]WASD[/color] to move • "
		instructions += "Walk [color=green]RIGHT[/color] along the beach • "
		instructions += "Get close to [color=orange]starfish[/color] to highlight them • "
		instructions += "Press [color=cyan]E[/color] to collect • "
		instructions += "[color=lime]Game starts in 3 seconds...[/color]"
		tutorial_text.text = instructions

func _on_show_interaction_hint(show: bool, hint_text: String):
	"""Show/hide interaction hint"""
	if interaction_hint:
		interaction_hint.visible = show
		if show and hint_text != "":
			interaction_hint.text = hint_text

func _on_timer_updated(time_remaining: float):
	"""Update timer display"""
	if timer_label:
		var minutes = int(time_remaining) / 60
		var seconds = int(time_remaining) % 60
		timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
		
		# Change color when time is running low
		if time_remaining <= 10:
			timer_label.modulate = Color.RED
		elif time_remaining <= 30:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color.WHITE

func _on_score_changed(new_score: int, score_change: int):
	"""Update score display"""
	total_score = new_score
	update_display()

func _on_critter_collected(critter_info: Dictionary):
	"""Update collection count"""
	critters_collected += 1
	update_display()

func _on_stage_completed(critter_count: int):
	"""Set total critter count"""
	total_critters = critter_count
	update_display()

func update_display():
	"""Update all HUD elements"""
	if score_label:
		score_label.text = "Score: %d" % total_score
	
	if critter_count_label:
		critter_count_label.text = "Critters: %d" % critters_collected

func _on_game_completed(final_score: int, total_collected: int, time_taken: float):
	"""Handle game completion"""
	SignalBus.ui_show_final_score.emit(final_score, total_collected, total_critters, time_taken)

func _on_show_final_score(score: int, collected: int, total: int, time_taken: float):
	"""Show final score screen"""
	if game_ui:
		game_ui.visible = false
	if tutorial_ui:
		tutorial_ui.visible = false
	if final_score_ui:
		final_score_ui.visible = true
	
	if final_score_label:
		final_score_label.text = "Final Score: %d" % score
	
	if final_collected_label:
		final_collected_label.text = "Critters Collected: %d/%d" % [collected, total]
		
		# Add completion message
		if collected >= total:
			final_collected_label.text += "\n[color=gold]Perfect! All critters found![/color]"
	
	if final_time_label:
		var minutes = int(time_taken) / 60
		var seconds = int(time_taken) % 60
		final_time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_play_again():
	"""Restart the game"""
	if GameManager:
		GameManager.restart_game()

func _on_exit_game():
	"""Exit the game"""
	if GameManager:
		GameManager.quit_game()
	else:
		get_tree().quit()

func _on_close_tutorial():
	"""Close tutorial early and start game"""
	if GameManager:
		GameManager.end_tutorial()
	else:
		# Fallback if GameManager isn't available
		if tutorial_ui:
			tutorial_ui.visible = false
