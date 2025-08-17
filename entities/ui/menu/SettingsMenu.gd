extends Control

@onready var master_slider = $VBoxContainer/MasterVolume/HSlider
@onready var master_label = $VBoxContainer/MasterVolume/ValueLabel
@onready var duration_slider = $VBoxContainer/GameDuration/HSlider
@onready var duration_label = $VBoxContainer/GameDuration/ValueLabel
@onready var audio_settings = null
@onready var game_settings = null

func _ready():
	# Try to get AudioSettings from autoload or create it
	if has_node("/root/AudioSettings"):
		audio_settings = get_node("/root/AudioSettings")
	else:
		# Load settings manually if not autoloaded
		audio_settings = load("res://config/settings/AudioSettings.gd").new()
		audio_settings.load_settings()
	
	# Try to get GameSettings from autoload or create it
	if has_node("/root/GameSettings"):
		game_settings = get_node("/root/GameSettings")
	else:
		# Load settings manually if not autoloaded
		game_settings = load("res://config/settings/GameSettings.gd").new()
	
	# Set slider to current volume
	if audio_settings:
		master_slider.value = audio_settings.master_volume
		_on_master_slider_value_changed(audio_settings.master_volume)
	
	# Set slider to current game duration
	if game_settings:
		var duration = game_settings.get_setting("gameplay.game_duration")
		if duration:
			duration_slider.value = duration
			_on_duration_slider_value_changed(duration)

func _on_master_slider_value_changed(value):
	# Update the label to show percentage
	master_label.text = str(int(value * 100)) + "%"
	
	# Update audio settings
	if audio_settings:
		audio_settings.set_master_volume(value)

func _on_duration_slider_value_changed(value):
	# Update the label to show seconds
	duration_label.text = str(int(value)) + "s"
	
	# Update game settings
	if game_settings:
		game_settings.set_setting("gameplay.game_duration", value)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://entities/ui/menu/MainMenu.tscn")