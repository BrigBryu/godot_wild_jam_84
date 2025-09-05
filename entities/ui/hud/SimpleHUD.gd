extends Control

# Simple HUD with just score, timer, and critter count

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var critter_count_label: Label = $TopBar/CritterCountLabel
@onready var interaction_hint: Label = null  # Will find in _ready()
@onready var game_timer: Node = null

var total_score: int = 0
var critters_collected: int = 0
var total_critters: int = 0

func _ready():
	# Try to find InteractionHint node - it might be at different paths
	var hint_paths = [
		"InteractionHint",           # Direct child
		"../InteractionHint",        # Sibling node
		"BottomBar/InteractionHint", # In bottom bar
		"./InteractionHint"          # Explicit current level
	]
	
	for path in hint_paths:
		interaction_hint = get_node_or_null(path)
		if interaction_hint:
			break
	
	# Only warn if interaction hints are expected to be shown
	if not interaction_hint:
		print("Note: InteractionHint node not found - interaction hints will be disabled")
	
	# Connect to SignalBus events
	SignalBus.ui_show_interaction_hint.connect(_on_show_interaction_hint)
	SignalBus.critter_collected.connect(_on_critter_collected)
	SignalBus.score_changed.connect(_on_score_changed)
	# Note: stage_generation_completed signal was removed - set total_critters elsewhere if needed
	
	# Find and connect to GameTimer
	game_timer = get_node_or_null("/root/Beach/GameTimer")
	if game_timer:
		game_timer.timer_updated.connect(_on_timer_updated)
		game_timer.timer_expired.connect(_on_timer_expired)
		timer_label.visible = true
	else:
		timer_label.visible = false
	
	# Hide interaction hint initially
	if interaction_hint:
		interaction_hint.visible = false
	
	update_display()

func _on_show_interaction_hint(show: bool, hint_text: String):
	"""Show/hide interaction hint"""
	if interaction_hint:
		interaction_hint.visible = show
		if show and hint_text != "":
			interaction_hint.text = hint_text

func _on_timer_updated(time_remaining: float):
	"""Update timer display"""
	if timer_label:
		var minutes = int(time_remaining / 60.0)  # Proper float division
		var seconds = int(time_remaining) % 60
		timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
		
		# Change color based on time remaining
		if time_remaining <= 10.0:
			timer_label.modulate = Color(1, 0.3, 0.3) if int(time_remaining * 2) % 2 == 0 else Color.WHITE
		elif time_remaining <= 30.0:
			timer_label.modulate = Color(1, 0.8, 0.3)
		else:
			timer_label.modulate = Color.WHITE

func _on_score_changed(new_score: int, _score_change: int):
	"""Update score display"""
	total_score = new_score
	update_display()

func _on_critter_collected(_critter_info: Dictionary):
	"""Update collection count"""
	critters_collected += 1
	update_display()

# Removed - stage_generation_completed signal no longer exists

func _on_timer_expired():
	"""Handle timer expiration"""
	if timer_label:
		timer_label.text = "Time: 00:00"
		timer_label.modulate = Color(1, 0, 0)
	
	# Show game over screen
	_show_game_over()

func _show_game_over():
	# Create game over overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var label = Label.new()
	label.text = "Time's Up!"
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.x = -150
	label.position.y = -50
	label.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var score_label_go = Label.new()
	score_label_go.text = "Final Score: " + str(total_score)
	score_label_go.add_theme_font_size_override("font_size", 32)
	score_label_go.set_anchors_preset(Control.PRESET_CENTER)
	score_label_go.position.x = -120
	score_label_go.position.y = 20
	score_label_go.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var button = Button.new()
	button.text = "Return to Menu"
	button.add_theme_font_size_override("font_size", 24)
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.position.x = -75
	button.position.y = 80
	button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	button.pressed.connect(_on_menu_button_pressed)
	
	add_child(overlay)
	overlay.add_child(label)
	overlay.add_child(score_label_go)
	overlay.add_child(button)

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://entities/ui/menu/MainMenu.tscn")

func update_display():
	"""Update all HUD elements"""
	if score_label:
		score_label.text = "Score: %d" % total_score
	
	if critter_count_label:
		critter_count_label.text = "Critters: %d" % critters_collected
	
	# Timer is updated via _on_timer_updated callback
