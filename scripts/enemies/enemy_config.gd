# enemy_config.gd
extends Resource
class_name EnemyConfig

# Basic Information
@export var enemy_id: String = "basic"
@export var display_name: String = "Basic Enemy"
@export var sprite_frames: SpriteFrames

# Stats
@export_group("Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var acceleration: float = 10.0
@export var damping: float = 0.9

# Attack Behavior
@export_group("Attack Behavior")
@export var attack_commitment: float = 0.5  # How committed enemy is during attack (0.0-1.0)
@export var post_attack_pause: float = 0.0  # Seconds to pause after attacking
@export var attack_retreat_distance: float = 0.0  # Distance to retreat after attacking
@export var attack_frequency: float = 1.0  # Multiplier for attack cooldowns (lower = more frequent)
@export var attack_telegraph_enabled: bool = false  # Whether attacks have telegraph
@export var attack_telegraph_time: float = 0.3  # How long to telegraph attacks
@export var retreat_chance: float = 0.4 # Note: Might be redundant with BaseEnemy parameters
@export var jump_chance: float = 0.2   # Note: Might be redundant with BaseEnemy parameters

# Detection & Combat
@export_group("Detection & Combat")
@export var detection_range: float = 300.0 # Note: BaseEnemy doesn't use this specific var yet
@export var sight_range: float = 600.0
@export var preferred_attack_distance: float = 150.0
@export var preferred_distance_tolerance: float = 50.0
@export var chase_speed_multiplier: float = 1.5
@export var direct_chase: bool = false
@export var chase_jump_chance: float = 0.0
@export var chase_jump_force: float = 300.0
@export var aggression_level: float = 0.5

# Weapons
@export var weapon_id: String = "sword"

# Enhanced Movement Parameters
@export_group("Enhanced Movement")
@export var use_avoidance: bool = true
@export var avoidance_strength: float = 150.0
@export var avoidance_ray_length: float = 75.0
@export var vertical_avoidance_factor: float = 0.6
@export var combat_movement_speed_multiplier: float = 0.5
@export var reposition_chance: float = 0.3
@export var reposition_min_time: float = 0.8
@export var reposition_max_time: float = 2.0

# Wandering Behavior
@export_group("Wandering")
@export var wander_speed_multiplier: float = 0.4
@export var wander_interval_min: float = 1.5
@export var wander_interval_max: float = 4.0

# Attack Definitions
@export_group("Attack Definitions")
@export var attack_types: Dictionary = {
	"melee": {
		"damage": 10,
		"cooldown": 1.0,
		"range": 50.0
	},
	"ranged": {
		"damage": 5,
		"cooldown": 2.0,
		"range": 200.0,
		"projectile": ""  # Path to projectile scene if needed
	}
}

# Advanced Options
@export_group("Advanced Options")
@export var motion_mode: int = 0  # 0 = Normal, 1 = Floating
@export var debug_mode: bool = false
@export var use_gravity: bool = true

# Complex Collections
@export_group("Collections")
@export var attack_patterns: Array[Resource] = []
@export var drop_items: Array[Resource] = []
@export var behaviors: Array[Resource] = []

# Apply configuration to an enemy instance
func apply_to_enemy(enemy_instance: BaseEnemy) -> void:
	# Apply Stats and other properties FIRST
	enemy_instance.max_health = max_health
	enemy_instance.move_speed = move_speed
	enemy_instance.acceleration = acceleration
	enemy_instance.damping = damping

	# Enhanced movement parameters
	enemy_instance.use_avoidance = use_avoidance
	enemy_instance.avoidance_strength = avoidance_strength
	enemy_instance.avoidance_ray_length = avoidance_ray_length
	enemy_instance.vertical_avoidance_factor = vertical_avoidance_factor
	enemy_instance.combat_movement_speed_multiplier = combat_movement_speed_multiplier
	enemy_instance.reposition_chance = reposition_chance
	enemy_instance.reposition_min_time = reposition_min_time
	enemy_instance.reposition_max_time = reposition_max_time

	# Wandering parameters
	enemy_instance.wander_speed_multiplier = wander_speed_multiplier
	enemy_instance.wander_interval_min = wander_interval_min
	enemy_instance.wander_interval_max = wander_interval_max

	# Combat parameters
	enemy_instance.sight_range = sight_range
	enemy_instance.preferred_attack_distance = preferred_attack_distance
	enemy_instance.preferred_distance_tolerance = preferred_distance_tolerance
	enemy_instance.chase_speed_multiplier = chase_speed_multiplier # Added missing assignment
	enemy_instance.direct_chase = direct_chase # Added missing assignment
	enemy_instance.chase_jump_chance = chase_jump_chance # Added missing assignment
	enemy_instance.chase_jump_force = chase_jump_force # Added missing assignment
	enemy_instance.aggression_level = aggression_level # Added missing assignment

	# Attack Behavior
	enemy_instance.attack_commitment = attack_commitment # Added missing assignment
	enemy_instance.post_attack_pause = post_attack_pause # Added missing assignment
	enemy_instance.attack_retreat_distance = attack_retreat_distance # Added missing assignment
	enemy_instance.attack_frequency = attack_frequency # Added missing assignment
	enemy_instance.attack_telegraph_enabled = attack_telegraph_enabled # Added missing assignment
	enemy_instance.attack_telegraph_time = attack_telegraph_time # Added missing assignment

	# Weapon ID
	enemy_instance.weapon_id = weapon_id # Added missing assignment

	# Set attack types
	enemy_instance.attack_types = attack_types.duplicate(true)

	# --- ADDED: Initialize Cooldowns AFTER setting types ---
	if enemy_instance.has_method("_initialize_attack_cooldowns"):
		enemy_instance._initialize_attack_cooldowns()
	# --- END ADDED ---

	# Motion mode
	if motion_mode == 1:  # Floating
		enemy_instance.motion_mode = enemy_instance.MOTION_MODE_FLOATING
		enemy_instance.use_gravity = false # Also ensure gravity is off for floating
	else:
		# Assuming 0 is grounded, explicitly set mode and use config gravity
		enemy_instance.motion_mode = enemy_instance.MOTION_MODE_GROUNDED # Or MOTION_MODE_DEFAULT if applicable
		enemy_instance.use_gravity = use_gravity # Use the config setting

	# Debug mode
	enemy_instance.debug_mode = debug_mode

	# Initialize health (Should happen AFTER max_health is set)
	enemy_instance.current_health = max_health
	# Optional: Emit signal to update health bars immediately
	# if enemy_instance.has_signal("health_changed"):
	#	 enemy_instance.emit_signal("health_changed", enemy_instance.current_health, enemy_instance.max_health)

	# Optional: Equip weapon AFTER setting weapon_id
	# Note: Child enemy scripts might call equip_weapon in their _ready, potentially
	# overriding this if config is applied before _ready finishes. Consider timing.
	# if enemy_instance.has_method("equip_weapon"):
	#	 enemy_instance.equip_weapon(enemy_instance.weapon_id)

	# Apply legacy parameters if they exist on the instance (for compatibility if needed)
	if "retreat_chance" in enemy_instance:
		enemy_instance.retreat_chance = retreat_chance
	if "jump_chance" in enemy_instance:
		enemy_instance.jump_chance = jump_chance
