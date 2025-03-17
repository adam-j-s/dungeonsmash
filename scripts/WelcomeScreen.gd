extends Control

# Path to your main game scene
@export var game_scene_path = "res://scenes/battle_arena.tscn"

func _ready():
	# Connect the button's pressed signal
	$StartButton.pressed.connect(_on_start_button_pressed)
	
	# Background animation
	var tween = create_tween().set_loops()
	tween.tween_property($Background, "modulate", Color(0.9, 0.9, 1.0), 2.0)
	tween.tween_property($Background, "modulate", Color(1.0, 0.9, 0.9), 2.0)
	
func _process(_delta):
	# Start game when any button is pressed
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p2_jump"):
		_on_start_button_pressed() # Come back and add in 'start' button
		
func _on_start_button_pressed():
	# Change to the game scene
	get_tree().change_scene_to_file(game_scene_path)
