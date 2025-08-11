extends Control

# Simple HUD with just score, timer, and critter count

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var critter_count_label: Label = $TopBar/CritterCountLabel
@onready var interaction_hint: Label = $InteractionHint

var total_score: int = 0
var critters_collected: int = 0
var total_critters: int = 0

func _ready():
	# Connect to SignalBus events
	SignalBus.ui_show_interaction_hint.connect(_on_show_interaction_hint)
	SignalBus.critter_collected.connect(_on_critter_collected)
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.stage_generation_completed.connect(_on_stage_completed)
	
	# No timer for now - just walking on beach
	
	# Hide interaction hint initially
	if interaction_hint:
		interaction_hint.visible = false
	
	update_display()

func _on_show_interaction_hint(show: bool, hint_text: String):
	"""Show/hide interaction hint"""
	if interaction_hint:
		interaction_hint.visible = show
		if show and hint_text != "":
			interaction_hint.text = hint_text

func _on_timer_updated(time_remaining: float):
	"""Update timer display - not used for now"""
	pass

func _on_score_changed(new_score: int, score_change: int):
	"""Update score display"""
	total_score = new_score
	update_display()

func _on_critter_collected(critter_info: Dictionary):
	"""Update collection count"""
	critters_collected += 1
	update_display()

func _on_stage_completed(critter_count: int):
	"""Set total critter count"""
	total_critters = critter_count
	update_display()

func update_display():
	"""Update all HUD elements"""
	if score_label:
		score_label.text = "Score: %d" % total_score
	
	if critter_count_label:
		critter_count_label.text = "Critters: %d" % critters_collected
	
	if timer_label:
		# No timer - just show empty or remove from HUD
		timer_label.visible = false
