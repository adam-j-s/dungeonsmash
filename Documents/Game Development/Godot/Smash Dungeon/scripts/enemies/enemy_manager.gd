# Enemy Manager
extends Node

# Dictionary of enemy types with their corresponding scene paths
var enemy_types = {
	"basic": "res://scenes/enemies/basic_enemy.tscn",
	"base": "res://resources/enemies/state machines/base_enemy.tscn",
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
	# Add more enemy types as needed
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
