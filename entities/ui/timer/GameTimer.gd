extends Node

@export var game_duration: float = 120.0  # 2 minutes default
@export var warning_time: float = 30.0  # Show warning in last 30 seconds

var time_remaining: float = 0.0
var timer_started: bool = false
var timer_paused: bool = false
var game_over: bool = false

signal timer_updated(time_left: float)
signal timer_warning(time_left: float)
signal timer_expired()

func _ready():
	time_remaining = game_duration
	set_process(false)  # Don't start processing until timer starts
	
	# Connect to tutorial completion signal
	if SignalBus.has_signal("tutorial_completed"):
		SignalBus.tutorial_completed.connect(_on_tutorial_completed)

func _process(delta):
	if timer_started and not timer_paused and not game_over:
		time_remaining -= delta
		
		if time_remaining <= 0:
			time_remaining = 0
			_on_timer_expired()
		else:
			timer_updated.emit(time_remaining)
			
			# Also emit through SignalBus for centralized management
			if SignalBus.has_signal("ui_timer_updated"):
				SignalBus.ui_timer_updated.emit(time_remaining)
			
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
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	return "%02d:%02d" % [minutes, seconds]

func _on_tutorial_completed():
	start_timer()

func _on_timer_expired():
	game_over = true
	timer_expired.emit()
	stop_timer()
	
	# Freeze the game
	get_tree().paused = true
	
	# Emit game over signal
	if SignalBus.has_signal("game_over"):
		SignalBus.game_over.emit()
