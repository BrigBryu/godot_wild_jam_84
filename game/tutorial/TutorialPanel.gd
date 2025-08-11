extends Control

# Simple tutorial panel for game jam demo

@onready var panel_container: PanelContainer = $TutorialContainer
@onready var tutorial_text: RichTextLabel = $TutorialContainer/MarginContainer/VBoxContainer/TutorialText
@onready var instruction_label: Label = $TutorialContainer/MarginContainer/VBoxContainer/HBoxContainer/InstructionLabel
@onready var progress_label: Label = $TutorialContainer/MarginContainer/VBoxContainer/HBoxContainer/ProgressLabel

var current_step: int = 0
var tutorial_steps: Array = [
	{
		"title": "Welcome to Beach Critters!",
		"text": "[b]Movement:[/b] Use WASD or Arrow Keys to walk along the beach"
	},
	{
		"title": "Collecting Critters",
		"text": "[b]Interact:[/b] Press E or Space near critters to collect them"
	},
	{
		"title": "Score Points",
		"text": "[b]Goal:[/b] Collect as many beach critters as you can! Each critter gives you points"
	},
	{
		"title": "Have Fun!",
		"text": "Explore the beach and see what you can find!"
	}
]

var is_showing: bool = true

func _ready():
	# Start tutorial automatically
	show_tutorial()
	display_current_step()

func _input(event):
	if not is_showing:
		return
		
	# Progress through tutorial with Space or Enter
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		next_step()
	# Skip tutorial with Escape
	elif event.is_action_pressed("ui_cancel"):
		hide_tutorial()

func display_current_step():
	if current_step >= tutorial_steps.size():
		hide_tutorial()
		return
	
	var step = tutorial_steps[current_step]
	tutorial_text.bbcode_text = "[center][color=yellow]" + step.title + "[/color][/center]\n\n" + step.text
	
	# Update progress
	progress_label.text = "Step %d of %d" % [current_step + 1, tutorial_steps.size()]
	
	# Update instruction
	if current_step < tutorial_steps.size() - 1:
		instruction_label.text = "Press [Space/E] to continue • [ESC] to skip"
	else:
		instruction_label.text = "Press [Space/E] to start playing • [ESC] to close"

func next_step():
	current_step += 1
	if current_step >= tutorial_steps.size():
		hide_tutorial()
	else:
		display_current_step()

func show_tutorial():
	is_showing = true
	panel_container.visible = true
	# Pause the game while tutorial is showing
	get_tree().paused = true
	# But allow this node to process
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func hide_tutorial():
	is_showing = false
	panel_container.visible = false
	# Resume game
	get_tree().paused = false
	# Emit signal that tutorial is complete (optional)
	SignalBus.ui_show_interaction_hint.emit(true, "Press E to collect critters!")
	# Remove tutorial after a delay
	await get_tree().create_timer(3.0).timeout
	SignalBus.ui_show_interaction_hint.emit(false, "")
