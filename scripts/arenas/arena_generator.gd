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

# --- Platform Parameters with Sliders (Explicit Hint Added) ---
@export_group("Horizontal Platforms")
@export_range(0, 30, 1, "slider") var num_platforms: int = 5 # Added "slider" hint
@export_range(1, 40, 1, "slider") var min_platform_length: int = 4
@export_range(1, 40, 1, "slider") var max_platform_length: int = 12
@export_range(1, 30, 1, "slider") var min_platform_y: int = 5
@export_range(1, 30, 1, "slider") var max_platform_y: int = 31 - 5
@export_range(1, 15, 1, "slider") var min_vertical_spacing: int = 4

@export_group("Vertical Platforms")
@export_range(0, 20, 1, "slider") var num_vertical_platforms: int = 2
@export_range(2, 25, 1, "slider") var min_vertical_platform_height: int = 3
@export_range(2, 25, 1, "slider") var max_vertical_platform_height: int = 8
@export_range(1, 70, 1, "slider") var min_vertical_platform_x: int = 5
@export_range(1, 70, 1, "slider") var max_vertical_platform_x: int = 72 - 6
@export_range(1, 20, 1, "slider") var min_horizontal_spacing: int = 5

@export_group("Diagonal Lines")
@export_range(0, 20, 1, "slider") var num_diagonal_lines: int = 2
@export_range(2, 25, 1, "slider") var min_diagonal_length: int = 4
@export_range(2, 25, 1, "slider") var max_diagonal_length: int = 10
@export var diagonals_avoid_solids: bool = true # Boolean remains checkbox

@export_group("Generation Trigger")
@export var generate_now: bool :
	get:
		return _generate_trigger
	set(value):
		var is_editor := Engine.is_editor_hint()
		print("Setter called. value: %s, is_editor: %s" % [value, is_editor])
		if value == true and is_editor == true:
			print("CONDITION MET! Editor Generation Triggered! Validating...")
			if _validate_preconditions():
				print("Validation PASSED. Calling generate_layout()...")
				generate_layout()
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

# --- Generation Function using TileMap.set_cell() ---
func generate_layout():
	print("generate_layout() entered (Using TileMap.set_cell).")
	if not _validate_preconditions():
		print("generate_layout(): Validation failed, exiting.")
		return
	print("generate_layout(): Validation passed.")

	# 1. Clear the TileMap Layer
	print("Clearing existing cells using TileMap.set_cell...")
	var used_cells = target_tilemap.get_used_cells(TILEMAP_LAYER)
	for cell in used_cells:
		target_tilemap.set_cell(TILEMAP_LAYER, cell, -1)
	print("Clearing complete.")

	# 2. Place Walls and Floor (Includes ceiling now)
	print("Placing walls, floor, and ceiling...")
	_place_walls_and_floor(target_tilemap)
	print("Boundaries placed.")

	# 3. Place HORIZONTAL Platforms
	print("Placing horizontal platforms...")
	var horizontal_rects : Array[Rect2i] = _place_platforms(target_tilemap)
	print("Horizontal platform placement attempt finished.")

	# 4. Place VERTICAL Platforms
	print("Placing vertical platforms...")
	var vertical_rects : Array[Rect2i] = _place_vertical_platforms(target_tilemap, horizontal_rects)
	print("Vertical platform placement attempt finished.")

	# 5. Place DIAGONAL Lines
	print("Placing diagonal lines...")
	_place_diagonal_lines(target_tilemap)
	print("Diagonal line placement attempt finished.")

	# 6. Notify editor of changes (Keep commented out if it causes hangs)
	print("Notifying editor of changes...")
	# target_tilemap.notify_property_list_changed()
	# if get_tree() and get_tree().edited_scene_root:
	# 	get_tree().edited_scene_root.set_edited(true)
	print("Skipped editor notification/dirty flag for testing.") # Keep this if notifications are commented

	print("generate_layout() finished. Remember to save the scene (Ctrl+S).")
# --- END Generation Function ---


# --- Helper Functions ---

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
	# Ceiling
	for x in range(ARENA_WIDTH_TILES):
		_set_solid_tile(tilemap, Vector2i(x, 0))

# Places horizontal platforms and returns their bounding boxes
func _place_platforms(tilemap: TileMap) -> Array[Rect2i]:
	print("Starting horizontal platform placement for %d platforms." % num_platforms)
	var placed_platform_rects: Array[Rect2i] = []
	var attempts := 0
	var max_attempts := num_platforms * 10

	while placed_platform_rects.size() < num_platforms and attempts < max_attempts:
		attempts += 1
		if attempts % 5 == 0 or attempts == 1:
			print("H_Attempt #%d (Placed %d/%d)" % [attempts, placed_platform_rects.size(), num_platforms])

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
		if not is_valid: continue

		if is_valid:
			print("H_Attempt #%d: Placing horizontal platform at %s, length %d" % [attempts, new_rect.position, plat_length])
			for i in range(plat_length):
				_set_solid_tile(tilemap, Vector2i(plat_x + i, plat_y))
			placed_platform_rects.append(new_rect)

	print("Horizontal platform placement loop finished after %d attempts. Placed %d/%d platforms." % [attempts, placed_platform_rects.size(), num_platforms])
	if placed_platform_rects.size() < num_platforms:
		print("ArenaGenerator: Warning - Could not place all requested horizontal platforms.")

	return placed_platform_rects


