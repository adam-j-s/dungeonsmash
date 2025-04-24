# arena_data.gd
extends Resource
class_name ArenaData

@export var id: String = "arena_01"
@export var name: String = "Default Arena"
@export var description: String = "A standard battle arena"
@export var difficulty: int = 1
@export var thumbnail_path: String = "res://assets/thumbnails/default_arena.png"

# Visual theming
@export var theme_name: String = "dungeon"
@export var background_path: String = "res://assets/backgrounds/dungeon.png"
@export var music_path: String = "res://assets/music/battle_01.ogg"

# Layout details
@export var size: Vector2 = Vector2(1920, 1080)
# Changed to regular Array to avoid typing issues
@export var player_spawn_positions: Array = [Vector2(400, 500), Vector2(1520, 500)]

# Tilemap data
@export var tilemap_path: String = "res://assets/tilesets/default_tileset.tres"
@export var tilemap_data: Dictionary = {}  # Will store layer/cell data

# Metadata
@export var available_in_multiplayer: bool = true
@export var available_in_singleplayer: bool = false

# Save the current state of a tilemap to this resource
func save_from_tilemap(tilemap: TileMap) -> void:
	tilemap_data.clear()
	
	# Store the tileset path if possible
	if tilemap.tile_set and ResourceLoader.exists(tilemap.tile_set.resource_path):
		tilemap_path = tilemap.tile_set.resource_path
	
	# For each layer in the tilemap
	for layer_index in range(tilemap.get_layers_count()):
		var layer_data = {}
		
		# Get all cells in this layer
		var used_cells = tilemap.get_used_cells(layer_index)
		
		# Store each cell's data
		for cell_pos in used_cells:
			var source_id = tilemap.get_cell_source_id(layer_index, cell_pos)
			var atlas_coords = tilemap.get_cell_atlas_coords(layer_index, cell_pos)
			var alternative_tile = tilemap.get_cell_alternative_tile(layer_index, cell_pos)
			
			# Only store cells that have valid data
			if source_id != -1:
				# Convert Vector2i to string key
				var cell_key = str(cell_pos.x) + "," + str(cell_pos.y)
				layer_data[cell_key] = {
					"source_id": source_id,
					"atlas_coords": [atlas_coords.x, atlas_coords.y],
					"alternative_tile": alternative_tile
				}
		
		# Add layer data if not empty
		if not layer_data.is_empty():
			tilemap_data[str(layer_index)] = layer_data

# Apply stored data to a tilemap
func apply_to_tilemap(tilemap: TileMap) -> void:
	# Clear the tilemap first
	tilemap.clear()
	
	# Try to load the tileset if it's different
	if not tilemap_path.is_empty() and (tilemap.tile_set == null or tilemap.tile_set.resource_path != tilemap_path):
		var tile_set = load(tilemap_path)
		if tile_set:
			tilemap.tile_set = tile_set
	
	# For each layer in our stored data
	for layer_str in tilemap_data.keys():
		var layer_index = int(layer_str)
		var layer_data = tilemap_data[layer_str]
		
		# For each cell in this layer
		for cell_key in layer_data.keys():
			var cell_data = layer_data[cell_key]
			
			# Convert string key back to Vector2i position
			var coords = cell_key.split(",")
			var cell_pos = Vector2i(int(coords[0]), int(coords[1]))
			
			# Get cell data
			var source_id = cell_data.source_id
			var atlas_coords = Vector2i(cell_data.atlas_coords[0], cell_data.atlas_coords[1])
			var alternative_tile = cell_data.alternative_tile
			
			# Set the cell in the tilemap
			tilemap.set_cell(layer_index, cell_pos, source_id, atlas_coords, alternative_tile)
