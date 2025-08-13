extends Control

func _ready():
	pass

func _on_play_button_pressed():
	# Switch to the beach scene when play is pressed
	get_tree().change_scene_to_file("res://stages/beach/Beach.tscn")

func _on_exit_button_pressed():
	# Quit the game
	get_tree().quit()