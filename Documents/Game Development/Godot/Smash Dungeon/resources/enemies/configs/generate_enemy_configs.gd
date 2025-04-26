@tool
extends EditorScript

# --- Configuration Variables (Example: Based on Base Enemy SM) ---
var enemy_id = "basic_enemy_sm"
var display_name = "Basic Enemy SM"
var max_health = 80
var move_speed = 120.0
var acceleration = 10.0
var damping = 0.8

var detection_range = 300.0
var sight_range = 350.0
var preferred_attack_distance = 50.0
var preferred_distance_tolerance = 10.0

var aggression_level = 0.5 # Base aggression level (can be overridden in ChaseState config)
var chase_speed_multiplier = 1.2 # Base chase speed (can be overridden in ChaseState config)
var direct_chase = false # Base chase behavior (can be overridden in ChaseState config)
var chase_jump_chance = 0.0 # Base jump chance
var chase_jump_force = 300.0 # Base jump force

var use_avoidance = true
var avoidance_strength = 100.0
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5

var combat_movement_speed_multiplier = 0.5 # Base combat speed (used if not in AttackState config)
var reposition_chance = 0.1 # Base reposition chance (used if not in RepositioningState config)
var reposition_min_time = 0.5 # Base reposition time (used if not in RepositioningState config)
var reposition_max_time = 1.0 # Base reposition time (used if not in RepositioningState config)
var wander_speed_multiplier = 0.4 # Base wander speed (used if not in IdleState config)
var wander_interval_min = 2.0 # Base wander time (used if not in IdleState config)
var wander_interval_max = 5.0 # Base wander time (used if not in IdleState config)

var attack_commitment = 0.5 # Base commitment (used if not in AttackState config)
var attack_retreat_distance = 0.0 # Base retreat distance (used if not in AttackState config)
var attack_frequency = 1.0 # Corresponds to default melee cooldown
var attack_telegraph_enabled = true # Legacy - may not be used directly by SM
var attack_telegraph_time = 0.6 # Default telegraph time (used for TelegraphState config)

var weapon_id = "sword" # Example weapon

var retreat_chance = 0.0 # Legacy
var jump_chance = 0.0 # Legacy
var attack_lunge_strength = 0.0 # Legacy

var motion_mode = 0 # MOTION_MODE_GROUNDED
var debug_mode = false
var use_gravity = true

var attack_types = {
	"melee": {
		"cooldown": 1.0,
		"range": 50.0,
		"damage": 10
	}
}

var use_state_machine = true

# State Machine Configuration Dictionary
var states_config = {
	"IdleState": {
		"wander_speed_multiplier": 0.4,
		"wander_interval_min": 2.0,
		"wander_interval_max": 5.0
	},
	"ChaseState": {
		"chase_speed_multiplier": 1.2,
		"direct_chase": false,
		"aggression_level": 0.5,
		"jump_chance": 0.0 # Example: Basic enemy doesn't jump in chase
		# Note: sight_range, preferred_attack_distance, preferred_distance_tolerance are often handled by base enemy logic or ChaseState directly reading base enemy props, but could be added here if needed per-state override.
	},
	"TelegraphState": { # New state configuration
		"telegraph_duration": 0.6, # Use the value from attack_telegraph_time
		"telegraph_movement_type": "none" # Example: Basic enemy stands still
	},
	"AttackState": { # Updated state configuration
		"attack_commitment": 0.3, # Example: Lower commitment after attack for basic enemy
		"attack_retreat_distance": 0.0 # Example: Basic enemy doesn't retreat
		# Removed: telegraph_time, post_attack_pause, min_attack_state_duration, combat_movement_speed_multiplier (if movement handled elsewhere/differently)
	},
	"RepositioningState": {
		"reposition_chance": 0.1, # Often checked before entering, params below affect duration/behavior within state
		"reposition_min_time": 0.5,
		"reposition_max_time": 1.0
	},
	"StunnedState": {
		"stun_duration": 0.5 # Example default stun duration
	},
	"DeathState": {
		# No specific parameters needed for base DeathState usually
	}
}
# --- End Configuration Variables ---


