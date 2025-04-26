@tool
extends EditorScript

# EDIT THESE VALUES for the enemy you want to generate
var enemy_id = "basic_enemy_sm"
var display_name = "Basic Enemy SM" 
var max_health = 80
var move_speed = 120.0
var acceleration = 10.0
var damping = 0.8

# Detection & Combat Parameters
var detection_range = 300.0
var sight_range = 350.0
var preferred_attack_distance = 50.0
var preferred_distance_tolerance = 10.0

# Aggression Parameters
var aggression_level = 0.5
var chase_speed_multiplier = 1.2
var direct_chase = false
var chase_jump_chance = 0.0
var chase_jump_force = 300.0

# Avoidance Parameters
var use_avoidance = true
var avoidance_strength = 100.0
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5

# Movement Parameters
var combat_movement_speed_multiplier = 0.5
var reposition_chance = 0.1
var reposition_min_time = 0.5
var reposition_max_time = 1.0
var wander_speed_multiplier = 0.4
var wander_interval_min = 2.0
var wander_interval_max = 5.0

# Attack Behavior Parameters
var attack_commitment = 0.6
var post_attack_pause = 0.0
var attack_retreat_distance = 0.0
var attack_frequency = 1.0
var attack_telegraph_enabled = false
var attack_telegraph_time = 0.3

# Weapon System Parameters
var weapon_id = "sword"

# Legacy Parameters (keep these for compatibility)
var retreat_chance = 0.1  # Match with reposition_chance
var jump_chance = 0.0
var attack_lunge_strength = 0.0

# Physics Parameters
var motion_mode = 0  # 0 = Normal (affected by gravity)
var debug_mode = false
var use_gravity = true

# Attack Definitions
var attack_types = {
	"melee": {
		"cooldown": 1.0,
		"range": 50.0,
		"damage": 10
	}
}

# State Machine Support
var use_state_machine = true  # Set to true to generate a state machine enemy config

# State-specific configurations (only used when use_state_machine is true)
var states_config = {
	"IdleState": {
		"wander_speed_multiplier": 0.4,
		"wander_interval_min": 2.0,
		"wander_interval_max": 5.0
	},
	"ChaseState": {
		"sight_range": 350.0,
		"preferred_attack_distance": 50.0,
		"preferred_distance_tolerance": 10.0,
		"chase_speed_multiplier": 1.2,
		"direct_chase": false,
		"aggression_level": 0.5
	},
	"AttackState": {
		"attack_commitment": 0.6,
		"post_attack_pause": 0.0,
		"min_attack_state_duration": 0.5,
		"combat_movement_speed_multiplier": 0.5
	},
	"RepositioningState": {
		"reposition_chance": 0.1,
		"reposition_min_time": 0.5,
		"reposition_max_time": 1.0
	},
	"StunnedState": {
		"stun_duration": 1.0
	},
	"DeathState": {}
}

func _run():
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
		config.jump_chance = jump_chance
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

	# --- SAVE THE RESOURCE ---
	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	var config_dir_path = "resources/enemies/configs" # Define path for clarity
	if not dir.dir_exists(config_dir_path):
		var err_mk = dir.make_dir_recursive(config_dir_path)
		if err_mk != OK:
			printerr("Failed to create directory: %s, error code: %d" % [config_dir_path, err_mk])
			return # Stop if directory creation fails

	# Generate the file path (uses the updated enemy_id)
	var file_path = "res://%s/%s_config.tres" % [config_dir_path, enemy_id]

	# Save the resource
	var err_save = ResourceSaver.save(config, file_path)
	if err_save == OK:
		print("Successfully saved %s" % file_path)
	else:
		printerr("Failed to save %s, error code: %d" % [file_path, err_save])
