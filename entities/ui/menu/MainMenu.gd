extends Control

func _unhandled_input(event: InputEvent) -> void:
	# Allow Enter key to start the game immediately
	if event.is_action_pressed("ui_accept") or event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_start_game()

func _start_game() -> void:
	"""Start the game - can be called by button or Enter key"""
	get_tree().change_scene_to_file("res://stages/beach/BeachMinimal.tscn")

func _on_play_button_pressed():
	# Switch to the beach scene when play is pressed
	_start_game()

func _on_settings_button_pressed():
	# Open settings menu
	get_tree().change_scene_to_file("res://entities/ui/menu/SettingsMenu.tscn")

func _on_exit_button_pressed():
	# Quit the game
	get_tree().quit()