func _run():
	# Ensure the EnemyConfig class is available
	var EnemyConfigClass = load("res://scripts/enemies/enemy_config.gd")
	if not EnemyConfigClass:
		printerr("EnemyConfig script not found at 'res://scripts/enemies/enemy_config.gd'.")
		return
	if not ClassDB.can_instantiate("EnemyConfig"):
		printerr("EnemyConfig class not found or invalid. Ensure 'res://scripts/enemies/enemy_config.gd' has 'class_name EnemyConfig'.")
		return

	# Create new enemy config resource
	var config = EnemyConfigClass.new()

	# --- Set properties on the config object ---
	config.enemy_id = enemy_id
	config.display_name = display_name
	config.max_health = max_health
	config.move_speed = move_speed
	config.acceleration = acceleration
	config.damping = damping

	config.detection_range = detection_range
	config.sight_range = sight_range
	config.preferred_attack_distance = preferred_attack_distance
	config.preferred_distance_tolerance = preferred_distance_tolerance

	config.aggression_level = aggression_level
	config.chase_speed_multiplier = chase_speed_multiplier
	config.direct_chase = direct_chase
	config.chase_jump_chance = chase_jump_chance
	config.chase_jump_force = chase_jump_force

	config.use_avoidance = use_avoidance
	config.avoidance_strength = avoidance_strength
	config.avoidance_ray_length = avoidance_ray_length
	config.vertical_avoidance_factor = vertical_avoidance_factor

	config.combat_movement_speed_multiplier = combat_movement_speed_multiplier
	config.reposition_chance = reposition_chance
	config.reposition_min_time = reposition_min_time
	config.reposition_max_time = reposition_max_time
	config.wander_speed_multiplier = wander_speed_multiplier
	config.wander_interval_min = wander_interval_min
	config.wander_interval_max = wander_interval_max

	# Set base attack parameters (some might be redundant if solely relying on state configs)
	config.attack_commitment = attack_commitment
	config.attack_retreat_distance = attack_retreat_distance
	config.attack_frequency = attack_frequency
	config.attack_telegraph_enabled = attack_telegraph_enabled
	config.attack_telegraph_time = attack_telegraph_time

	config.weapon_id = weapon_id

	# Check and set legacy properties if they exist on the EnemyConfig script
	var config_props = config.get_script().get_script_property_list()
	var prop_names = []
	for prop in config_props:
		prop_names.append(prop.name)

	if "retreat_chance" in prop_names:
		config.retreat_chance = retreat_chance
	if "jump_chance" in prop_names:
		config.jump_chance = jump_chance
	if "attack_lunge_strength" in prop_names:
		config.attack_lunge_strength = attack_lunge_strength

	config.motion_mode = motion_mode
	config.debug_mode = debug_mode
	config.use_gravity = use_gravity

	config.attack_types = attack_types.duplicate(true) # Ensure deep copy

	# State Machine properties
	config.use_state_machine = use_state_machine
	if use_state_machine:
		# Use the pre-defined dictionary structure, ensuring a deep copy
		config.states_config = states_config.duplicate(true)
		# Transfer the relevant base attack_telegraph_time to the TelegraphState config
		if config.states_config.has("TelegraphState") and "telegraph_duration" in config.states_config["TelegraphState"]:
			config.states_config["TelegraphState"]["telegraph_duration"] = attack_telegraph_time
	else:
		config.states_config = {}


	# --- SAVE THE RESOURCE ---
	# Determine the correct directory based on whether the state machine is used
	var config_dir_path = "resources/enemies/configs"
	if use_state_machine:
		config_dir_path = "state_machines/configs"

	# Ensure the target directory exists
	var dir_access = DirAccess.open("res://")
	if not dir_access:
		printerr("Failed to access resource directory 'res://'.")
		return

	if not dir_access.dir_exists(config_dir_path):
		var err_mk = dir_access.make_dir_recursive(config_dir_path)
		if err_mk != OK:
			printerr("Failed to create directory: res://%s, error code: %d" % [config_dir_path, err_mk])
			return

	# Construct the full file path
	var file_path = "res://%s/%s_config.tres" % [config_dir_path, enemy_id]

	# Save the resource file
	var err_save = ResourceSaver.save(config, file_path)
	if err_save == OK:
		print("Successfully generated and saved config: %s" % file_path)
		# Attempt to refresh the filesystem view in the editor
		if Engine.is_editor_hint():
			var editor_fs = EditorInterface.get_resource_filesystem()
			if editor_fs:
				editor_fs.scan()
	else:
		printerr("Failed to save config resource %s, error code: %d" % [file_path, err_save])
