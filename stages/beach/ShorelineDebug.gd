extends Node2D

@export var shore_y: float = 420.0
@export var Rmax: float = 80.0
@export var w: float = 0.45
@export var k: float = 0.0
@export var lock_vertical: bool = true
@export var show_debug: bool = true

# Computed edge position from main script (single source of truth)
var _current_edge_y: float = 420.0

func runup_from_phase(p: float, R: float) -> float:
	if p < 0.42:
		return pow(p / 0.42, 0.6) * R
	if p > 0.58:
		return (1.0 - pow((p - 0.58) / 0.42, 0.6)) * R
	return R

func _draw():
	if not show_debug:
		return
		
	var vp = get_viewport_rect().size
	
	# Draw baseline shore_y (gray)
	draw_line(Vector2(0, shore_y), Vector2(vp.x, shore_y), Color(0.7, 0.7, 0.7), 2.0)
	
	# Use the computed edge position from main script (single source of truth)
	var edge_y = _current_edge_y
	
	# Draw current edge_y (cyan)
	draw_line(Vector2(0, edge_y), Vector2(vp.x, edge_y), Color(0.2, 1.0, 1.0), 2.0)
	
	# Draw labels
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(10, shore_y - 5), "Baseline Shore", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(10, edge_y - 5), "Water Edge", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 1.0, 1.0))

func _process(_delta):
	if show_debug:
		queue_redraw()