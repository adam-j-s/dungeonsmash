@tool
extends EditorScript

# --- Fodder Enemy SM Configuration ---
var enemy_id = "fodder_enemy_sm"
var display_name = "Fodder Enemy SM"
var max_health = 40
var move_speed = 150.0
var acceleration = 12.0
var damping = 0.8

# Detection & Combat Parameters
var detection_range = 500.0
var sight_range = 500.0
var preferred_attack_distance = 40.0
var preferred_distance_tolerance = 30.0 # Increased tolerance for aggressive movement

# Aggression Parameters
var aggression_level = 0.9 # More aggressive
var chase_speed_multiplier = 1.8 # Faster chase
var direct_chase = true # More direct approach
var chase_jump_chance = 0.2 # Small chance to jump during chase
var chase_jump_force = 250.0 # Moderate jump force

# Avoidance Parameters
var use_avoidance = true
var avoidance_strength = 100.0
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5

# Movement Parameters
var combat_movement_speed_multiplier = 0.9 # Slightly slower when in close combat/attacking
var reposition_chance = 0.1 # Low chance to reposition
var reposition_min_time = 0.3 # Quick reposition
var reposition_max_time = 0.6
var wander_speed_multiplier = 0.6 # Faster wandering
var wander_interval_min = 1.5 # Shorter wander intervals
var wander_interval_max = 3.0

# Attack Behavior Parameters
var attack_commitment = 0.8 # High commitment to attack once started
var post_attack_pause = 0.1 # Very short pause after attack
var attack_retreat_distance = 0.0 # No specific retreat after attack
var attack_frequency = 1.25 # Corresponds roughly to 0.8s cooldown
var attack_telegraph_enabled = true # Use telegraph
var attack_telegraph_time = 0.2 # Quick telegraph

# Weapon System Parameters
var weapon_id = "sword"

# Legacy Parameters (keep these for compatibility if needed)
var retreat_chance = 0.1 # Match with reposition_chance
var jump_chance = 0.2 # Match with chase_jump_chance
var attack_lunge_strength = 0.0 # No lunge

# Physics Parameters
var motion_mode = 0 # Grounded
var debug_mode = false
var use_gravity = true

# Attack Definitions
var attack_types = {
	"melee": {
		"cooldown": 0.8, # Correct cooldown
		"range": 45.0, # Slightly increased range
		"damage": 8
	}
}

# State Machine Support
var use_state_machine = true # This IS a state machine enemy

# State-specific configurations
var states_config = {
	"IdleState": {
		"wander_speed_multiplier": 0.6,
		"wander_interval_min": 1.5,
		"wander_interval_max": 3.0
	},
	"ChaseState": {
		# Inherits general sight/preferred distance from base config
		"chase_speed_multiplier": 1.8,
		"direct_chase": true,
		"aggression_level": 0.9,
		"jump_chance": 0.2 # Specific jump chance for chase
	},
	"AttackState": {
		"attack_commitment": 0.8,
		"post_attack_pause": 0.1,
		# Add other specific attack state parameters if needed, e.g.:
		# "min_attack_state_duration": 0.5,
		"combat_movement_speed_multiplier": 0.9 # Match base combat speed
	},
	"RepositioningState": {
		"reposition_chance": 0.1,
		"reposition_min_time": 0.3,
		"reposition_max_time": 0.6
	},
	"StunnedState": {
		"stun_duration": 0.5 # Quick stun recovery
	},
	"DeathState": {}
}
# --- End Configuration ---


func _run():
	# Ensure the EnemyConfig class is available
	if not Engine.has_singleton("EnemyConfig") and not ClassDB.can_instantiate("EnemyConfig"):
		printerr("EnemyConfig class not found. Ensure 'res://scripts/enemies/enemy_config.gd' is loaded and has 'class_name EnemyConfig'.")
		return
		
	# Create new enemy config resource
	var config = EnemyConfig.new()

	# Set all base properties
	config.enemy_id = enemy_id
	config.display_name = display_name
	config.max_health = max_health
	config.move_speed = move_speed
	config.acceleration = acceleration
	config.damping = damping

	# Detection & Combat
	config.detection_range = detection_range
	config.sight_range = sight_range
	config.preferred_attack_distance = preferred_attack_distance
	config.preferred_distance_tolerance = preferred_distance_tolerance

	# Aggression Parameters
	config.aggression_level = aggression_level
	config.chase_speed_multiplier = chase_speed_multiplier
	config.direct_chase = direct_chase
	config.chase_jump_chance = chase_jump_chance
	config.chase_jump_force = chase_jump_force

	# Avoidance Parameters
	config.use_avoidance = use_avoidance
	config.avoidance_strength = avoidance_strength
	config.avoidance_ray_length = avoidance_ray_length
	config.vertical_avoidance_factor = vertical_avoidance_factor

	# Movement Parameters
	config.combat_movement_speed_multiplier = combat_movement_speed_multiplier
	config.reposition_chance = reposition_chance
	config.reposition_min_time = reposition_min_time
	config.reposition_max_time = reposition_max_time
	config.wander_speed_multiplier = wander_speed_multiplier
	config.wander_interval_min = wander_interval_min
	config.wander_interval_max = wander_interval_max

	# Attack Behavior Parameters
	config.attack_commitment = attack_commitment
	config.post_attack_pause = post_attack_pause
	config.attack_retreat_distance = attack_retreat_distance
	config.attack_frequency = attack_frequency
	config.attack_telegraph_enabled = attack_telegraph_enabled
	config.attack_telegraph_time = attack_telegraph_time

	# Weapon System
	config.weapon_id = weapon_id

	# Legacy Parameters (Assign if they exist in EnemyConfig.gd)
	if "retreat_chance" in config:
		config.retreat_chance = retreat_chance
	if "jump_chance" in config:
		config.jump_chance = jump_chance # Note: This might be redundant if chase_jump_chance exists
	if "attack_lunge_strength" in config:
		config.attack_lunge_strength = attack_lunge_strength

	# Physics Parameters
	config.motion_mode = motion_mode
	config.debug_mode = debug_mode
	config.use_gravity = use_gravity

	# Attack Types (Deep copy is crucial!)
	config.attack_types = attack_types.duplicate(true)

	# Set state machine properties
	config.use_state_machine = use_state_machine
	if use_state_machine:
		config.states_config = states_config.duplicate(true)
	else:
		# Clear states_config if not using state machine, optional but good practice
		config.states_config = {} 

	# --- SAVE THE RESOURCE ---
	# Determine the correct directory based on whether it's a state machine config
	var config_dir_path = "resources/enemies/configs" # Default path
	if use_state_machine:
		config_dir_path = "state_machines/configs" # Path for state machine configs

	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(config_dir_path):
		var err_mk = dir.make_dir_recursive(config_dir_path)
		if err_mk != OK:
			printerr("Failed to create directory: %s, error code: %d" % [config_dir_path, err_mk])
			return # Stop if directory creation fails

	# Generate the file path (uses the updated enemy_id and determined path)
	var file_path = "res://%s/%s_config.tres" % [config_dir_path, enemy_id]

	# Save the resource
	var err_save = ResourceSaver.save(config, file_path)
	if err_save == OK:
		print("Successfully saved %s" % file_path)
		# Optionally re-scan filesystem for the editor to pick up the new file immediately
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("Failed to save %s, error code: %d" % [file_path, err_save])
