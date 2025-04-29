@tool
extends EditorScript

# Preload config scripts needed for enums/constants if possible in @tool
# Note: Preloading might sometimes be tricky in EditorScript, use integer value if it fails.
const ChaseStateConfig = preload("res://state_machines/states/state_configs/chase_state_config.gd")
const EnemyConfig = preload("res://scripts/enemies/enemy_config.gd") # Preload main config too

# --- Base Configuration Variables (MODIFIED FOR JUMPER SM) ---
var enemy_id = "jumper_sm"
var display_name = "Jumper Enemy SM"

# --- Global Defaults (ADJUSTED FOR JUMPER, includes NEW variables) ---
# Core Stats
var max_health = 60
var move_speed = 100.0
var acceleration = 800.0 # <--- Using the higher value from debugging
var damping = 0.9
# Weapon
var weapon_id = "melee_stomp"
var attack_types = { "melee": { "cooldown": 0.3, "range": 45.0, "damage": 15 } } # Lower cooldown
# State Machine
var use_state_machine = true
# Physics
var motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED # Use engine constant
var use_gravity = true # <-- NEW/CONFIRMED DEFAULT
var debug_mode = true # <-- Keep debug true for jumper testing
# Combat Behavior
var combat_movement_speed_multiplier = 0.7 # <-- NEW DEFAULT
var min_attack_state_duration = 0.15 # <-- NEW DEFAULT (lower)
# Avoidance
var use_avoidance = true # <-- NEW/CONFIRMED DEFAULT
var avoidance_strength = 150.0 # <-- NEW/CONFIRMED DEFAULT (adjust as needed)
var avoidance_ray_length = 75.0 # <-- NEW/CONFIRMED DEFAULT (adjust as needed)
var vertical_avoidance_factor = 0.6 # <-- NEW/CONFIRMED DEFAULT

# --- State-Specific Default Parameters (ADJUSTED FOR JUMPER) ---
var idle_defaults = {
	"wander_speed_multiplier": 0.4,
	"wander_interval_min": 1.5,
	"wander_interval_max": 4.0
}
var chase_defaults = {
	# Detection & Range
	"sight_range": 450.0,
	"preferred_attack_distance": 40.0,
	"preferred_distance_tolerance": 20.0,
	# Movement
	"chase_speed_multiplier": 1.1,
	"direct_chase": true,
	# Jumping
	"chase_jump_chance": 0.15, # Adjust this heavily!
	"chase_jump_force": 400.0,
	"chase_jump_type": ChaseStateConfig.JumpType.AIMED, # Defaulting to Aimed now
	# Behavior
	"aggression_level": 0.7 # Slightly more aggressive
}
var telegraph_defaults = {
	"telegraph_duration": 0.0, # Set to 0 based on testing
	"telegraph_movement_type": "none"
}
var attack_defaults = {
	"attack_commitment": 0.15, # Set lower based on testing
	"attack_retreat_distance": 0.0
}
var repositioning_defaults = {
	"reposition_min_time": 1.0,
	"reposition_max_time": 1.5
}
var stunned_defaults = {
	"stun_duration": 0.6
}
var death_defaults = {}

# --- Paths ---
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


# --- Helper Function ---
# (save_state_config function remains unchanged)
func save_state_config(state_name: String, state_config_instance: Resource, enemy_config_dir_path: String) -> String:
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

