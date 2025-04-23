# CaveGenerator.gd
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

# --- Cellular Automata Parameters ---
@export_group("Cave Generation Parameters")
# Percentage chance (0.0 to 1.0) for a cell to start as a wall in the initial random grid.
@export_range(0.0, 1.0, 0.01, "slider") var initial_wall_chance: float = 0.45
# How many simulation steps to run. More steps generally smooth things out.
@export_range(1, 10, 1, "slider") var simulation_iterations: int = 4
# If a floor cell has MORE than this many wall neighbors, it becomes a wall (Birth rule).
@export_range(0, 8, 1, "slider") var birth_limit: int = 4 # Equivalent to "> 4" in example
# If a wall cell has this many OR MORE wall neighbors, it stays a wall (Survival rule). Fewer = dies.
@export_range(0, 8, 1, "slider") var survival_limit: int = 4 # Equivalent to "> 3" in example

# --- Generation Trigger ---
@export_group("Generation Trigger")
var _generate_trigger := false
@export var generate_now: bool :
	get: return _generate_trigger
	set(value):
		var is_editor := Engine.is_editor_hint()
		print("Cave Setter called. value: %s, is_editor: %s" % [value, is_editor])
		if value == true and is_editor == true:
			print("Cave CONDITION MET! Validating...")
			if _validate_preconditions():
				print("Cave Validation PASSED. Calling generate_layout()...")
				generate_layout()
			else:
				printerr("Cave Validation FAILED. Cannot generate.")
		else:
			print("Cave CONDITION NOT MET. value == %s, is_editor == %s" % [value, is_editor])
		self._generate_trigger = false
		notify_property_list_changed()

# --- Constants ---
# Match the dimensions from the platform generator for consistency
const ARENA_WIDTH_TILES: int = 72
const ARENA_HEIGHT_TILES: int = 32
# Tile info for the wall/solid tile
const WALL_TILE_SOURCE_ID: int = 0
const WALL_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WALL_TILE_ALTERNATIVE: int = 0
const TILEMAP_LAYER: int = 0

# --- Internal Grid ---
# 2D array to represent our cave grid (true = wall, false = floor)
var grid : Array = []

# --- Main Generation Function ---
func generate_layout():
	print("Cave generate_layout() entered.")
	if not _validate_preconditions(): return

	# 1. Initialize the internal grid with random noise
	print("Initializing grid...")
	_initialize_grid()

	# 2. Run the cellular automata simulation
	print("Running simulation for %d iterations..." % simulation_iterations)
	_run_simulation()
	print("Simulation complete.")

	# 3. Draw the resulting grid onto the TileMap
	print("Drawing grid to TileMap...")
	_draw_grid_to_tilemap()
	print("Drawing complete.")

	# 4. Notify editor (Keep commented out if it causes hangs)
	print("Notifying editor of changes...")
	# target_tilemap.notify_property_list_changed()
	# if get_tree() and get_tree().edited_scene_root:
	# 	get_tree().edited_scene_root.set_edited(true)
	print("Skipped editor notification/dirty flag.")

	print("Cave generate_layout() finished. Remember to save the scene (Ctrl+S).")

# --- Helper Functions ---

# Creates the internal 2D array and fills it randomly based on initial_wall_chance
func _initialize_grid():
	grid.clear() # Clear previous grid if any
	grid.resize(ARENA_WIDTH_TILES) # Resize outer array
	for x in range(ARENA_WIDTH_TILES):
		grid[x] = [] # Initialize inner array
		grid[x].resize(ARENA_HEIGHT_TILES) # Resize inner array
		for y in range(ARENA_HEIGHT_TILES):
			# Set to true (wall) based on chance
			grid[x][y] = randf() < initial_wall_chance

# Runs the simulation loop
func _run_simulation():
	for i in range(simulation_iterations):
		# Important: Create a deep copy to base calculations on the previous step
		var new_grid = grid.duplicate(true)
		for x in range(ARENA_WIDTH_TILES):
			for y in range(ARENA_HEIGHT_TILES):
				var wall_neighbors : int = _count_neighboring_walls(x, y)

				if grid[x][y] == true: # If it's currently a wall
					# Wall survives if neighbor count is >= survival_limit
					new_grid[x][y] = (wall_neighbors >= survival_limit)
				else: # If it's currently a floor
					# Floor becomes a wall if neighbor count is >= birth_limit
					new_grid[x][y] = (wall_neighbors >= birth_limit)

		grid = new_grid # Update the main grid for the next iteration (or for drawing)
		print("Iteration %d complete." % (i + 1))


# Counts wall neighbors in the 8 surrounding cells (Moore neighborhood)
func _count_neighboring_walls(x: int, y: int) -> int:
	var count := 0
	for i in range(-1, 2): # Offset x by -1, 0, 1
		for j in range(-1, 2): # Offset y by -1, 0, 1
			if i == 0 and j == 0:
				continue # Skip the central cell itself

			var check_x : int = x + i
			var check_y : int = y + j

			# Check bounds: Treat out-of-bounds as a wall
			if check_x < 0 or check_x >= ARENA_WIDTH_TILES or \
			   check_y < 0 or check_y >= ARENA_HEIGHT_TILES:
				count += 1
			# If in bounds, check the grid value
			elif grid[check_x][check_y] == true: # Check if it's a wall
				count += 1
	return count


# Clears the TileMap and draws the final internal grid state
func _draw_grid_to_tilemap():
	if not is_instance_valid(target_tilemap): return

	# Clear the layer first
	var used_cells = target_tilemap.get_used_cells(TILEMAP_LAYER)
	for cell in used_cells:
		target_tilemap.set_cell(TILEMAP_LAYER, cell, -1)

	# Draw walls based on the internal grid
	for x in range(ARENA_WIDTH_TILES):
		for y in range(ARENA_HEIGHT_TILES):
			if grid[x][y] == true: # If the grid cell is a wall
				target_tilemap.set_cell(
					TILEMAP_LAYER,
					Vector2i(x, y),
					WALL_TILE_SOURCE_ID,
					WALL_TILE_ATLAS_COORDS,
					WALL_TILE_ALTERNATIVE
				)
			# else: Floor cells are left empty (already cleared)

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
		push_error("CaveGenerator: target_tilemap is not set!")
		return false
	if not target_tilemap is TileMap:
		push_error("CaveGenerator: target_tilemap node is not a TileMap!")
		return false
	if not is_instance_valid(target_tilemap.tile_set):
		push_error("CaveGenerator: target_tilemap does not have a valid TileSet assigned!")
		return false
	if target_tilemap.get_layers_count() <= TILEMAP_LAYER:
		push_error("CaveGenerator: target_tilemap does not have layer %d (Layer count: %d)!" % [TILEMAP_LAYER, target_tilemap.get_layers_count()])
		return false
	print("Cave _validate_preconditions: All checks passed.")
	return true
