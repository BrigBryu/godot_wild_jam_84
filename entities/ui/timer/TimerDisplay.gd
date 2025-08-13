extends Control

@onready var timer_label: Label = $TimerContainer/TimerLabel
@onready var timer_container: PanelContainer = $TimerContainer
@onready var game_timer: Node = null

var warning_flash: bool = false

func _ready():
	# Find the GameTimer node
	game_timer = get_node_or_null("/root/Beach/GameTimer")
	if not game_timer:
		game_timer = get_node_or_null("../GameTimer")
	
	if game_timer:
		game_timer.timer_updated.connect(_on_timer_updated)
		game_timer.timer_warning.connect(_on_timer_warning)
		game_timer.timer_expired.connect(_on_timer_expired)
	
	# Initially hide until timer starts
	visible = false

func _on_timer_updated(time_left: float):
	if not visible:
		visible = true
	
	if timer_label:
		timer_label.text = _format_time(time_left)
		
		# Flash red when under 10 seconds
		if time_left <= 10.0:
			timer_label.modulate = Color(1, 0.3, 0.3) if int(time_left * 2) % 2 == 0 else Color.WHITE
		elif time_left <= 30.0:
			timer_label.modulate = Color(1, 0.8, 0.3)  # Yellow warning
		else:
			timer_label.modulate = Color.WHITE

func _on_timer_warning(time_left: float):
	# Could add sound effect or animation here
	print("Warning: ", time_left, " seconds remaining!")

func _on_timer_expired():
	if timer_label:
		timer_label.text = "00:00"
		timer_label.modulate = Color(1, 0, 0)
	
	# Show game over overlay
	_show_game_over()

func _format_time(time: float) -> String:
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	return "%02d:%02d" % [minutes, seconds]

func _show_game_over():
	# Create a simple game over overlay
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
	
	var score_label = Label.new()
	score_label.text = "Score: " + str(ScoreManager.get_score())
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.set_anchors_preset(Control.PRESET_CENTER)
	score_label.position.x = -100
	score_label.position.y = 20
	score_label.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var button = Button.new()
	button.text = "Return to Menu"
	button.add_theme_font_size_override("font_size", 24)
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.position.x = -75
	button.position.y = 80
	button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	button.pressed.connect(_on_menu_button_pressed)
	
	get_parent().add_child(overlay)
	overlay.add_child(label)
	overlay.add_child(score_label)
	overlay.add_child(button)

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://entities/ui/menu/MainMenu.tscn")