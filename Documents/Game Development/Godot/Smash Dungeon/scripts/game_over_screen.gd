extends Control

@export var welcome_screen_path = "res://scenes/welcome_screen.tscn"
@export var character_select_path = "res://scenes/character_select.tscn"
@export var main_game_path = "res://scenes/battle_arena.tscn"

# Track which button is currently selected
var current_button = 0
var buttons = []

# Call this when showing the screen
func set_winner(winner_text):
	$VBoxContainer/WinnerLabel.text = winner_text
	
	# Add character info
	var character_info = Label.new()
	var p1_class = CharacterClasses.get_character_class(GameManager.player1_character).name
	var p2_class = CharacterClasses.get_character_class(GameManager.player2_character).name
	character_info.text = "Player 1: " + p1_class + " vs Player 2: " + p2_class
	character_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$VBoxContainer.add_child(character_info)
	$VBoxContainer.move_child(character_info, 1)  # Place it right after the winner label

func _ready():
	# Store references to buttons
	buttons = [$VBoxContainer/RestartButton, $VBoxContainer/CharSelectButton, $VBoxContainer/MainMenuButton]
	
	# Connect button signals
	$VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBoxContainer/CharSelectButton.pressed.connect(_on_char_select_pressed)
	$VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	
	# Set initial focus to first button
	buttons[current_button].grab_focus()

func _process(_delta):
	# Handle button navigation with player 1 controller/keyboard
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_right"):
		current_button = min(current_button + 1, buttons.size() - 1)
		buttons[current_button].grab_focus()
	
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_left"):
		current_button = max(current_button - 1, 0)
		buttons[current_button].grab_focus()
	
	# Handle button navigation with player 2 controller
	if Input.is_action_just_pressed("p2_down") or Input.is_action_just_pressed("p2_right"):
		current_button = min(current_button + 1, buttons.size() - 1)
		buttons[current_button].grab_focus()
	
	if Input.is_action_just_pressed("p2_up") or Input.is_action_just_pressed("p2_left"):
		current_button = max(current_button - 1, 0)
		buttons[current_button].grab_focus()
	
	# Select the focused button with either player's inputs
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_attack") or Input.is_action_just_pressed("p2_attack") or Input.is_action_just_pressed("p2_accept"):
		buttons[current_button].emit_signal("pressed")

func _on_restart_pressed():
	# Same characters, new battle
	get_tree().change_scene_to_file(main_game_path)

func _on_char_select_pressed():
	# Go back to character selection
	get_tree().change_scene_to_file(character_select_path)

func _on_main_menu_pressed():
	get_tree().change_scene_to_file(welcome_screen_path)
