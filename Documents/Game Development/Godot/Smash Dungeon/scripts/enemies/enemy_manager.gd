# Enemy Manager
extends Node

# Dictionary of enemy types with their corresponding scene paths
var enemy_types = {
	# Traditional enemies
	"basic_enemy": "res://scenes/enemies/basic_enemy.tscn",
	"fodder": "res://scenes/enemies/basic_fodder_enemy.tscn",
	"zapper": "res://scenes/enemies/zap_fodder_enemy.tscn",
	"bouncer": "res://scenes/enemies/bouncer_enemy.tscn",
	"jumper": "res://scenes/enemies/jumper_enemy.tscn",
	"turret": "res://scenes/enemies/turret_enemy.tscn",
	"wisp_enemy": "res://scenes/enemies/wisp_enemy.tscn",
	"splitter": "res://scenes/enemies/splitter_enemy.tscn",
	"floater": "res://scenes/enemies/floater_enemy.tscn",
	"slime": "res://scenes/enemies/slime_enemy.tscn",
	"ranged": "res://scenes/enemies/ranged_enemy.tscn",
	"boss": "res://scenes/enemies/boss_enemy.tscn",
	"tile_aware_slime": "res://scenes/enemies/tile_aware_slime.tscn",
	"slithering_limb": "res://scenes/enemies/slithering_limb.tscn",
	"procedural_spider": "res://scenes/enemies/procedural_spider.tscn",
	"procedural_spider_3d": "res://scenes/enemies/procedural_spider_3d.tscn",
	"carrion": "res://scenes/enemies/carrion_body.tscn",
	
	# State machine enemies
	"basic_enemy_sm": "res://state_machines/base_enemy_sm.tscn",
	"fodder_sm": "res://state_machines/fodder_enemy_sm.tscn",
	"jumper_sm": "res://state_machines/jumper_enemy_sm.tscn",
	"bouncer_sm": "res://state_machines/bouncer_enemy_sm.tscn"
	# Add more state machine enemies as you create them
}

# Preloaded enemy scenes for quick access
var preloaded_enemies = {}

func _ready():
	# Preload all enemy scenes
	for enemy_id in enemy_types:
		var path = enemy_types[enemy_id]
		if ResourceLoader.exists(path):
			preloaded_enemies[enemy_id] = load(path)
			print("EnemyManager: Successfully preloaded enemy type: " + enemy_id)
		else:
			push_error("EnemyManager: Enemy scene does not exist at path: " + path)
			print("EnemyManager: ERROR - Enemy scene not found at: " + path)

