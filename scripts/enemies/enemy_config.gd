# enemy_config.gd
extends Resource
class_name EnemyConfig

@export var enemy_id: String = "basic"
@export var display_name: String = "Basic Enemy"
@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 50.0
@export var detection_range: float = 300.0
@export var sprite_frames: SpriteFrames

# You could add more complex properties here
@export var attack_patterns: Array[Resource] = []
@export var drop_items: Array[Resource] = []
