# arena_capture_tool.gd
@tool
extends EditorScript

func _run():
	# Get the currently edited scene
	var current_scene = get_editor_interface().get_edited_scene_root()
	if not current_scene:
		print("No scene is currently being edited!")
		return
	
	# Find the tilemap in the scene
	var tilemap = null
	for child in current_scene.get_children():
		if child is TileMap:
			tilemap = child
			break
	
	if not tilemap:
		print("No TileMap found in the scene!")
		return
	
	# Create a new ArenaData resource
	var arena_data = ArenaData.new()
	
	# Set basic properties
	arena_data.id = "default_arena"
	arena_data.name = "Default Arena"
	arena_data.description = "The original battle arena"
	
	# Use hardcoded spawn positions - EDIT THESE to match your actual player positions
	# These are just example positions - replace with your actual player starting positions
	arena_data.player_spawn_positions = [Vector2(400, 500), Vector2(1520, 500)]
	
	# Save tilemap data to the resource
	arena_data.save_from_tilemap(tilemap)
	
	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://resources/arenas"):
		dir.make_dir_recursive("res://resources/arenas")
	
	# Save the resource
	var result = ResourceSaver.save(arena_data, "res://resources/arenas/default_arena.tres")
	
	if result == OK:
		print("Arena data saved successfully to res://resources/arenas/default_arena.tres")
	else:
		print("Failed to save arena data! Error code: " + str(result))
