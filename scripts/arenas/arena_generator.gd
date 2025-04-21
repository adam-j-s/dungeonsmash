# ArenaGenerator.gd
@tool
extends Node

# --- Configuration ---
@export var target_tilemap: TileMap = null :
	set(value):
		if value is TileMap or value == null:
			target_tilemap = value
			update_configuration_warnings()
		else:
			push_warning("Assigned node is not a TileMap!")

var _generate_trigger := false

# --- Editor Trigger ---
@export var generate_now: bool :
	get:
		return _generate_trigger
	set(value):
		var is_editor = Engine.is_editor_hint()
		print("Setter called. value: %s, is_editor: %s" % [value, is_editor])
		if value == true and is_editor == true:
			print("CONDITION MET! Editor Generation Triggered! Validating...")
			if _validate_preconditions():
				print("Validation PASSED. Calling generate_layout()...")
				generate_layout() # Call the modified function below
			else:
				printerr("Validation FAILED. Cannot generate.")
		else:
			print("CONDITION NOT MET. value == %s, is_editor == %s" % [value, is_editor])
		self._generate_trigger = false
		notify_property_list_changed()

# --- Constants ---
const ARENA_WIDTH_TILES: int = 72
const ARENA_HEIGHT_TILES: int = 32
const FLOOR_Y: int = 31
const SOLID_TILE_SOURCE_ID: int = 0
const SOLID_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const SOLID_TILE_ALTERNATIVE: int = 0
const TILEMAP_LAYER: int = 0

# --- Platform Parameters ---
@export var num_platforms: int = 5
@export var min_platform_length: int = 4
@export var max_platform_length: int = 12
@export var min_platform_y: int = 5
@export var max_platform_y: int = FLOOR_Y - 5
@export var min_vertical_spacing: int = 4

# --- Generation Function using TileMap.set_cell() ---
func generate_layout():
	print("generate_layout() entered (Using TileMap.set_cell).")
	if not _validate_preconditions():
		print("generate_layout(): Validation failed, exiting.")
		return
	print("generate_layout(): Validation passed.")

	# No need to get layer_data anymore

	# 1. Clear the TileMap Layer using TileMap.set_cell
	print("Clearing existing cells using TileMap.set_cell...")
	var used_cells = target_tilemap.get_used_cells(TILEMAP_LAYER)
	for cell in used_cells:
		# Erase cell by setting source ID to -1 using the TileMap node directly
		target_tilemap.set_cell(TILEMAP_LAYER, cell, -1)
	print("Clearing complete.")

	# 2. Place Walls and Floor using TileMap.set_cell
	print("Placing walls and floor...")
	# Pass the target_tilemap node to the helper function
	_place_walls_and_floor(target_tilemap)
	print("Walls and floor placed.")

	# 3. Place Platforms using TileMap.set_cell
	print("Placing platforms...")
	# Pass the target_tilemap node to the helper function
	_place_platforms(target_tilemap)
	print("Platform placement attempt finished.") # Note: _place_platforms logs success internally

	# 4. Notify editor of changes (Still important)
	print("Notifying editor of changes...")
	#target_tilemap.notify_property_list_changed()
	#if get_tree() and get_tree().edited_scene_root:
		#get_tree().edited_scene_root.set_edited(true)

	print("generate_layout() finished. Remember to save the scene (Ctrl+S).")
# --- END MODIFIED Generation Function ---


# --- Helper Functions Modified to use TileMap ---

# Accepts TileMap node instead of tile_data
func _place_walls_and_floor(tilemap: TileMap):
	# Floor
	for x in range(ARENA_WIDTH_TILES):
		_set_solid_tile(tilemap, Vector2i(x, FLOOR_Y))
	# Left Wall
	for y in range(ARENA_HEIGHT_TILES - 1):
		_set_solid_tile(tilemap, Vector2i(0, y))
	# Right Wall
	for y in range(ARENA_HEIGHT_TILES - 1):
		_set_solid_tile(tilemap, Vector2i(ARENA_WIDTH_TILES - 1, y))

