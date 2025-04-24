# ArenaScene.gd (Script for the root Node2D of your Arena template scene)
extends Node2D

# Get references to the important child nodes
@onready var generator = $ArenaGenerator
@onready var terrain_tilemap = $Terrain # Assuming your TileMap is named Terrain
@onready var spawn1 = $PlayerSpawn1
@onready var spawn2 = $PlayerSpawn2

# Called when the node enters the scene tree (e.g., when you run this scene)
func _ready():
	# --- REMOVED ---
	# No longer automatically generating layout here.
	# Generation is now triggered manually via the Inspector.
	# --- REMOVED ---
	print("ArenaScene: Ready.")

	# You could potentially still place spawn points here if desired when the scene RUNS,
	# but placing them manually or via the generator's tool method might be better
	# if you need them set BEFORE capturing.
	# generator.place_spawn_points(spawn1, spawn2) # Optional: Place spawns at runtime


# Optional: Add a button in the editor for placing spawns if needed
var _place_spawns_trigger := false
@export var place_spawns_now: bool :
	get: return _place_spawns_trigger
	set(value):
		if value == true and Engine.is_editor_hint():
			print("Placing spawn points via editor button...")
			# Ensure generator reference is valid before calling its method
			if is_instance_valid(generator) and is_instance_valid(spawn1) and is_instance_valid(spawn2):
				generator.place_spawn_points(spawn1, spawn2)
			else:
				# Add more specific error messages
				if not is_instance_valid(generator): printerr("ArenaScene: Generator node reference is invalid!")
				if not is_instance_valid(spawn1): printerr("ArenaScene: PlayerSpawn1 node reference is invalid!")
				if not is_instance_valid(spawn2): printerr("ArenaScene: PlayerSpawn2 node reference is invalid!")
				printerr("Missing generator or spawn markers!")

		# --- FIX HERE ---
		self._place_spawns_trigger = false # Use self.
		# --- END FIX ---

		notify_property_list_changed()
