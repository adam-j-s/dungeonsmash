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
	#Implement migration tool
	
	#var migration_tool = load("res://scripts/system-migration-tool.gd").new()
	#migration_tool.enable_new_projectile_system = true
	#migration_tool.replace_projectile_script = true
	#add_child(migration_tool)
	#migration_tool.start_migration()

# Function to start game flow
func start_game():
	# Go to character select screen
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

# Function to start battle with selected characters
func start_battle():
	# Set the first available arena as current (if one exists)
	var arena_ids = ArenaDatabase.get_all_arena_ids()
	if arena_ids.size() > 0:
		ArenaDatabase.set_current_arena(arena_ids[0])
		print("Set current arena to: " + ArenaDatabase.current_arena_id)
	else:
		print("No arenas available in database")
	
	# Load the battle scene
	var battle_scene = load("res://scenes/battle_arena.tscn").instantiate()
	
	# Set player character classes directly in GameManager for the battle scene to access
	GameManager.player1_character = player1_character
	GameManager.player2_character = player2_character
	
	# Note: We no longer need to set character classes here as the battle_arena.gd script
	# will now read these values from the GameManager in its _ready() function
	
	# Change to battle scene
	get_tree().root.add_child(battle_scene)
	
# Function to handle end of battle
func end_battle(winner_player: int):
	winner = winner_player
