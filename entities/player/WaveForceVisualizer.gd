class_name WaveForceVisualizer
extends Node2D

## Simple visual indicator for wave detection
## Just shows when player is in the wave

@export var enabled: bool = false  # Disabled by default
@export var indicator_color: Color = Color.CYAN

# References
var wave_detector: WaveDetector
var player: CharacterBody2D

func _ready() -> void:
	# Get references
	player = get_parent() as CharacterBody2D
	if player:
		wave_detector = player.get_node_or_null("WaveDetector") as WaveDetector
	
	# Ensure we draw on top
	z_index = 100
	show_behind_parent = false

func _process(_delta: float) -> void:
	if not enabled or not wave_detector:
		visible = false
		return
	
	visible = wave_detector.is_in_wave
	if visible:
		queue_redraw()

func _draw() -> void:
	if not enabled or not wave_detector or not wave_detector.is_in_wave:
		return
	
	# Just draw a simple wave indicator circle
	draw_circle(Vector2.ZERO, 20.0, Color(indicator_color.r, indicator_color.g, indicator_color.b, 0.3))
	draw_arc(Vector2.ZERO, 20.0, 0, TAU, 32, indicator_color, 2.0)
