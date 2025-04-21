@tool
extends EditorScript

# EDIT THESE VALUES for the enemy you want to generate
var enemy_id = "zap_fodder" # Changed from basic_fodder_enemy
var display_name = "Zap Wisp" 
var max_health = 40 # Adjusted for Zap Wisp
var move_speed = 120.0 # Adjusted for Zap Wisp (flying)
var acceleration = 8.0 # Adjusted for Zap Wisp
var damping = 0.9 # Adjusted for Zap Wisp

# Detection & Combat Parameters
var detection_range = 400.0 # Adjusted for Zap Wisp
var sight_range = 600.0 # Adjusted for Zap Wisp
var preferred_attack_distance = 60.0 # Adjusted for Zap Wisp (close range zap)
var preferred_distance_tolerance = 20.0 # Adjusted for Zap Wisp

# Aggression Parameters
var aggression_level = 0.6 # Adjusted for Zap Wisp
var chase_speed_multiplier = 1.0 # Adjusted for Zap Wisp (floating)
var direct_chase = true # Zap Wisp moves directly
var chase_jump_chance = 0.0 # Zap Wisp doesn't jump
var chase_jump_force = 0.0 # Zap Wisp doesn't jump

# Avoidance Parameters
var use_avoidance = true # Zap Wisp uses avoidance
var avoidance_strength = 100.0 # Adjusted for Zap Wisp
var avoidance_ray_length = 60.0 # Adjusted for Zap Wisp
var vertical_avoidance_factor = 1.0 # Adjusted for Zap Wisp (equal avoidance)

# Movement Parameters
var combat_movement_speed_multiplier = 0.8 # Adjusted for Zap Wisp
var reposition_chance = 0.1 # Adjusted for Zap Wisp (less repositioning)
var reposition_min_time = 0.8 # Adjusted for Zap Wisp
var reposition_max_time = 1.5 # Adjusted for Zap Wisp
var wander_speed_multiplier = 0.6 # Adjusted for Zap Wisp
var wander_interval_min = 2.0 # Adjusted for Zap Wisp
var wander_interval_max = 5.0 # Adjusted for Zap Wisp

# Attack Behavior Parameters
var attack_commitment = 0.8 # Adjusted for Zap Wisp
var post_attack_pause = 0.5 # Adjusted for Zap Wisp
var attack_retreat_distance = 0.0 # Zap Wisp doesn't retreat
var attack_frequency = 1.0 # Zap Wisp base frequency
var attack_telegraph_enabled = true # Zap Wisp telegraphs
var attack_telegraph_time = 0.8 # Zap Wisp telegraph duration

# Weapon System Parameters
var weapon_id = "zap_aoe" # Changed to the zap weapon

# Legacy Fodder-specific Parameters (some can be removed eventually)
# Note: These might be less relevant now with BaseEnemy's parameters
var retreat_chance = 0.1 # Adjusted to align with reposition_chance/commitment
var jump_chance = 0.0 # Adjusted (flying)
var attack_lunge_strength = 0.0 # Not applicable

# Physics Parameters
var motion_mode = 1  # Changed: 1 = Floating
var debug_mode = false
var use_gravity = false # Changed: Disable gravity

# Attack Definitions
# Note: Defines the *conditions* for triggering the equipped weapon's attack.
# Damage/radius/etc. are primarily defined in the weapon's JSON ("zap_aoe").
var attack_types = {
	"area_zap": {          # Identifier for the zap trigger condition
		"cooldown": 3.5,   # Enemy-specific trigger cooldown
		"range": 75.0      # Distance threshold to initiate the attack
	}
} # Changed from melee definition

func _run():
	# Create new enemy config resource
	var config = EnemyConfig.new()

	# Set all properties (Uses the values defined in the section above)
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
	# Note: attack_lunge_strength likely doesn't exist in EnemyConfig

	# Physics Parameters
	config.motion_mode = motion_mode
	config.debug_mode = debug_mode
	config.use_gravity = use_gravity

	# Attack Types (Deep copy is crucial!)
	config.attack_types = attack_types.duplicate(true)

	# --- SAVE THE RESOURCE --- (Original comments preserved)

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
