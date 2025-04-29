# enemy_config.gd
extends Resource
class_name EnemyConfig

# --- Load State Config classes ---
const IdleStateConfig = preload("res://state_machines/states/state_configs/idle_state_config.gd")
const ChaseStateConfig = preload("res://state_machines/states/state_configs/chase_state_config.gd")
const TelegraphStateConfig = preload("res://state_machines/states/state_configs/telegraph_state_config.gd")
const AttackStateConfig = preload("res://state_machines/states/state_configs/attack_state_config.gd")
const RepositioningStateConfig = preload("res://state_machines/states/state_configs/repositioning_state_config.gd")
const StunnedStateConfig = preload("res://state_machines/states/state_configs/stunned_state_config.gd")
const DeathStateConfig = preload("res://state_machines/states/state_configs/death_state_config.gd")

# --- Basic Information ---
@export var enemy_id: String = "basic"
@export var display_name: String = "Basic Enemy"
@export var sprite_frames: SpriteFrames

# --- Core Stats (Global) ---
@export_group("Core Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0 # Base speed, states might use multipliers
@export var acceleration: float = 500.0 # Increased default based on jumper debugging
@export var damping: float = 0.9

# --- Weapon System (Global) ---
@export_group("Weapon System")
@export var weapon_id: String = ""
@export var attack_types: Dictionary = {} # Keep for legacy/simple enemies OR non-weapon system attacks

# --- State Machine Support (Global) ---
@export_group("State Machine")
@export var use_state_machine: bool = false

# --- Physics & Debug (Global) ---
@export_group("Physics & Debug")
@export var motion_mode: int = 0 # Use CharacterBody2D.MOTION_MODE_GROUNDED / MOTION_MODE_FLOATING
@export var use_gravity: bool = true # <-- MOVED/ADDED HERE
@export var debug_mode: bool = false
@export var jump_force: float = 300.0

# --- Combat Behavior (Global) ---
@export_group("Combat Behavior")
@export var combat_movement_speed_multiplier: float = 0.7 # <-- ADDED HERE (Multiplier for speed during certain combat states?)
@export var min_attack_state_duration: float = 0.2 # <-- ADDED HERE (Min time to stay in AttackState, maybe superseded by commitment?)

# --- Avoidance (Global) ---
@export_group("Avoidance")
@export var use_avoidance: bool = true # <-- MOVED/ADDED HERE
@export var avoidance_strength: float = 150.0 # <-- MOVED/ADDED HERE
@export var avoidance_ray_length: float = 75.0 # <-- MOVED/ADDED HERE
@export var vertical_avoidance_factor: float = 0.6 # <-- MOVED/ADDED HERE

# --- Collections (Global) ---
@export_group("Collections")
@export var attack_patterns: Array[Resource] = []
@export var drop_items: Array[Resource] = []
@export var behaviors: Array[Resource] = []

# --- State Machine Configuration (NEW STRUCTURE) ---
@export_group("State Configurations")
@export var idle_config: IdleStateConfig = null
@export var chase_config: ChaseStateConfig = null
@export var telegraph_config: TelegraphStateConfig = null
@export var attack_config: AttackStateConfig = null
@export var repositioning_config: RepositioningStateConfig = null
@export var stunned_config: StunnedStateConfig = null
@export var death_config: DeathStateConfig = null
# Add exports for any other custom state configs here


# --- Legacy/Base Behavior (Marked for Removal / Superseded) ---
# These should eventually be deleted once all enemies are converted and
# dependent code in BaseEnemy/BaseEnemySM is updated to read from config.
@export_group("Legacy/Base Behavior (Review for Removal)")
@export var attack_commitment: float = 0.5 # Superseded by AttackStateConfig
@export var post_attack_pause: float = 0.0 # Likely unused now / state logic
@export var attack_retreat_distance: float = 0.0 # Superseded by AttackStateConfig
@export var attack_frequency: float = 1.0 # Handled by weapon cooldowns
@export var attack_telegraph_enabled: bool = false # Superseded by TelegraphState presence/config
@export var attack_telegraph_time: float = 0.3 # Superseded by TelegraphStateConfig
@export var retreat_chance: float = 0.4 # Likely state transition logic now
@export var jump_chance: float = 0.2 # Superseded by ChaseStateConfig
@export var detection_range: float = 300.0 # Superseded by ChaseStateConfig? (sight_range)
@export var sight_range: float = 600.0 # Superseded by ChaseStateConfig
@export var preferred_attack_distance: float = 150.0 # Superseded by ChaseStateConfig
@export var preferred_distance_tolerance: float = 50.0 # Superseded by ChaseStateConfig
@export var chase_speed_multiplier: float = 1.5 # Superseded by ChaseStateConfig
@export var direct_chase: bool = false # Superseded by ChaseStateConfig
@export var chase_jump_chance: float = 0.0 # Superseded by ChaseStateConfig
@export var chase_jump_force: float = 300.0 # Superseded by ChaseStateConfig
@export var aggression_level: float = 0.5 # Superseded by ChaseStateConfig
# Note: use_avoidance and related vars were MOVED to the dedicated "Avoidance" group above.
# Note: combat_movement_speed_multiplier MOVED to dedicated "Combat Behavior" group above.
@export var reposition_chance: float = 0.3 # State transition logic
@export var reposition_min_time: float = 0.8 # Superseded by RepositioningStateConfig
@export var reposition_max_time: float = 2.0 # Superseded by RepositioningStateConfig
@export var wander_speed_multiplier: float = 0.4 # Superseded by IdleStateConfig
@export var wander_interval_min: float = 1.5 # Superseded by IdleStateConfig
@export var wander_interval_max: float = 4.0 # Superseded by IdleStateConfig


# Apply configuration to an enemy instance
# NOTE: This function mainly applies properties still potentially used by BaseEnemy logic
# OR legacy enemies. State Machine enemies primarily read directly from this config resource.
# This function likely needs cleanup/removal in Phase 3.
func apply_to_enemy(enemy_instance) -> void:
	if not is_instance_valid(enemy_instance): return

	# Apply Core Stats
	if "max_health" in enemy_instance: enemy_instance.max_health = max_health
	if "move_speed" in enemy_instance: enemy_instance.move_speed = move_speed
	if "acceleration" in enemy_instance: enemy_instance.acceleration = acceleration
	if "damping" in enemy_instance: enemy_instance.damping = damping

	# Weapon ID
	if "weapon_id" in enemy_instance: enemy_instance.weapon_id = weapon_id

	# Physics & Debug
	if "motion_mode" in enemy_instance: enemy_instance.motion_mode = motion_mode
	if "use_gravity" in enemy_instance: enemy_instance.use_gravity = use_gravity
	if "debug_mode" in enemy_instance: enemy_instance.debug_mode = debug_mode

	# Apply NEW Global Configs (Combat, Avoidance) - if BaseEnemy needs them directly
	if "combat_movement_speed_multiplier" in enemy_instance: enemy_instance.combat_movement_speed_multiplier = combat_movement_speed_multiplier
	if "min_attack_state_duration" in enemy_instance: enemy_instance.min_attack_state_duration = min_attack_state_duration
	if "use_avoidance" in enemy_instance: enemy_instance.use_avoidance = use_avoidance
	if "avoidance_strength" in enemy_instance: enemy_instance.avoidance_strength = avoidance_strength
	if "avoidance_ray_length" in enemy_instance: enemy_instance.avoidance_ray_length = avoidance_ray_length
	if "vertical_avoidance_factor" in enemy_instance: enemy_instance.vertical_avoidance_factor = vertical_avoidance_factor

	# Apply Legacy/Superseded properties - Keep ONLY if non-SM enemies still rely on apply_to_enemy()
	# Otherwise, these lines should be removed in Phase 3.
	if "attack_commitment" in enemy_instance: enemy_instance.attack_commitment = attack_commitment
	if "post_attack_pause" in enemy_instance: enemy_instance.post_attack_pause = post_attack_pause
	if "attack_retreat_distance" in enemy_instance: enemy_instance.attack_retreat_distance = attack_retreat_distance
	if "attack_frequency" in enemy_instance: enemy_instance.attack_frequency = attack_frequency
	if "attack_telegraph_enabled" in enemy_instance: enemy_instance.attack_telegraph_enabled = attack_telegraph_enabled
	if "attack_telegraph_time" in enemy_instance: enemy_instance.attack_telegraph_time = attack_telegraph_time
	if "sight_range" in enemy_instance: enemy_instance.sight_range = sight_range
	if "preferred_attack_distance" in enemy_instance: enemy_instance.preferred_attack_distance = preferred_attack_distance
	if "preferred_distance_tolerance" in enemy_instance: enemy_instance.preferred_distance_tolerance = preferred_distance_tolerance
	if "chase_speed_multiplier" in enemy_instance: enemy_instance.chase_speed_multiplier = chase_speed_multiplier
	if "direct_chase" in enemy_instance: enemy_instance.direct_chase = direct_chase
	if "chase_jump_chance" in enemy_instance: enemy_instance.chase_jump_chance = chase_jump_chance
	if "chase_jump_force" in enemy_instance: enemy_instance.chase_jump_force = chase_jump_force
	if "aggression_level" in enemy_instance: enemy_instance.aggression_level = aggression_level
	if "reposition_chance" in enemy_instance: enemy_instance.reposition_chance = reposition_chance
	if "reposition_min_time" in enemy_instance: enemy_instance.reposition_min_time = reposition_min_time
	if "reposition_max_time" in enemy_instance: enemy_instance.reposition_max_time = reposition_max_time
	if "wander_speed_multiplier" in enemy_instance: enemy_instance.wander_speed_multiplier = wander_speed_multiplier
	if "wander_interval_min" in enemy_instance: enemy_instance.wander_interval_min = wander_interval_min
	if "wander_interval_max" in enemy_instance: enemy_instance.wander_interval_max = wander_interval_max
	if "attack_types" in enemy_instance: enemy_instance.attack_types = attack_types.duplicate(true) # Still need deep copy

	# Initialize health AFTER max_health is set
	if "current_health" in enemy_instance: enemy_instance.current_health = max_health

	# Initialize Cooldowns AFTER setting types/frequency
	if enemy_instance.has_method("_initialize_attack_cooldowns"):
		enemy_instance._initialize_attack_cooldowns()
