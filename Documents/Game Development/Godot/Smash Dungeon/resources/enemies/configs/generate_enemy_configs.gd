@tool
extends EditorScript

# --- Base Configuration Variables (Example: Based on Base Enemy SM) ---
var enemy_id = "basic_enemy_sm"
var display_name = "Basic Enemy SM"
# ... (Keep other global and state default variables as they were) ...
var max_health = 80
var move_speed = 120.0
var acceleration = 10.0
var damping = 0.8
var weapon_id = "sword"
var use_state_machine = true
var motion_mode = 0
var use_gravity = true
var debug_mode = false
var use_avoidance = true
var avoidance_strength = 100.0
var avoidance_ray_length = 60.0
var vertical_avoidance_factor = 0.5
var attack_types = { "melee": { "cooldown": 1.0, "range": 50.0, "damage": 10 } }

# --- State-Specific Default Parameters ---
var idle_defaults = { "wander_speed_multiplier": 0.4, "wander_interval_min": 2.0, "wander_interval_max": 5.0 }
var chase_defaults = { "sight_range": 350.0, "preferred_attack_distance": 50.0, "preferred_distance_tolerance": 10.0, "chase_speed_multiplier": 1.2, "direct_chase": false, "chase_jump_chance": 0.0, "chase_jump_force": 300.0, "aggression_level": 0.5 }
var telegraph_defaults = { "telegraph_duration": 0.6, "telegraph_movement_type": "none" }
var attack_defaults = { "attack_commitment": 0.3, "attack_retreat_distance": 0.0 }
var repositioning_defaults = { "reposition_min_time": 0.5, "reposition_max_time": 1.0 }
var stunned_defaults = { "stun_duration": 0.5 }
var death_defaults = {} # No defaults currently needed

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

# Define PARENT directories where enemy-specific folders will be created
const PARENT_CONFIG_DIR_LEGACY = "res://resources/enemies/configs"
const PARENT_CONFIG_DIR_SM = "res://state_machines/configs"


# --- Helper Function to Save Individual State Config ---
# Now saves directly into the provided enemy_config_dir_path
func save_state_config(state_name: String, state_config_instance: Resource, enemy_config_dir_path: String) -> String:
	if not is_instance_valid(state_config_instance):
		printerr("Invalid instance provided for state: ", state_name)
		return ""

	# Construct file path: e.g., res://state_machines/configs/basic_enemy_sm/idle_config.tres
	var file_name = "%s_config.tres" % [state_name.to_lower()] # Simpler filename
	var file_path = enemy_config_dir_path.path_join(file_name)

	# Save the state config resource (Directory existence checked before calling this)
	var err_save = ResourceSaver.save(state_config_instance, file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save == OK:
		print("  Successfully saved state config: %s" % file_path)
		return file_path # Return the path where it was saved
	else:
		printerr("  Failed to save state config %s, error code: %d" % [file_path, err_save])
		return ""


# --- Main Execution ---
func _run():
	print("--- Starting Enemy Config Generation for '%s' ---" % enemy_id)

	# --- 1. Load Required Classes ---
	var EnemyConfigClass = load("res://scripts/enemies/enemy_config.gd")
	if not EnemyConfigClass: printerr("EnemyConfig script not found."); return

	var state_config_classes = {}
	for state_name in STATE_CONFIG_SCRIPT_PATHS:
		var script_path = STATE_CONFIG_SCRIPT_PATHS[state_name]
		var loaded_script = load(script_path)
		if not loaded_script: printerr("Failed to load StateConfig script: %s for state %s" % [script_path, state_name]); continue
		state_config_classes[state_name] = loaded_script
	print("Loaded %d state config classes." % state_config_classes.size())


	# --- 2. Determine and Create Enemy-Specific Directory ---
	var parent_config_dir = PARENT_CONFIG_DIR_SM if use_state_machine else PARENT_CONFIG_DIR_LEGACY
	# Construct the path for the enemy's dedicated folder: e.g., res://state_machines/configs/basic_enemy_sm
	var enemy_config_dir = parent_config_dir.path_join(enemy_id)

	# Ensure the enemy-specific directory exists
	var dir_access = DirAccess.open("res://")
	if not dir_access: printerr("Failed to access res://"); return
	if not dir_access.dir_exists(enemy_config_dir.replace("res://", "")):
		var err_mk = dir_access.make_dir_recursive(enemy_config_dir.replace("res://", ""))
		if err_mk != OK:
			printerr("Failed to create enemy config directory: %s, error code: %d" % [enemy_config_dir, err_mk])
			return
		else:
			print("Created directory: %s" % enemy_config_dir)


	# --- 3. Create Main Config Instance ---
	var main_config = EnemyConfigClass.new()

	# --- 4. Set GLOBAL Properties on Main Config ---
	main_config.enemy_id = enemy_id
	main_config.display_name = display_name
	# ... (set other global properties as before) ...
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


	# --- 5. Create, Populate, Save, and Link STATE Config Resources ---
	if use_state_machine:
		print("Generating State Config Resources into: %s" % enemy_config_dir)
		var state_defaults = {
			"Idle": idle_defaults, "Chase": chase_defaults, "Telegraph": telegraph_defaults,
			"Attack": attack_defaults, "Repositioning": repositioning_defaults,
			"Stunned": stunned_defaults, "Death": death_defaults
		}

		for state_name in state_defaults:
			if not state_config_classes.has(state_name): continue # Skip if script wasn't loaded

			var StateConfigClass = state_config_classes[state_name]
			var state_config_instance = StateConfigClass.new()

			var defaults = state_defaults[state_name]
			for param_name in defaults:
				if param_name in state_config_instance: state_config_instance.set(param_name, defaults[param_name])
				else: push_warning("...") # Warning as before

			# Save the state config INTO the enemy's directory
			var saved_state_config_path = save_state_config(state_name, state_config_instance, enemy_config_dir)

			# Link it to the main config
			if not saved_state_config_path.is_empty():
				var loaded_state_config = load(saved_state_config_path)
				if is_instance_valid(loaded_state_config):
					var config_var_name = state_name.to_lower() + "_config"
					if config_var_name in main_config: main_config.set(config_var_name, loaded_state_config)
					else: printerr("Main EnemyConfig missing var '%s'" % config_var_name)
				else: printerr("Failed to load back saved state config: %s" % saved_state_config_path)

	# --- 6. Save the MAIN Config Resource ---
	# Construct the full file path for the main config inside the enemy folder
	var main_file_path = enemy_config_dir.path_join("config.tres") # Use simple name "config.tres"

	var err_save_main = ResourceSaver.save(main_config, main_file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save_main == OK:
		print("Successfully generated and saved MAIN config: %s" % main_file_path)
	else:
		printerr("Failed to save MAIN config resource %s, error code: %d" % [main_file_path, err_save_main])

	# Attempt to refresh filesystem
	if Engine.is_editor_hint():
		var editor_fs = EditorInterface.get_resource_filesystem()
		if editor_fs: editor_fs.scan(); print("Editor filesystem scan requested.")

	print("--- Enemy Config Generation Finished ---")
