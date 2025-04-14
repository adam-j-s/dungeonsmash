extends Node

# Character selection
var player1_character: String = "knight"
var player2_character: String = "wizard"

# Variable to store the chosen arena ID
var selected_arena_id: String = "default_arena" #Default/fallback arena ID
# Game results
var winner: int = 0  # 0 = none/draw, 1 = player1, 2 = player2

# DEBUG
const DEBUG = true

# Initialize systems
func _ready():
	# Enable new projectile system
	ProjectSettings.set_setting("game/use_new_projectile_system", true)
	print("New projectile system enabled")
	
func _input(event): # Or _unhandled_input if you prefer now that it's not Escape
	# Check for the custom quit action mapped to 'P'
	if event.is_action_pressed("debug_quit"):
		print("Debug Quit action detected. Consuming event and requesting quit...")
		get_viewport().set_input_as_handled() # Still good practice
		get_tree().quit()
		print("Quit command issued.")
		
# Function to start game flow
func start_game():
	# Go to character select screen
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

# Function to start battle with selected characters
func start_battle():
	var arena_to_load_id = selected_arena_id
	var battle_scene_path = "res://scenes/battle_arena.tscn"
	var loaded_successfully = false # Flag to track if data-driven load worked

	if DEBUG:
		print("GameManager: Attempting to start battle with selected arena: '", arena_to_load_id, "'")

	# Step 1 - Set player characters first
	GameManager.player1_character = player1_character
	GameManager.player2_character = player2_character
	
	if DEBUG:
		print("GameManager: Set player characters for next scene: P1=", player1_character, "P2=", player2_character)

	# Step 2 - try preferred data-driven load	
	if ArenaDatabase != null:
		if DEBUG:
			print("GameManager: ArenaDatabase is NOT null.")
		
		if ArenaDatabase.arenas.has(arena_to_load_id):
			if DEBUG:
				print("GameManager: ArenaDatabase HAS arena_id '", arena_to_load_id, "'.")
				print("GameManager: ArenaDatabase found and has ID '" + arena_to_load_id + "'. Requesting load.")
				print("GameManager: >>> Calling ArenaDatabase.load_battle_with_arena NOW...")
				
			loaded_successfully = ArenaDatabase.load_battle_with_arena(arena_to_load_id, battle_scene_path)
			
			if DEBUG:
				print("GameManager: <<< Returned from ArenaDatabase.load_battle_with_arena. Success = ", loaded_successfully)

			if not loaded_successfully and DEBUG:
				print("WARNING in GameManager: ArenaDatabase.load_battle_with_arena reported failure for ID '" + arena_to_load_id + "'. Will attempt fallback load.")	
		else:
			if DEBUG:
				print("GameManager: ArenaDatabase DOES NOT HAVE arena_id '", arena_to_load_id, "'.")
				print("WARNING in GameManager: Arena ID '" + arena_to_load_id + "' not found in ArenaDatabase. Will attempt fallback load.")
	else:
		if DEBUG:
			print("GameManager: ArenaDatabase IS null at this point.")
			print("WARNING in GameManager: ArenaDatabase singleton is null. Cannot load arena data. Will attempt fallback load.")
	
	if not loaded_successfully:
		if DEBUG:
			print("GameManager: Falling back - loading default battle scene layout directly.")
		
		if ArenaDatabase != null:
			ArenaDatabase.current_arena_data = null
			ArenaDatabase.current_arena_id = ""

		var error_code = get_tree().change_scene_to_file("res://scenes/battle_arena.tscn")
		
		if error_code != OK:
			if DEBUG:
				print("CRITICAL ERROR in GameManager: Fallback scene load ('" + battle_scene_path + "') failed! Error code: ", error_code)
			
			get_tree().change_scene_to_file("res://scenes/welcome_screen.tscn")


# Function to handle end of battle
func end_battle(winner_player: int):
	winner = winner_player
