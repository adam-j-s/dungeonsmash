@tool
extends EditorScript

# --- Preload Base and Specific Config Classes ---
var ChaseStateConfig = preload("res://state_machines/states/state_configs/chase_state_config.gd")
var EnemyConfig = preload("res://scripts/enemies/enemy_config.gd")
# Adjust path if needed for BouncerConfig
var BouncerConfig = load("res://scripts/enemies/configs/bouncer_config.gd")

# ==============================================================
# --- Configuration For Which Enemy To Generate ---
# ==============================================================
var enemy_id = "bouncer_sm" # <--- SET THIS TO THE ENEMY ID YOU WANT TO GENERATE
var display_name = "Bouncer Enemy SM" # <--- SET THIS TO MATCH enemy_id

# ==============================================================
# --- Define BASE DEFAULT VALUES ---
# These are the starting points used if not overridden later.
# ==============================================================
# Core Stats
var default_max_health: int = 100
var default_move_speed: float = 100.0
var default_acceleration: float = 500.0
var default_damping: float = 0.9
# Weapon
var default_weapon_id: String = ""
var default_attack_types: Dictionary = {}
# State Machine
var default_use_state_machine: bool = true
# Physics & Debug
var default_motion_mode: int = CharacterBody2D.MOTION_MODE_GROUNDED
var default_use_gravity: bool = true
var default_jump_force: float = 300.0
var default_debug_mode: bool = false
# Combat Behavior
var default_combat_movement_speed_multiplier: float = 1.0
var default_min_attack_state_duration: float = 0.1
# Avoidance
var default_use_avoidance: bool = true
var default_avoidance_strength: float = 150.0
var default_avoidance_ray_length: float = 75.0
var default_vertical_avoidance_factor: float = 0.6
# Bouncer Specific
var default_bouncer_bump_damage: int = 8
var default_bouncer_collision_damage_cooldown: float = 0.75
var default_bouncer_direction_change_cooldown: float = 0.3
var default_bouncer_stuck_threshold: float = 0.5

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


