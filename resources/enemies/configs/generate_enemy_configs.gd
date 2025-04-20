@tool
extends EditorScript

# EDIT THESE VALUES for the enemy you want to generate
var enemy_id = "basic_enemy"
var display_name = "Basic Enemy"
var max_health = 80
var move_speed = 120.0
var acceleration = 10.0
var damping = 0.8
var detection_range = 300.0
var sight_range = 350.0
var preferred_attack_distance = 50.0
var preferred_distance_tolerance = 10.0
var use_avoidance = true
var avoidance_strength = 100.0
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5
var combat_movement_speed_multiplier = 0.5
var reposition_chance = 0.1
var reposition_min_time = 0.5
var reposition_max_time = 1.0
var wander_speed_multiplier = 0.4
var wander_interval_min = 2.0
var wander_interval_max = 5.0
var motion_mode = 0  # 0 = Normal, 1 = Floating
var debug_mode = false
var use_gravity = true
# EDIT THIS to configure the attack types
# For a melee enemy like the basic enemy:
var attack_types = {
	"melee": {
		"cooldown": 1.0,
		"damage": 10,
		"range": 50.0
	}
}

# For a melee enemy like the basic enemy (uncomment to use):
#var attack_types = {
#	"melee": {
#		"cooldown": 1.0,
#		"damage": 10,
#		"range": 50.0
#	}
#}

func _run():
	# Create new enemy config resource
	var config = EnemyConfig.new()
	
	# Set all properties
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
	config.attack_types = attack_types.duplicate(true)
	config.motion_mode = motion_mode
	config.debug_mode = debug_mode
	config.use_gravity = use_gravity
	
	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("resources/enemies/configs"):
		dir.make_dir_recursive("resources/enemies/configs")
	
	# Generate the file path
	var file_path = "res://resources/enemies/configs/%s_config.tres" % enemy_id
	
	# Save the resource
	var err = ResourceSaver.save(config, file_path)
	if err == OK:
		print("Successfully saved %s" % file_path)
	else:
		printerr("Failed to save %s, error code: %d" % [file_path, err])