# --- Main Execution ---
func _run():
	print("--- Starting Enemy Config Generation for '%s' ---" % enemy_id)

	# --- 1. Load Required Classes ---
	# EnemyConfigClass is preloaded now
	if not EnemyConfig: printerr("EnemyConfig script not found or failed preload."); return

	var state_config_classes = {}
	for state_name in STATE_CONFIG_SCRIPT_PATHS:
		var script_path = STATE_CONFIG_SCRIPT_PATHS[state_name]
		var loaded_script = load(script_path) # Keep load here, might be more robust than preload in tool script
		if not loaded_script: printerr("Failed to load StateConfig script: %s for state %s" % [script_path, state_name]); continue
		state_config_classes[state_name] = loaded_script
	print("Loaded %d state config classes." % state_config_classes.size())

	# --- 2. Determine and Create Enemy-Specific Directory ---
	# (Unchanged)
	var parent_config_dir = PARENT_CONFIG_DIR_SM # Assuming use_state_machine is true
	var enemy_config_dir = parent_config_dir.path_join(enemy_id)
	var dir_access = DirAccess.open("res://")
	if not dir_access: printerr("Failed to access res://"); return
	if not dir_access.dir_exists(enemy_config_dir.replace("res://", "")):
		var err_mk = dir_access.make_dir_recursive(enemy_config_dir.replace("res://", ""))
		if err_mk != OK: printerr("Failed to create enemy config directory: %s, error code: %d" % [enemy_config_dir, err_mk]); return
		else: print("Created directory: %s" % enemy_config_dir)

	# --- 3. Create Main Config Instance ---
	var main_config = EnemyConfig.new() # Use preloaded class

	# --- 4. Set GLOBAL Properties on Main Config --- # <-- MODIFIED SECTION
	main_config.enemy_id = enemy_id
	main_config.display_name = display_name
	# Core Stats
	main_config.max_health = max_health
	main_config.move_speed = move_speed
	main_config.acceleration = acceleration
	main_config.damping = damping
	# Weapon
	main_config.weapon_id = weapon_id
	main_config.attack_types = attack_types.duplicate(true)
	# State Machine
	main_config.use_state_machine = use_state_machine
	# Physics & Debug
	main_config.motion_mode = motion_mode
	main_config.use_gravity = use_gravity # <-- ADDED
	main_config.debug_mode = debug_mode
	# Combat Behavior
	main_config.combat_movement_speed_multiplier = combat_movement_speed_multiplier # <-- ADDED
	main_config.min_attack_state_duration = min_attack_state_duration # <-- ADDED
	# Avoidance
	main_config.use_avoidance = use_avoidance # <-- ADDED
	main_config.avoidance_strength = avoidance_strength # <-- ADDED
	main_config.avoidance_ray_length = avoidance_ray_length # <-- ADDED
	main_config.vertical_avoidance_factor = vertical_avoidance_factor # <-- ADDED

	print("Set global parameters on main config.")

	# --- 5. Create, Populate, Save, and Link STATE Config Resources ---
	# (Unchanged logic, but uses updated state_defaults)
	if use_state_machine:
		print("Generating State Config Resources into: %s" % enemy_config_dir)
		var state_defaults = {
			"Idle": idle_defaults, "Chase": chase_defaults, "Telegraph": telegraph_defaults,
			"Attack": attack_defaults, "Repositioning": repositioning_defaults,
			"Stunned": stunned_defaults, "Death": death_defaults
		}
		for state_name in state_defaults:
			if not state_config_classes.has(state_name): continue
			var StateConfigClass = state_config_classes[state_name]
			var state_config_instance = StateConfigClass.new()
			var defaults = state_defaults[state_name]
			for param_name in defaults:
				if param_name in state_config_instance:
					# Handle enum case for chase_jump_type
					if state_name == "Chase" and param_name == "chase_jump_type":
						# Assuming the default var holds the enum value directly
						state_config_instance.set(param_name, defaults[param_name])
					else:
						state_config_instance.set(param_name, defaults[param_name])
				else: push_warning("Parameter '%s' not found in %sConfig script. Check for typos or missing @export." % [param_name, state_name])
			var saved_state_config_path = save_state_config(state_name, state_config_instance, enemy_config_dir)
			if not saved_state_config_path.is_empty():
				var loaded_state_config = load(saved_state_config_path)
				if is_instance_valid(loaded_state_config):
					var config_var_name = state_name.to_lower() + "_config"
					if config_var_name in main_config: main_config.set(config_var_name, loaded_state_config)
					else: printerr("Main EnemyConfig missing var '%s'" % config_var_name)
				else: printerr("Failed to load back saved state config: %s" % saved_state_config_path)

	# --- 6. Save the MAIN Config Resource ---
	# (Unchanged)
	var main_file_path = enemy_config_dir.path_join("config.tres")
	var err_save_main = ResourceSaver.save(main_config, main_file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save_main == OK: print("Successfully generated and saved MAIN config: %s" % main_file_path)
	else: printerr("Failed to save MAIN config resource %s, error code: %d" % [main_file_path, err_save_main])

	# --- Filesystem Refresh ---
	# (Unchanged)
	if Engine.is_editor_hint():
		var editor_fs = EditorInterface.get_resource_filesystem()
		if editor_fs: editor_fs.scan(); print("Editor filesystem scan requested.")

	print("--- Enemy Config Generation Finished ---")
