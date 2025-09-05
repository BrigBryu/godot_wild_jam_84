extends Node

@export var game_duration: float = 240.0  # 4 minutes for more exploration time
@export var warning_time: float = 30.0  # Show warning in last 30 seconds

var time_remaining: float = 0.0
var timer_started: bool = false
var timer_paused: bool = false
var game_over: bool = false
var game_settings = null

signal timer_updated(time_left: float)
signal timer_warning(time_left: float)
signal timer_expired()

func _ready():
	# Try to get GameSettings and use its duration if available
	if has_node("/root/GameSettings"):
		game_settings = get_node("/root/GameSettings")
		var duration = game_settings.get_setting("gameplay.game_duration")
		if duration:
			game_duration = duration
			# Set warning time to 1/3 of game duration
			warning_time = duration / 3.0
	
	time_remaining = game_duration
	set_process(false)  # Don't start processing until timer starts
	
	# Start timer immediately (no tutorial system anymore)
	start_timer()

func _process(delta):
	if timer_started and not timer_paused and not game_over:
		time_remaining -= delta
		
		if time_remaining <= 0:
			time_remaining = 0
			_on_timer_expired()
		else:
			timer_updated.emit(time_remaining)
			
			# Check for warning threshold
			if time_remaining <= warning_time and time_remaining > warning_time - delta:
				timer_warning.emit(time_remaining)

func start_timer():
	if not timer_started:
		timer_started = true
		set_process(true)

func pause_timer():
	timer_paused = true

func resume_timer():
	timer_paused = false

func stop_timer():
	timer_started = false
	timer_paused = false
	set_process(false)

func reset_timer():
	time_remaining = game_duration
	timer_started = false
	timer_paused = false
	game_over = false
	set_process(false)

func get_formatted_time() -> String:
	var minutes = int(time_remaining) / 60.0  # Use float division
	var seconds = int(time_remaining) % 60
	return "%02d:%02d" % [minutes, seconds]

func _on_timer_expired():
	game_over = true
	timer_expired.emit()
	stop_timer()
	
	# Freeze the game
	get_tree().paused = true
