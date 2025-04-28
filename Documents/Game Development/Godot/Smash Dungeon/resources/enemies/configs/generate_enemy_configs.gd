@tool
extends EditorScript

# --- Base Configuration Variables (MODIFIED FOR FODDER SM) ---
var enemy_id = "fodder_sm" # <--- CHANGED
var display_name = "Fodder Enemy SM" # <--- CHANGED

# --- Global Defaults (ADJUSTED FOR FODDER) ---
var max_health = 30 # Lower health for fodder
var move_speed = 140.0 # Fodder might be slightly faster/more erratic base speed
var acceleration = 12.0 # Higher acceleration for quick movements
var damping = 0.85 # Slightly less damping to feel less controlled
var weapon_id = "melee_short" # Assuming a basic melee weapon, adjust if needed
var use_state_machine = true
var motion_mode = 0 # Grounded
var use_gravity = true
var debug_mode = false # Default to false
var use_avoidance = false # Fodder might not need/use avoidance
var avoidance_strength = 100.0 # Keep defaults if enabled later
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5
# Fodder might not need complex attack types dictionary if using a simple weapon
var attack_types = { "melee": { "cooldown": 0.8, "range": 40.0, "damage": 5 } } # Simpler, faster attack

# --- State-Specific Default Parameters (ADJUSTED FOR FODDER) ---
# Based on old fodder_enemy_sm.gd hardcoded values and general fodder concept

var idle_defaults = {
	"wander_speed_multiplier": 0.5, # Slightly faster wandering
	"wander_interval_min": 1.0, # More frequent wandering
	"wander_interval_max": 3.0
}
var chase_defaults = {
	# Detection & Range
	"sight_range": 500.0, # From old script detection_range
	"preferred_attack_distance": 35.0, # Closer attack range (adjusted from old script)
	"preferred_distance_tolerance": 20.0, # Tighter tolerance (adjusted from old script)
	# Movement
	"chase_speed_multiplier": 1.6, # Aggressive chase speed (adjusted from old script)
	"direct_chase": true, # From old script
	"chase_jump_chance": 0.15, # Slightly increased jump chance (from old script)
	"chase_jump_force": 350.0, # From old script
	# Behavior
	"aggression_level": 0.9 # From old script
}
var telegraph_defaults = {
	"telegraph_duration": 0.3, # Shorter telegraph for fodder
	"telegraph_movement_type": "none" # Fodder likely stops to telegraph
}
var attack_defaults = {
	"attack_commitment": 0.15, # Very short commitment after attacking
	"attack_retreat_distance": 0.0 # Fodder likely doesn't retreat deliberately
}
var repositioning_defaults = {
	# Make repositioning very unlikely or short if triggered
	"reposition_min_time": 0.1,
	"reposition_max_time": 0.3
}
var stunned_defaults = {
	"stun_duration": 0.4 # Shorter stun duration
}
var death_defaults = {} # No defaults currently needed

# --- Paths (Keep as is) ---
const STATE_CONFIG_SCRIPT_PATHS = {
	"Idle": "res://state_machines/states/state_configs/idle_state_config.gd",
	"Chase": "res://state_machines/states/state_configs/chase_state_config.gd",
	"Telegraph": "res://state_machines/states/state_configs/telegraph_state_config.gd",
	"Attack": "res://state_machines/states/state_configs/attack_state_config.gd",
	"Repositioning": "res://state_machines/states/state_configs/repositioning_state_config.gd",
	"Stunned": "res://state_machines/states/state_configs/stunned_state_config.gd",
	"Death": "res://state_machines/states/state_configs/death_state_config.gd"
}
const PARENT_CONFIG_DIR_LEGACY = "res://resources/enemies/configs"
const PARENT_CONFIG_DIR_SM = "res://state_machines/configs"