# --- Helper Function to Save Individual State Config ---
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
	print("--- Using Display Name: '%s' ---" % display_name)

	# ==============================================================
	# --- Determine Final Values for Current Enemy Run ---
	# Start with base defaults, then apply enemy-specific overrides
	# ==============================================================
	var max_health: int = default_max_health
	var move_speed: float = default_move_speed
	var acceleration: float = default_acceleration
	var damping: float = default_damping
	var weapon_id: String = default_weapon_id
	var attack_types: Dictionary = default_attack_types.duplicate(true) # Ensure deep copy
	var use_state_machine: bool = default_use_state_machine
	var motion_mode: int = default_motion_mode
	var use_gravity: bool = default_use_gravity
	var jump_force: float = default_jump_force
	var debug_mode: bool = default_debug_mode
	var combat_movement_speed_multiplier: float = default_combat_movement_speed_multiplier
	var min_attack_state_duration: float = default_min_attack_state_duration
	var use_avoidance: bool = default_use_avoidance
	var avoidance_strength: float = default_avoidance_strength
	var avoidance_ray_length: float = default_avoidance_ray_length
	var vertical_avoidance_factor: float = default_vertical_avoidance_factor
	# Bouncer specific defaults (only used if generating bouncer config)
	var bump_damage: int = default_bouncer_bump_damage
	var collision_damage_cooldown: float = default_bouncer_collision_damage_cooldown
	var direction_change_cooldown: float = default_bouncer_direction_change_cooldown
	var stuck_threshold: float = default_bouncer_stuck_threshold

	# --- Specific Enemy Overrides --- # <-- THIS LOGIC IS NOW INSIDE _run()
	if enemy_id == "bouncer_sm":
		print("Applying Bouncer specific overrides...")
		max_health = 75
		move_speed = 150.0
		acceleration = 600.0
		damping = 0.95
		weapon_id = ""
		attack_types = {}
		jump_force = 350.0
		combat_movement_speed_multiplier = 1.0
		min_attack_state_duration = 0.0
		use_avoidance = false
		debug_mode = false # Set true if needed for bouncer debugging

	elif enemy_id == "jumper_sm":
		print("Applying Jumper specific overrides...")
		max_health = 60
		move_speed = 100.0
		acceleration = 800.0
		damping = 0.9
		weapon_id = "melee_stomp"
		attack_types = { "melee": { "cooldown": 0.3, "range": 45.0, "damage": 15 } }
		jump_force = 400.0
		combat_movement_speed_multiplier = 0.7
		min_attack_state_duration = 0.15
		use_avoidance = true
		avoidance_strength = 150.0
		avoidance_ray_length = 75.0
		vertical_avoidance_factor = 0.6
		debug_mode = true

	# Add elif blocks for other specific enemies here...
	else:
		print("Using base default values for enemy: %s" % enemy_id)

	# ==============================================================
	# --- Determine State-Specific Default Dictionaries ---
	# These are populated based on the FINAL default values determined above.
	# ==============================================================
	var idle_defaults = {
		"wander_speed_multiplier": 0.4 * (move_speed / 100.0), # Scale wander speed with move_speed
		"wander_interval_min": 1.5,
		"wander_interval_max": 4.0,
	}
	var chase_defaults = { # Start with generic chase defaults
		"sight_range": 500.0,
		"preferred_attack_distance": 50.0,
		"preferred_distance_tolerance": 100.0,
		"chase_speed_multiplier": 1.2,
		"direct_chase": true,
		"chase_jump_chance": 0.0,
		"chase_jump_force": jump_force, # Use the final jump_force value
		"chase_jump_type": ChaseStateConfig.JumpType.VERTICAL,
		"aggression_level": 0.6,
	}
	var telegraph_defaults = {
		"telegraph_duration": 0.1,
		"telegraph_movement_type": "none",
	}
	var attack_defaults = {
		"attack_commitment": 0.15,
		"attack_retreat_distance": 0.0,
	}
	var repositioning_defaults = {
		"reposition_min_time": 1.0,
		"reposition_max_time": 1.5,
	}
	var stunned_defaults = {
		"stun_duration": 0.8,
	}
	var death_defaults = {}

	# --- Override state defaults for specific enemies ---
	if enemy_id == "jumper_sm":
		chase_defaults = {
			"sight_range": 450.0,
			"preferred_attack_distance": 40.0,
			"preferred_distance_tolerance": 20.0,
			"chase_speed_multiplier": 1.1,
			"direct_chase": true,
			"chase_jump_chance": 0.15,
			"chase_jump_force": jump_force, # Uses jumper's jump_force
			"chase_jump_type": ChaseStateConfig.JumpType.AIMED,
			"aggression_level": 0.7,
		}
		telegraph_defaults["telegraph_duration"] = 0.0 # Jumper specific override
		stunned_defaults["stun_duration"] = 0.6

	elif enemy_id == "bouncer_sm":
		# Bouncer chase config influences direction change/jump logic
		chase_defaults = {
			"sight_range": 500.0,
			"preferred_attack_distance": 50.0,
			"preferred_distance_tolerance": 100.0,
			"chase_speed_multiplier": 1.0, # Ignored by bouncer logic
			"direct_chase": true, # Affects logic
			"chase_jump_chance": 0.0, # Not used
			"chase_jump_force": jump_force, # Bouncer uses this
			"chase_jump_type": ChaseStateConfig.JumpType.VERTICAL,
			"aggression_level": 0.6, # Affects logic
		}
		# Bouncer doesn't use these states, but define defaults just in case
		telegraph_defaults["telegraph_duration"] = 0.0
		attack_defaults["attack_commitment"] = 0.0
		stunned_defaults["stun_duration"] = 0.8 # Bouncer specific override

	# Add elif blocks for other enemies' state default overrides...


	# --- 1. Load Required Classes ---
	# Checks are done using preloads at the top now
	if not EnemyConfig: 
		printerr("EnemyConfig script not loaded!"); 
		return
	if enemy_id == "bouncer_sm" and not BouncerConfig: 
		printerr("BouncerConfig script not loaded!"); 
		return

	var state_config_classes = {}
	for state_name in STATE_CONFIG_SCRIPT_PATHS:
		var script_path = STATE_CONFIG_SCRIPT_PATHS[state_name]
		var loaded_script = load(script_path)
		if not loaded_script: printerr("Failed to load StateConfig script: %s for state %s" % [script_path, state_name]); continue
		state_config_classes[state_name] = loaded_script
	print("Loaded %d state config classes." % state_config_classes.size())

	# --- 2. Determine and Create Enemy-Specific Directory ---
	var parent_config_dir = PARENT_CONFIG_DIR_SM
	var enemy_config_dir = parent_config_dir.path_join(enemy_id)

	var dir_access = DirAccess.open("res://")
	if not dir_access: printerr("Failed to access res://"); return
	if not dir_access.dir_exists(enemy_config_dir.replace("res://", "")):
		var err_mk = dir_access.make_dir_recursive(enemy_config_dir.replace("res://", ""))
		if err_mk != OK: printerr("Failed to create enemy config directory: %s, error code: %d" % [enemy_config_dir, err_mk]); return
		else: print("Created directory: %s" % enemy_config_dir)

	# --- 3. Create Main Config Instance (Conditional) ---
	var main_config: EnemyConfig = null # Base type hint

	if enemy_id == "bouncer_sm":
		if BouncerConfig:
			main_config = BouncerConfig.new()
			print("Instantiated BouncerConfig for bouncer_sm.")
		else:
			printerr("BouncerConfig script not loaded! Falling back to EnemyConfig.")
			main_config = EnemyConfig.new() # Fallback
	else:
		main_config = EnemyConfig.new()
		print("Instantiated standard EnemyConfig for %s." % enemy_id)

	if not is_instance_valid(main_config): printerr("FATAL: Failed to create any main_config instance!"); return

	# --- 4. Set GLOBAL Properties on Main Config ---
	# Use the final determined values from the top override logic
	main_config.enemy_id = enemy_id
	main_config.display_name = display_name
	main_config.max_health = max_health
	main_config.move_speed = move_speed
	main_config.acceleration = acceleration
	main_config.damping = damping
	main_config.weapon_id = weapon_id
	main_config.attack_types = attack_types.duplicate(true)
	main_config.use_state_machine = use_state_machine
	main_config.motion_mode = motion_mode
	main_config.use_gravity = use_gravity
	main_config.jump_force = jump_force
	main_config.debug_mode = debug_mode
	main_config.combat_movement_speed_multiplier = combat_movement_speed_multiplier
	main_config.min_attack_state_duration = min_attack_state_duration
	main_config.use_avoidance = use_avoidance
	main_config.avoidance_strength = avoidance_strength
	main_config.avoidance_ray_length = avoidance_ray_length
	main_config.vertical_avoidance_factor = vertical_avoidance_factor

	# --- Set Bouncer-Specific Properties (Only if it's a BouncerConfig) ---
	if main_config is BouncerConfig:
		var bouncer_cfg := main_config as BouncerConfig
		bouncer_cfg.bump_damage = bump_damage
		bouncer_cfg.collision_damage_cooldown = collision_damage_cooldown
		bouncer_cfg.direction_change_cooldown = direction_change_cooldown
		bouncer_cfg.stuck_threshold = stuck_threshold
		print("Applied Bouncer-specific config properties.")

	print("Set ALL applicable global parameters on main config.")

	# --- 5. Create, Populate, Save, and Link STATE Config Resources ---
	if use_state_machine:
		print("Generating State Config Resources into: %s" % enemy_config_dir)

		var relevant_states = []
		if enemy_id == "bouncer_sm":
			relevant_states = ["Idle", "Chase", "Stunned", "Death"]
		elif enemy_id == "jumper_sm":
			relevant_states = ["Idle", "Chase", "Telegraph", "Attack", "Stunned", "Death"]
		else: # Default set
			relevant_states = ["Idle", "Chase", "Telegraph", "Attack", "Repositioning", "Stunned", "Death"]

		print("Generating config for states: %s" % str(relevant_states))

		var state_defaults_map = {
			"Idle": idle_defaults, "Chase": chase_defaults,
			"Telegraph": telegraph_defaults, "Attack": attack_defaults,
			"Repositioning": repositioning_defaults, "Stunned": stunned_defaults,
			"Death": death_defaults
		}

		for state_name in relevant_states:
			if not state_config_classes.has(state_name):
				printerr("Missing StateConfig class definition for required state: %s" % state_name)
				continue

			var StateConfigClass = state_config_classes[state_name]
			var state_config_instance = StateConfigClass.new()

			if not state_defaults_map.has(state_name):
				push_warning("No defaults dictionary defined for state: %s" % state_name)
				continue

			var defaults = state_defaults_map[state_name]
			for param_name in defaults:
				if param_name in state_config_instance:
					state_config_instance.set(param_name, defaults[param_name])
				else:
					pass # Silently ignore if default exists but export doesn't (less noise)

			var saved_state_config_path = save_state_config(state_name, state_config_instance, enemy_config_dir)
			if not saved_state_config_path.is_empty():
				var loaded_state_config = load(saved_state_config_path)
				if is_instance_valid(loaded_state_config):
					var config_var_name = state_name.to_lower() + "_config"
					if config_var_name in main_config:
						main_config.set(config_var_name, loaded_state_config)
					else:
						printerr("Main EnemyConfig (or subclass '%s') missing export var '%s' for state link." % [main_config.get_class(), config_var_name])
				else:
					printerr("Failed to load back saved state config: %s" % saved_state_config_path)

	# --- 6. Save the MAIN Config Resource ---
	var main_file_path = enemy_config_dir.path_join("config.tres")
	var err_save_main = ResourceSaver.save(main_config, main_file_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err_save_main == OK:
		print("Successfully generated and saved MAIN config: %s" % main_file_path)
	else:
		printerr("Failed to save MAIN config resource %s, error code: %d" % [main_file_path, err_save_main])

	# --- 7. Filesystem Refresh ---
	if Engine.is_editor_hint():
		var editor_fs = EditorInterface.get_resource_filesystem()
		if editor_fs:
			editor_fs.scan()
			print("Editor filesystem scan requested.")
		else:
			printerr("Could not get Editor Filesystem Interface.")

	print("--- Enemy Config Generation Finished ---")
