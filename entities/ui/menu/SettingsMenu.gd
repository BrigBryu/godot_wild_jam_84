extends Control

@onready var master_slider = $VBoxContainer/MasterVolume/HSlider
@onready var master_label = $VBoxContainer/MasterVolume/ValueLabel
@onready var audio_settings = null

func _ready():
	# Try to get AudioSettings from autoload or create it
	if has_node("/root/AudioSettings"):
		audio_settings = get_node("/root/AudioSettings")
	else:
		# Load settings manually if not autoloaded
		audio_settings = load("res://config/settings/AudioSettings.gd").new()
		audio_settings.load_settings()
	
	# Set slider to current volume
	if audio_settings:
		master_slider.value = audio_settings.master_volume
		_on_master_slider_value_changed(audio_settings.master_volume)

func _on_master_slider_value_changed(value):
	# Update the label to show percentage
	master_label.text = str(int(value * 100)) + "%"
	
	# Update audio settings
	if audio_settings:
		audio_settings.set_master_volume(value)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://entities/ui/menu/MainMenu.tscn")