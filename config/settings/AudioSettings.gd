extends Node

const SETTINGS_FILE = "user://audio_settings.cfg"

var master_volume: float = 1.0  # Default to full volume
var music_volume: float = 0.7
var sfx_volume: float = 0.8

func _ready():
	load_settings()
	apply_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_FILE)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		# Use default values if no settings file exists
		save_settings()
		return
	
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 0.7)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.8)

func apply_settings():
	# Convert 0-1 range to decibels (-80 to 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	
	# If you have separate buses for music and SFX, uncomment these:
	# var music_bus = AudioServer.get_bus_index("Music")
	# if music_bus >= 0:
	#     AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	
	# var sfx_bus = AudioServer.get_bus_index("SFX")
	# if sfx_bus >= 0:
	#     AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))

func set_master_volume(value: float):
	master_volume = clamp(value, 0.0, 2.0)  # Allow up to 200%
	apply_settings()
	save_settings()

func set_music_volume(value: float):
	music_volume = value
	apply_settings()
	save_settings()

func set_sfx_volume(value: float):
	sfx_volume = value
	apply_settings()
	save_settings()

func linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80.0
	# Allow boost up to +6dB for 200% volume
	return 20 * log(linear) / log(10)