# Accepts TileMap node instead of tile_data
func _place_platforms(tilemap: TileMap):
	print("Starting platform placement for %d platforms." % num_platforms)
	var placed_platform_rects: Array[Rect2i] = []
	var attempts := 0
	# Keep max_attempts reduced for initial testing
	var max_attempts := num_platforms * 5
	print("Max attempts: %d" % max_attempts)

	while placed_platform_rects.size() < num_platforms and attempts < max_attempts:
		attempts += 1
		if attempts % 5 == 0 or attempts == 1:
			print("Attempt #%d (Placed %d/%d)" % [attempts, placed_platform_rects.size(), num_platforms])

		var plat_length := randi_range(min_platform_length, max_platform_length)
		var plat_x := randi_range(1, ARENA_WIDTH_TILES - 2 - plat_length)
		var plat_y := randi_range(min_platform_y, max_platform_y)
		var new_rect := Rect2i(plat_x, plat_y, plat_length, 1)
		var is_valid := true

		for existing_rect in placed_platform_rects:
			if abs(new_rect.position.y - existing_rect.position.y) < min_vertical_spacing:
				var existing_end_x := existing_rect.position.x + existing_rect.size.x
				var new_end_x := new_rect.position.x + new_rect.size.x
				if (new_rect.position.x < existing_end_x and new_end_x > existing_rect.position.x):
					is_valid = false
					break
		if is_valid:
			print("Attempt #%d: Placing platform at %s, length %d" % [attempts, new_rect.position, plat_length])
			for i in range(plat_length):
				# Pass tilemap node to _set_solid_tile
				_set_solid_tile(tilemap, Vector2i(plat_x + i, plat_y))
			placed_platform_rects.append(new_rect)

	print("Platform placement loop finished after %d attempts. Placed %d/%d platforms." % [attempts, placed_platform_rects.size(), num_platforms])
	if placed_platform_rects.size() < num_platforms:
		print("ArenaGenerator: Warning - Could not place all requested platforms.")

# Accepts TileMap node instead of tile_data, uses tilemap.set_cell
func _set_solid_tile(tilemap: TileMap, coords: Vector2i):
	if not is_instance_valid(tilemap): # Check if tilemap node is valid
		printerr("_set_solid_tile: tilemap node is invalid!")
		return
	tilemap.set_cell( # Call set_cell on the TileMap node directly
		TILEMAP_LAYER,
		coords,
		SOLID_TILE_SOURCE_ID,
		SOLID_TILE_ATLAS_COORDS,
		SOLID_TILE_ALTERNATIVE
	)

# --- Validation and Warnings (Unchanged) ---
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_instance_valid(target_tilemap):
		warnings.append("Target TileMap is not assigned!")
	elif not target_tilemap is TileMap:
		warnings.append("Assigned Target TileMap node is not a TileMap!")
	return warnings

func _validate_preconditions() -> bool:
	if not is_instance_valid(target_tilemap):
		push_error("ArenaGenerator: target_tilemap is not set!")
		return false
	if not target_tilemap is TileMap:
		push_error("ArenaGenerator: target_tilemap node is not a TileMap!")
		return false
	if not is_instance_valid(target_tilemap.tile_set):
		push_error("ArenaGenerator: target_tilemap does not have a valid TileSet assigned!")
		return false
	if target_tilemap.get_layers_count() <= TILEMAP_LAYER:
		push_error("ArenaGenerator: target_tilemap does not have layer %d (Layer count: %d)!" % [TILEMAP_LAYER, target_tilemap.get_layers_count()])
		return false
	print("_validate_preconditions: All checks passed.")
	return true
# --- END Validation Function ---


# --- Spawn Point Placement (Unchanged) ---
func place_spawn_points(spawn1: Marker2D, spawn2: Marker2D):
	if not is_instance_valid(target_tilemap): return
	if not is_instance_valid(spawn1) or not is_instance_valid(spawn2): return
	var spawn_y := FLOOR_Y - 2
	var spawn1_x := 3
	var spawn2_x := ARENA_WIDTH_TILES - 4
	spawn1.position = target_tilemap.map_to_local(Vector2i(spawn1_x, spawn_y))
	spawn2.position = target_tilemap.map_to_local(Vector2i(spawn2_x, spawn_y))
	print("Spawn points placed.")
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		get_tree().edited_scene_root.set_edited(true)
