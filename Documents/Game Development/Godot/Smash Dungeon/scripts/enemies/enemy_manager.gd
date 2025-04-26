# Enemy Manager
extends Node

# Dictionary of enemy types with their corresponding scene paths
var enemy_types = {
	# Traditional enemies
	"basic": "res://scenes/enemies/basic_enemy.tscn",
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
	"basic_sm": "res://state_machines/base_enemy_sm.tscn",
	"fodder_sm": "res://state_machines/fodder_enemy_sm.tscn"
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
	# Check if enemy type exists in the dictionary
	if not enemy_type in enemy_types:
		push_error("EnemyManager: Enemy type not found: " + enemy_type)
		print("EnemyManager: ERROR - Unknown enemy type: " + enemy_type)
		return null
	
	# Check if the enemy was successfully preloaded    
	if not enemy_type in preloaded_enemies or preloaded_enemies[enemy_type] == null:
		push_error("EnemyManager: Enemy scene not preloaded for type: " + enemy_type)
		print("EnemyManager: ERROR - Trying to load enemy scene at runtime...")
		
		# Try to load it now as a fallback
		var path = enemy_types[enemy_type]
		if ResourceLoader.exists(path):
			var scene = load(path)
			if scene:
				preloaded_enemies[enemy_type] = scene
				print("EnemyManager: Successfully loaded enemy type at runtime: " + enemy_type)
			else:
				print("EnemyManager: CRITICAL ERROR - Failed to load scene: " + path)
				return null
		else:
			print("EnemyManager: CRITICAL ERROR - Scene file does not exist: " + path)
			return null
		
	# Now try to instantiate
	var enemy_instance = preloaded_enemies[enemy_type].instantiate()
	enemy_instance.global_position = position
	
	if parent_node != null:
		parent_node.add_child(enemy_instance)
	
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