# Places vertical platforms, checking against horizontal ones
func _place_vertical_platforms(tilemap: TileMap, existing_horizontal_rects: Array[Rect2i]) -> Array[Rect2i]:
	print("Starting vertical platform placement for %d platforms." % num_vertical_platforms)
	var placed_vertical_rects: Array[Rect2i] = []
	var attempts := 0
	var max_attempts := num_vertical_platforms * 10

	while placed_vertical_rects.size() < num_vertical_platforms and attempts < max_attempts:
		attempts += 1
		if attempts % 5 == 0 or attempts == 1:
			print("V_Attempt #%d (Placed %d/%d)" % [attempts, placed_vertical_rects.size(), num_vertical_platforms])

		var plat_height := randi_range(min_vertical_platform_height, max_vertical_platform_height)
		var plat_x := randi_range(min_vertical_platform_x, max_vertical_platform_x)
		var plat_y := randi_range(1, ARENA_HEIGHT_TILES - 2 - plat_height) # Avoid ceiling/floor
		var new_rect := Rect2i(plat_x, plat_y, 1, plat_height)
		var is_valid := true

		# Check against other VERTICAL platforms
		for existing_rect in placed_vertical_rects:
			if abs(new_rect.position.x - existing_rect.position.x) < min_horizontal_spacing:
				var existing_end_y := existing_rect.position.y + existing_rect.size.y
				var new_end_y := new_rect.position.y + new_rect.size.y
				if (new_rect.position.y < existing_end_y and new_end_y > existing_rect.position.y):
					is_valid = false
					break
		if not is_valid: continue

		# Check against HORIZONTAL platforms
		for existing_horz_rect in existing_horizontal_rects:
			if new_rect.intersects(existing_horz_rect.grow_side(SIDE_LEFT, 1).grow_side(SIDE_RIGHT, 1)):
				is_valid = false
				break
		if not is_valid: continue

		# Check walls (redundant but safe)
		if plat_x <= 0 or plat_x >= ARENA_WIDTH_TILES -1:
			is_valid = false
			continue

		if is_valid:
			print("V_Attempt #%d: Placing vertical platform at %s, height %d" % [attempts, new_rect.position, plat_height])
			for i in range(plat_height):
				_set_solid_tile(tilemap, Vector2i(plat_x, plat_y + i))
			placed_vertical_rects.append(new_rect)

	print("Vertical platform placement loop finished after %d attempts. Placed %d/%d platforms." % [attempts, placed_vertical_rects.size(), num_vertical_platforms])
	if placed_vertical_rects.size() < num_vertical_platforms:
		print("ArenaGenerator: Warning - Could not place all requested vertical platforms.")

	return placed_vertical_rects

# Places diagonal lines
func _place_diagonal_lines(tilemap: TileMap):
	print("Starting diagonal line placement for %d lines." % num_diagonal_lines)
	var directions := [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	var lines_placed := 0

	for _i in range(num_diagonal_lines):
		var line_length := randi_range(min_diagonal_length, max_diagonal_length)
		var start_x := randi_range(2, ARENA_WIDTH_TILES - 3)
		var start_y := randi_range(2, FLOOR_Y - 2)
		var start_pos := Vector2i(start_x, start_y)
		var direction : Vector2i = directions[randi() % directions.size()]

		print("D_Attempt: Placing diagonal line from %s, dir %s, length %d" % [start_pos, direction, line_length])
		var placed_any_tile := false
		for l in range(line_length):
			var current_pos : Vector2i = start_pos + direction * l

			# Bounds check
			if current_pos.x <= 0 or current_pos.x >= ARENA_WIDTH_TILES - 1 or \
			   current_pos.y <= 0 or current_pos.y >= FLOOR_Y:
				print("D_Attempt: Went out of bounds at %s. Stopping line." % current_pos)
				break

			# Overlap check (optional)
			if diagonals_avoid_solids:
				var existing_tile_source := tilemap.get_cell_source_id(TILEMAP_LAYER, current_pos)
				if existing_tile_source != -1:
					print("D_Attempt: Hit existing tile at %s. Stopping line." % current_pos)
					break

			_set_solid_tile(tilemap, current_pos)
			placed_any_tile = true

		if placed_any_tile:
			lines_placed += 1

	print("Diagonal line placement finished. Placed segments for %d/%d lines." % [lines_placed, num_diagonal_lines])

# Sets a solid tile using TileMap.set_cell
func _set_solid_tile(tilemap: TileMap, coords: Vector2i):
	if not is_instance_valid(tilemap):
		printerr("_set_solid_tile: tilemap node is invalid!")
		return
	tilemap.set_cell(
		TILEMAP_LAYER,
		coords,
		SOLID_TILE_SOURCE_ID,
		SOLID_TILE_ATLAS_COORDS,
		SOLID_TILE_ALTERNATIVE
	)

# --- Validation and Warnings ---
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

# --- Spawn Point Placement ---
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
