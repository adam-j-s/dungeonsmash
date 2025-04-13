extends Node

# Character selection
var player1_character: String = "knight"
var player2_character: String = "wizard"

# Game results
var winner: int = 0  # 0 = none/draw, 1 = player1, 2 = player2

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
		get_tree().call_deferred("quit")
		
# Function to start game flow
func start_game():
	# Go to character select screen
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

# Function to start battle with selected characters
func start_battle():
	var arena_to_load_id = "my_new_arena" #start by hardcoding the first arena ID
	var battle_scene_path = "res://scenes/battle_arena.tscn"
	var loaded_successfully = false #Flag to track if data-driven load worked
	
	print("GameManager: Attempting to start battle...")
	
	# Set player character classes directly in GameManager for the battle scene to access
	GameManager.player1_character = player1_character
	GameManager.player2_character = player2_character
	print("GameManager: Set player characters for next scene: P1=", player1_character, "P2=", player2_character)
	
		
	#Optional check to make sure it actually exists in database
	if ArenaDatabase != null:
		print("GameManager: ArenaDatabase is NOT null.")
		if ArenaDatabase.arenas.has(arena_to_load_id):
			print("GameManager: ArenaDatabase HAS arena_id '", arena_to_load_id, "'.")
			print("GameManager: ArenaDatabase found and has ID '" + arena_to_load_id + "'. Requesting load.")
			print("GameManager: >>> Calling ArenaDatabase.load_battle_with_arena NOW...")
			#ArenaDatabase.load_battle_with_arena should set current_arena_data AND change scene
			# Returns true on success (change_scene_to_file returns ok)	
			loaded_successfully = ArenaDatabase.load_battle_with_arena(arena_to_load_id, battle_scene_path)
			print("GameManager: <<< Returned from ArenaDatabase.load_battle_with_arena. Success = ", loaded_successfully)
			
			if not loaded_successfully:
				print("WARNING in GameManager: ArenaDatabase.load_battle_with_arena reported failure for ID '" + arena_to_load_id + "'. Will attempt fallback load.")	
		else:
			print("GameManager: ArenaDatabase DOES NOT HAVE arena_id '", arena_to_load_id, "'.")
			print("WARNING in GameManager: Arena ID '" + arena_to_load_id + "' not found in ArenaDatabase. Will attempt fallback load.")
			# loaded_successfully remains false
	else:
		print("GameManager: ArenaDatabase IS null at this point.")
		print("WARNING in GameManager: ArenaDatabase singleton is null. Cannot load arena data. Will attempt fallback load.")
		#loaded_successfully remains false
	if not loaded_successfully:
		print("GameManager: Falling back - loading default battle scene layout directly.")
		 		
		# Explicitly clear current_arena_data IF database exists
		#Ensures battle_arena.gd doesn't try to load bad data if DB exists but specific ID/load failed
		if ArenaDatabase != null:
			ArenaDatabase.current_arena_data = null
			ArenaDatabase.current_arena_id = "" #Also clear the ID
					
		#Attempt to lead the scene directly
		var error_code = get_tree().change_scene_to_file("res://scenes/battle_arena.tscn")	
		
		#Handle last resort error (fallback failed)
		
		if error_code != OK:
			print("CRITICAL ERROR in GameManager: Fallback scene load ('" + battle_scene_path + "') failed! Error code: ", error_code)
			
			#last resort - go back to menue or show error screen
			get_tree().change_scene_to_file("res://scenes/welcome_screen.tscn")	

# Function to handle end of battle
func end_battle(winner_player: int):
	winner = winner_player