# --- Helper Function (Keep as is) ---
func save_state_config(state_name: String, state_config_instance: Resource, enemy_config_dir_path: String) -> String:
	# ... (rest of function remains the same) ...
	if not is_instance_valid(state_config_instance):
		printerr("Invalid instance provided for state: ", state_name)
		return ""
	var file_name = "%s_config.tres" % [state_name.to_lower()]
	var file_path = enemy_config_dir_path.path_join(file_name)
	var err_save = ResourceSaver.save(state_config_instance, file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save == OK:
		print("  Successfully saved state config: %s" % file_path)
		return file_path
	else:
		printerr("  Failed to save state config %s, error code: %d" % [file_path, err_save])
		return ""


# --- Main Execution (Keep structure, uses modified vars above) ---
func _run():
	print("--- Starting Enemy Config Generation for '%s' ---" % enemy_id) # Will now print "fodder_sm"

	# --- 1. Load Required Classes (Keep as is) ---
	var EnemyConfigClass = load("res://scripts/enemies/enemy_config.gd")
	if not EnemyConfigClass: printerr("EnemyConfig script not found."); return
	var state_config_classes = {}
	for state_name in STATE_CONFIG_SCRIPT_PATHS:
		var script_path = STATE_CONFIG_SCRIPT_PATHS[state_name]
		var loaded_script = load(script_path)
		if not loaded_script: printerr("Failed to load StateConfig script: %s for state %s" % [script_path, state_name]); continue
		state_config_classes[state_name] = loaded_script
	print("Loaded %d state config classes." % state_config_classes.size())

	# --- 2. Determine and Create Enemy-Specific Directory (Keep as is) ---
	# Will now create res://state_machines/configs/fodder_sm/
	var parent_config_dir = PARENT_CONFIG_DIR_SM if use_state_machine else PARENT_CONFIG_DIR_LEGACY
	var enemy_config_dir = parent_config_dir.path_join(enemy_id)
	var dir_access = DirAccess.open("res://")
	if not dir_access: printerr("Failed to access res://"); return
	if not dir_access.dir_exists(enemy_config_dir.replace("res://", "")):
		var err_mk = dir_access.make_dir_recursive(enemy_config_dir.replace("res://", ""))
		if err_mk != OK:
			printerr("Failed to create enemy config directory: %s, error code: %d" % [enemy_config_dir, err_mk])
			return
		else:
			print("Created directory: %s" % enemy_config_dir)

	# --- 3. Create Main Config Instance (Keep as is) ---
	var main_config = EnemyConfigClass.new()

	# --- 4. Set GLOBAL Properties on Main Config (Keep as is) ---
	# Will use the adjusted fodder defaults defined above
	main_config.enemy_id = enemy_id
	main_config.display_name = display_name
	main_config.max_health = max_health
	main_config.move_speed = move_speed
	main_config.acceleration = acceleration
	main_config.damping = damping
	main_config.weapon_id = weapon_id
	main_config.use_state_machine = use_state_machine
	main_config.motion_mode = motion_mode
	main_config.use_gravity = use_gravity
	main_config.debug_mode = debug_mode
	main_config.use_avoidance = use_avoidance
	main_config.avoidance_strength = avoidance_strength
	main_config.avoidance_ray_length = avoidance_ray_length
	main_config.vertical_avoidance_factor = vertical_avoidance_factor
	main_config.attack_types = attack_types.duplicate(true)
	print("Set global parameters on main config.")

	# --- 5. Create, Populate, Save, and Link STATE Config Resources (Keep as is) ---
	# Will use the adjusted fodder state defaults defined above
	if use_state_machine:
		print("Generating State Config Resources into: %s" % enemy_config_dir)
		var state_defaults = {
			"Idle": idle_defaults, "Chase": chase_defaults, "Telegraph": telegraph_defaults,
			"Attack": attack_defaults, "Repositioning": repositioning_defaults,
			"Stunned": stunned_defaults, "Death": death_defaults
		}
		for state_name in state_defaults:
			# ... (rest of loop remains the same) ...
			if not state_config_classes.has(state_name): continue
			var StateConfigClass = state_config_classes[state_name]
			var state_config_instance = StateConfigClass.new()
			var defaults = state_defaults[state_name]
			for param_name in defaults:
				if param_name in state_config_instance: state_config_instance.set(param_name, defaults[param_name])
				else: push_warning("Parameter '%s' not found in %sConfig script. Check for typos or missing @export." % [param_name, state_name]) # Added warning
			var saved_state_config_path = save_state_config(state_name, state_config_instance, enemy_config_dir)
			if not saved_state_config_path.is_empty():
				var loaded_state_config = load(saved_state_config_path)
				if is_instance_valid(loaded_state_config):
					var config_var_name = state_name.to_lower() + "_config"
					if config_var_name in main_config: main_config.set(config_var_name, loaded_state_config)
					else: printerr("Main EnemyConfig missing var '%s'" % config_var_name)
				else: printerr("Failed to load back saved state config: %s" % saved_state_config_path)


	# --- 6. Save the MAIN Config Resource (Keep as is) ---
	# Will save into res://state_machines/configs/fodder_sm/config.tres
	var main_file_path = enemy_config_dir.path_join("config.tres")
	var err_save_main = ResourceSaver.save(main_config, main_file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save_main == OK:
		print("Successfully generated and saved MAIN config: %s" % main_file_path)
	else:
		printerr("Failed to save MAIN config resource %s, error code: %d" % [main_file_path, err_save_main])

	# --- Filesystem Refresh (Keep as is) ---
	if Engine.is_editor_hint():
		var editor_fs = EditorInterface.get_resource_filesystem()
		if editor_fs: editor_fs.scan(); print("Editor filesystem scan requested.")

	print("--- Enemy Config Generation Finished ---")
