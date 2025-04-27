# enemy_config.gd
extends Resource
class_name EnemyConfig

# --- Load State Config classes (optional but helps with type hints) ---
# Note: Adjust paths if you saved them elsewhere
const IdleStateConfig = preload("res://state_machines/states/state_configs/idle_state_config.gd")
const ChaseStateConfig = preload("res://state_machines/states/state_configs/chase_state_config.gd")
const TelegraphStateConfig = preload("res://state_machines/states/state_configs/telegraph_state_config.gd")
const AttackStateConfig = preload("res://state_machines/states/state_configs/attack_state_config.gd")
const RepositioningStateConfig = preload("res://state_machines/states/state_configs/repositioning_state_config.gd")
const StunnedStateConfig = preload("res://state_machines/states/state_configs/stunned_state_config.gd")
const DeathStateConfig = preload("res://state_machines/states/state_configs/death_state_config.gd")
# Add preloads for any other custom state configs here

# --- Basic Information ---
@export var enemy_id: String = "basic"
@export var display_name: String = "Basic Enemy"
@export var sprite_frames: SpriteFrames

# --- Core Stats (Global) ---
@export_group("Core Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0 # Base speed, states might use multipliers
@export var acceleration: float = 10.0
@export var damping: float = 0.9

# --- Weapon System (Global) ---
@export_group("Weapon System")
@export var weapon_id: String = ""

# --- State Machine Support (Global) ---
@export_group("State Machine")
@export var use_state_machine: bool = false

# --- Physics & Debug (Global) ---
@export_group("Physics & Debug")
@export var motion_mode: int = 0 # 0 = Grounded, 1 = Floating
@export var use_gravity: bool = true
@export var debug_mode: bool = false

# --- Optional Base Parameters (Consider removing if fully superseded by states) ---
# These are the parameters we discussed migrating into state configs.
# Keep them for now if legacy enemies still need them, but plan to remove eventually.
@export_group("Legacy/Base Behavior (Review for Removal)")
@export var attack_commitment: float = 0.5 # Superseded by AttackStateConfig
@export var post_attack_pause: float = 0.0 # Likely unused now
@export var attack_retreat_distance: float = 0.0 # Superseded by AttackStateConfig
@export var attack_frequency: float = 1.0 # Related to cooldowns, maybe keep?
@export var attack_telegraph_enabled: bool = false # Superseded by TelegraphStateConfig presence
@export var attack_telegraph_time: float = 0.3 # Superseded by TelegraphStateConfig
@export var retreat_chance: float = 0.4 # Likely state transition logic now
@export var jump_chance: float = 0.2 # Superseded by ChaseStateConfig
@export var detection_range: float = 300.0 # Global detection? Or Chase specific? Review needed.
@export var sight_range: float = 600.0 # Superseded by ChaseStateConfig
@export var preferred_attack_distance: float = 150.0 # Superseded by ChaseStateConfig
@export var preferred_distance_tolerance: float = 50.0 # Superseded by ChaseStateConfig
@export var chase_speed_multiplier: float = 1.5 # Superseded by ChaseStateConfig
@export var direct_chase: bool = false # Superseded by ChaseStateConfig
@export var chase_jump_chance: float = 0.0 # Superseded by ChaseStateConfig
@export var chase_jump_force: float = 300.0 # Superseded by ChaseStateConfig
@export var aggression_level: float = 0.5 # Superseded by ChaseStateConfig
@export var use_avoidance: bool = true # Keep global? Or make state specific? (e.g., disable in Stunned)
@export var avoidance_strength: float = 150.0
@export var avoidance_ray_length: float = 75.0
@export var vertical_avoidance_factor: float = 0.6
@export var combat_movement_speed_multiplier: float = 0.5 # Maybe AttackState specific? Review.
@export var reposition_chance: float = 0.3 # State transition logic
@export var reposition_min_time: float = 0.8 # Superseded by RepositioningStateConfig
@export var reposition_max_time: float = 2.0 # Superseded by RepositioningStateConfig
@export var wander_speed_multiplier: float = 0.4 # Superseded by IdleStateConfig
@export var wander_interval_min: float = 1.5 # Superseded by IdleStateConfig
@export var wander_interval_max: float = 4.0 # Superseded by IdleStateConfig
@export var attack_types: Dictionary = {} # Keep for legacy or simple enemies?

# --- Collections (Global) ---
@export_group("Collections")
@export var attack_patterns: Array[Resource] = []
@export var drop_items: Array[Resource] = []
@export var behaviors: Array[Resource] = []

# --- State Machine Configuration (NEW STRUCTURE) ---
@export_group("State Configurations")
@export var idle_config: IdleStateConfig = null # Assign IdleStateConfig resource here
@export var chase_config: ChaseStateConfig = null # Assign ChaseStateConfig resource here
@export var telegraph_config: TelegraphStateConfig = null # Assign TelegraphStateConfig resource here
@export var attack_config: AttackStateConfig = null # Assign AttackStateConfig resource here
@export var repositioning_config: RepositioningStateConfig = null # Assign RepositioningStateConfig resource here
@export var stunned_config: StunnedStateConfig = null # Assign StunnedStateConfig resource here
@export var death_config: DeathStateConfig = null # Assign DeathStateConfig resource here
# Add exports for any other custom state configs here

# --- REMOVED ---
# @export var states_config: Dictionary = { ... } # This line is now gone

# Apply configuration to an enemy instance
# Note: This function becomes much simpler, mainly applying global parameters.
# State configuration is now primarily handled by the states themselves reading their specific config resource.
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

	# Apply Legacy/Base properties (These should eventually be removed or confirmed global)
	# Consider removing these assignments once states fully rely on their own configs
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
	if "use_avoidance" in enemy_instance: enemy_instance.use_avoidance = use_avoidance
	if "avoidance_strength" in enemy_instance: enemy_instance.avoidance_strength = avoidance_strength
	if "avoidance_ray_length" in enemy_instance: enemy_instance.avoidance_ray_length = avoidance_ray_length
	if "vertical_avoidance_factor" in enemy_instance: enemy_instance.vertical_avoidance_factor = vertical_avoidance_factor
	if "combat_movement_speed_multiplier" in enemy_instance: enemy_instance.combat_movement_speed_multiplier = combat_movement_speed_multiplier
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
