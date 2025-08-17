extends Node

# Centralized game settings manager

const SETTINGS_FILE = "user://game_settings.cfg"

# Default settings
var settings = {
	"audio": {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0
	},
	"graphics": {
		"resolution": Vector2(1280, 720),
		"fullscreen": false,
		"vsync": true,
		"quality": "medium"
	},
	"gameplay": {
		"show_interaction_hints": true,
		"auto_save": true,
		"difficulty": "normal",
		"game_duration": 30.0
	},
	"controls": {
		"move_speed_modifier": 1.0,
		"mouse_sensitivity": 1.0
	}
}

func _ready():
	load_settings()

func get_setting(key_path: String):
	var keys = key_path.split(".")
	var current = settings
	
	for key in keys:
		if key in current:
			current = current[key]
		else:
			return null
	
	return current

func set_setting(key_path: String, value):
	var keys = key_path.split(".")
	var current = settings
	
	for i in range(keys.size() - 1):
		var key = keys[i]
		if key in current:
			current = current[key]
		else:
			current[key] = {}
			current = current[key]
	
	current[keys[-1]] = value
	save_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err != OK:
		push_warning("Settings file not found, using defaults")
		save_settings()
		return
	
	for section in config.get_sections():
		if section in settings:
			for key in config.get_section_keys(section):
				settings[section][key] = config.get_value(section, key)

func save_settings():
	var config = ConfigFile.new()
	
	for section in settings:
		for key in settings[section]:
			config.set_value(section, key, settings[section][key])
	
	config.save(SETTINGS_FILE)