# Function to spawn an enemy of specific type at a position
func spawn_enemy(enemy_type: String, position: Vector2, parent_node = null) -> Node2D:
	# 1. Check if enemy type is known
	if not enemy_type in enemy_types:
		push_error("EnemyManager: Enemy type not found in enemy_types dictionary: " + enemy_type)
		return null

	# 2. Ensure scene is preloaded (with fallback loading)
	if not enemy_type in preloaded_enemies or preloaded_enemies[enemy_type] == null:
		push_warning("EnemyManager: Enemy scene not preloaded for type: '%s'. Attempting load..." % enemy_type)
		var scene_path = enemy_types[enemy_type]
		if ResourceLoader.exists(scene_path):
			var loaded_scene = load(scene_path)
			if loaded_scene:
				preloaded_enemies[enemy_type] = loaded_scene
				print("EnemyManager: Successfully loaded scene at runtime: " + scene_path)
			else:
				printerr("EnemyManager: Failed to load scene resource: " + scene_path)
				return null
		else:
			printerr("EnemyManager: Scene file does not exist: " + scene_path)
			return null

	# 3. Instantiate the enemy scene
	var enemy_instance = preloaded_enemies[enemy_type].instantiate()
	if not is_instance_valid(enemy_instance):
		printerr("EnemyManager: Failed to instantiate scene for type: " + enemy_type)
		return null

	# 4. Set initial position
	enemy_instance.global_position = position

	# 5. Determine and Load Configuration
	var config_path: String = ""
	var parent_config_dir: String = ""
	var is_sm: bool = enemy_type.ends_with("_sm") # Check if it's a state machine type

	if is_sm:
		# --- State Machine Enemy Config Path ---
		parent_config_dir = "res://state_machines/configs"
		# Path goes into the enemy-specific folder and looks for 'config.tres'
		config_path = parent_config_dir.path_join(enemy_type).path_join("config.tres")
	else:
		# --- Legacy Enemy Config Path ---
		parent_config_dir = "res://resources/enemies/configs" # Adjust if your legacy path is different
		# Assumes legacy configs follow the old naming convention
		config_path = parent_config_dir.path_join("%s_config.tres" % enemy_type)

	print("EnemyManager: Attempting to load config for '%s' from: '%s'" % [enemy_type, config_path])

	if ResourceLoader.exists(config_path):
		var loaded_config: Resource = load(config_path) # Use load() not preload() here

		if loaded_config is EnemyConfig:
			# Check if the enemy instance has a 'config' property to assign to
			if "config" in enemy_instance:
				enemy_instance.config = loaded_config
				print("EnemyManager: Successfully loaded and assigned config '%s' to '%s'" % [config_path, enemy_type])

				## --- Optional: Apply config values immediately ---
				## Useful if enemy _ready() depends on config values being present as direct properties
				## However, ideally states read directly from enemy.config.xxx_config
			#if loaded_config.has_method("apply_to_enemy"):
				#loaded_config.apply_to_enemy(enemy_instance)
				#print("EnemyManager: Called apply_to_enemy for '%s'" % enemy_type)
				## ----------------------------------------------

			else:
				push_error("EnemyManager: Enemy instance '%s' (Script: %s) does not have a 'config' variable." % [enemy_type, enemy_instance.get_script().resource_path if enemy_instance.get_script() else "N/A"])
		elif loaded_config == null:
			# load() returns null if it fails for reasons other than non-existence
			printerr("EnemyManager: Failed to load resource '%s' (returned null)." % config_path)
		else:
			# Loaded something, but it wasn't the right type
			push_error("EnemyManager: Loaded resource '%s' is not an EnemyConfig (Type: %s)." % [config_path, typeof(loaded_config)])
	else:
		# File doesn't exist at the constructed path
		print("EnemyManager: Config file not found for '%s' at '%s'. Enemy will use default script values." % [enemy_type, config_path])

	# 6. Add to Scene Tree
	if is_instance_valid(parent_node):
		parent_node.add_child(enemy_instance)
	else:
		# Fallback if no parent provided - add to current scene? Might not be desired.
		push_warning("EnemyManager: Spawned enemy '%s' without a specified parent node. Adding to SceneTree root." % enemy_type)
		# get_tree().get_root().add_child(enemy_instance) # Example fallback, use with caution

	# 7. Return the instance
	return enemy_instance
	
# Function to get a reference to an enemy scene without instantiating
func get_enemy_scene(enemy_type: String) -> PackedScene:
	if not enemy_type in preloaded_enemies or preloaded_enemies[enemy_type] == null:
		push_error("EnemyManager: Cannot get enemy scene for type: " + enemy_type)
		return null
		
	return preloaded_enemies[enemy_type]

# Helper to determine if an enemy type uses the state machine
func is_state_machine_enemy(enemy_type: String) -> bool:
	# Quick check by name convention
	if enemy_type.ends_with("_sm"):
		return true
		
	# If not clear from name, check the scene
	if preloaded_enemies.has(enemy_type) and preloaded_enemies[enemy_type] != null:
		# Instantiate to check, but don't add to tree
		var instance = preloaded_enemies[enemy_type].instantiate()
		var is_sm = instance is BaseEnemySM
		instance.queue_free()  # Clean up
		return is_sm
		
	return false

# Apply config to enemy instance (useful for runtime config changes)
func apply_config_to_enemy(enemy_instance, config: EnemyConfig) -> void:
	if enemy_instance == null or config == null:
		push_error("EnemyManager: Cannot apply config - null instance or config")
		return
		
	# If the enemy is a state machine type but config isn't set for state machine
	if enemy_instance is BaseEnemySM and not config.use_state_machine:
		print("Warning: Applying non-state machine config to state machine enemy")
		
	# Or if config is for state machine but enemy isn't
	elif config.use_state_machine and not enemy_instance is BaseEnemySM:
		print("Warning: Applying state machine config to non-state machine enemy")
	
	# Apply configuration
	config.apply_to_enemy(enemy_instance)
