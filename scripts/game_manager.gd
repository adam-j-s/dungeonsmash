extends Node

# Character selection
var player1_character: String = "knight"
var player2_character: String = "wizard"

# Game results
var winner: int = 0  # 0 = none/draw, 1 = player1, 2 = player2

# Function to start game flow
func start_game():
	# Go to character select screen
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

# Function to start battle with selected characters
func start_battle():
	var battle_scene = load("res://scenes/battle_arena.tscn").instantiate()
	
	# Set player character classes
	var player1 = battle_scene.get_node("Player1")
	if player1:
		player1.character_class_id = player1_character
	
	var player2 = battle_scene.get_node("Player2") 
	if player2:
		player2.character_class_id = player2_character
	
	# Change to battle scene
	get_tree().root.add_child(battle_scene)
	
# Function to handle end of battle
func end_battle(winner_player: int):
	winner = winner_player
