extends Control

@export var welcome_screen_path = "res://scenes/welcome_screen.tscn"
@export var main_game_path = "res://scenes/battle_arena.tscn"

# Call this when showing the screen
func set_winner(winner_text):
	$VBoxContainer/WinnerLabel.text = winner_text

func _ready():
	$VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

func _on_restart_pressed():
	get_tree().change_scene_to_file(main_game_path)

func _on_main_menu_pressed():
	get_tree().change_scene_to_file(welcome_screen_path)
