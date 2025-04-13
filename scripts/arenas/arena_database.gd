# Arena Database
extends Node

var arenas: Dictionary = {}
var arena_list: Array[String] = []
var current_arena_id: String = ""
var current_arena_data: ArenaData = null

const ARENA_DIR = "res://resources/arenas/"
const ARENA_EXTENSION = ".tres"
const DEBUG = true

func _ready():
	load_all_arenas()
	print("ArenaDatabase _ready() completed successfully.")
func load_all_arenas() -> void:
	arenas.clear()
	arena_list.clear()
	
	# Check for arenas in the resources directory
	var dir = DirAccess.open(ARENA_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(ARENA_EXTENSION):
				var arena_id = file_name.get_basename()
				var arena_path = ARENA_DIR + file_name
				var arena = load(arena_path) as ArenaData
				
				if arena:
					arenas[arena_id] = arena
					arena_list.append(arena_id)
					print("Loaded arena: ", arena.name)
				
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# If no arenas were loaded, create a default one
	if arenas.is_empty():
		print("No arenas found! Create a default arena first.")
	else:
		print("Loaded ", arenas.size(), " arenas")


func get_arena(arena_id: String) -> ArenaData:
	if arenas.has(arena_id):
		return arenas[arena_id]
	return null

func set_current_arena(arena_id: String) -> bool:
	if arenas.has(arena_id):
		current_arena_id = arena_id
		current_arena_data = arenas[arena_id]
		return true
	return false

func get_all_arena_ids() -> Array[String]:
	return arena_list

func get_multiplayer_arenas() -> Array[String]:
	var result: Array[String] = []
	for id in arena_list:
		if arenas[id].available_in_multiplayer:
			result.append(id)
	return result

# Load the battle scene and apply arena data
func load_battle_with_arena(arena_id: String, battle_scene_path: String) -> bool:
	print("ArenaDatabase: load_battle_with_arena called with ID: ", arena_id) # <-- ADD
	if not arenas.has(arena_id):
		push_error("Arena ID not found: " + arena_id)
		print("ArenaDatabase: Arena ID not found, returning false.") # <-- ADD
		return false

	# Set as current arena
	current_arena_id = arena_id
	current_arena_data = arenas[arena_id]
	print("ArenaDatabase: Set current_arena_data to: ", current_arena_data) # <-- ADD (Will print the resource object)
	if current_arena_data != null:
		print("ArenaDatabase: current_arena_data.name is: ", current_arena_data.name) # <-- ADD (Verify data)

	# Load the battle scene
	var error_code = get_tree().change_scene_to_file(battle_scene_path)
	print("ArenaDatabase: change_scene_to_file result: ", error_code) # <-- ADD (Should be 0 for OK)

	if error_code != OK:
		print("ArenaDatabase: Scene change failed! Returning false.") # <-- ADD
		# Optionally clear data again if scene change failed?
		# current_arena_data = null
		# current_arena_id = ""
		return false
	else:
		print("ArenaDatabase: Scene change initiated successfully. Returning true.") # <-- ADD
		return true
