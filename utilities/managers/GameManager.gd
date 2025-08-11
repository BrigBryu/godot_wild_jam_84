extends Node

signal game_started
signal game_paused
signal game_resumed
signal level_completed

var current_level: int = 1
var score: int = 0
var is_paused: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func start_game():
	score = 0
	current_level = 1
	emit_signal("game_started")
	load_level(current_level)

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		emit_signal("game_paused")
	else:
		emit_signal("game_resumed")

func load_level(level_number: int):
	var level_path = "res://scenes/levels/Level%d.tscn" % level_number
	if ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		print("Level %d not found!" % level_number)

func add_score(points: int):
	score += points

func complete_level():
	emit_signal("level_completed")
	current_level += 1
	load_level(current_level)