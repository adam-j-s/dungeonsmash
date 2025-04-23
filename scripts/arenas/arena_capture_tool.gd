# Arena Capture Tool - Updated Version
@tool
extends EditorScript

# Path: res://scripts/tools/arena_capture_tool.gd (Example path)

# --- PRE-REQUISITES ---
# 1. Layout scene should have a TileMap node named exactly "Terrain".
# 2. Layout scene should have Marker2D nodes named exactly "PlayerSpawn1" and "PlayerSpawn2" placed where players should start.
# 3. (Optional) Layout scene's root node can have String Metadata named "background_path" containing the path to the desired background image.
# 4. Ensure ArenaData resource script exists (e.g., "res://scripts/arenas/arena_data.gd")

# Reference to the ArenaData resource script (adjust path if needed)
const ArenaData = preload("res://scripts/arenas/arena_data.gd")

func _run():
	# Get the currently edited scene root node
	var current_scene = get_editor_interface().get_edited_scene_root()
	if not current_scene:
		print("ERROR: No scene is currently being edited!")
		printerr("Please open the arena layout scene you want to capture.")
		return

	print("Starting capture for scene: ", current_scene.scene_file_path if current_scene.scene_file_path else "[Unsaved Scene]")

	# --- Find the TileMap ---
	var tilemap = current_scene.find_child("Terrain", true, false) # Recursive search, ignore ownership
	if not tilemap or not tilemap is TileMap:
		print("ERROR: No TileMap node named 'Terrain' found in the scene!")
		printerr("Make sure your TileMap is named 'Terrain'.")
		return
	print("Found TileMap node: 'Terrain'")

	# --- Find the Spawn Markers ---
	var spawn1_marker = current_scene.find_child("PlayerSpawn1", true, false)
	var spawn2_marker = current_scene.find_child("PlayerSpawn2", true, false)

	# --- Define Sensible Default Spawn Positions ---
	var default_spawn1_pos = Vector2(200, 500)
	var default_spawn2_pos = Vector2(current_scene.get_viewport_rect().size.x - 200 if current_scene.get_viewport_rect().size.x > 400 else 952, 500)

	# --- Get positions from markers or use defaults ---
	var spawn1_pos = default_spawn1_pos
	if spawn1_marker and spawn1_marker is Marker2D:
		spawn1_pos = spawn1_marker.global_position
		print("Found PlayerSpawn1 marker at: ", spawn1_pos)
	else:
		print("WARNING: PlayerSpawn1 marker not found or not a Marker2D! Using default position: ", default_spawn1_pos)

	var spawn2_pos = default_spawn2_pos
	if spawn2_marker and spawn2_marker is Marker2D:
		spawn2_pos = spawn2_marker.global_position
		print("Found PlayerSpawn2 marker at: ", spawn2_pos)
	else:
		print("WARNING: PlayerSpawn2 marker not found or not a Marker2D! Using default position: ", default_spawn2_pos)


	# --- Create a new ArenaData resource ---
	if ArenaData == null:
		printerr("ERROR: Failed to preload ArenaData script! Check the path.")
		return
	var arena_data = ArenaData.new()


	# --- Set properties based on the scene ---
	# NOTE: ID will be updated later with timestamp for uniqueness
	var base_id = current_scene.name.to_lower().replace(" ", "_") if current_scene.name != "" else "captured_arena"
	arena_data.id = base_id # Set temporary ID
	arena_data.name = current_scene.name.capitalize() if current_scene.name != "" else "Captured Arena"
	arena_data.description = "Arena captured from: " + (current_scene.scene_file_path if current_scene.scene_file_path else "[Unsaved Scene]")


	# --- Assign the found or default spawn positions ---
	arena_data.player_spawn_positions = [spawn1_pos, spawn2_pos]
	print("Setting spawn positions to: ", arena_data.player_spawn_positions)


	# --- Capture Background Path from Metadata (Optional) ---
	var captured_bg_path = ""
	if current_scene.has_meta("background_path"):
		captured_bg_path = current_scene.get_meta("background_path", "")
		if captured_bg_path is String and ResourceLoader.exists(captured_bg_path):
			print("Found valid background_path metadata: ", captured_bg_path)
			arena_data.background_path = captured_bg_path
		elif captured_bg_path is String:
			print("WARNING: background_path metadata found ('", captured_bg_path, "') but file does not exist! Path will be empty.")
			arena_data.background_path = ""
		else:
			print("WARNING: background_path metadata found but is not a string. Path will be empty.")
			arena_data.background_path = ""
	else:
		print("INFO: No 'background_path' metadata found on scene root. Background path will be empty.")
		arena_data.background_path = ""


	# --- Save tilemap data to the resource ---
	print("Capturing TileMap data from 'Terrain' node...")
	arena_data.save_from_tilemap(tilemap)
	print("TileMap data captured.")


	# --- Prepare Save Path ---
	var dir_path = "res://resources/arenas"
	# Ensure directory exists
	var dir = DirAccess.open("res://")
	if not dir:
		printerr("ERROR: Cannot access 'res://' directory!")
		return
	if not dir.dir_exists(dir_path):
		var make_dir_err = dir.make_dir_recursive(dir_path)
		if make_dir_err != OK:
			printerr("ERROR: Failed to create directory '", dir_path, "' Error code: ", make_dir_err)
			return
		else:
			print("Created directory: ", dir_path)

	# --- Generate Unique Filename and Update ID ---
	# Get timestamp string (YYYYMMDD_HHMMSS format)
	var timestamp = Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	# Create unique ID using base_id and timestamp
	var unique_id = "%s_%s" % [base_id, timestamp]
	# Update the ID within the ArenaData resource itself
	arena_data.id = unique_id
	# Construct the save path using this unique_id
	var save_path = dir_path.path_join(unique_id + ".tres")
	# --- End Unique Filename Generation ---


	# --- Save the resource ---
	print("Attempting to save ArenaData resource to: ", save_path)
	var result = ResourceSaver.save(arena_data, save_path)


	# --- Report Result ---
	if result == OK:
		print("SUCCESS: Arena data saved to ", save_path)
		get_editor_interface().get_resource_filesystem().scan()
	else:
		print("ERROR: Failed to save arena data! Error code: ", str(result))
		printerr("ResourceSaver failed to save to path: " + save_path)
