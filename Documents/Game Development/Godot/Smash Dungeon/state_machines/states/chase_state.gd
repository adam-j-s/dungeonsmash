# state_machines/states/chase_state.gd
class_name ChaseState
extends State

# Local variables to store configuration values for this state instance
var sight_range: float = 600.0
var preferred_attack_distance: float = 150.0
var preferred_distance_tolerance: float = 50.0
var chase_speed_multiplier: float = 1.2
var direct_chase: bool = false
var chase_jump_chance: float = 0.0
var chase_jump_force: float = 300.0
var aggression_level: float = 0.5

func enter():
	# Attempt to load configuration from the specific ChaseStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.chase_config):
		# Explicitly type hint for clarity (optional but good)
		var cfg: ChaseStateConfig = enemy.config.chase_config

		# Load values directly from the config resource's properties
		self.sight_range = cfg.sight_range
		self.preferred_attack_distance = cfg.preferred_attack_distance
		self.preferred_distance_tolerance = cfg.preferred_distance_tolerance
		self.chase_speed_multiplier = cfg.chase_speed_multiplier
		self.direct_chase = cfg.direct_chase
		self.chase_jump_chance = cfg.chase_jump_chance
		self.chase_jump_force = cfg.chase_jump_force
		self.aggression_level = cfg.aggression_level
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: ChaseState loaded config - aggression: %.2f, speed_mult: %.2f, tolerance: %.1f" % [enemy.name, aggression_level, chase_speed_multiplier, preferred_distance_tolerance])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: ChaseState could not find valid chase_config resource. Using default values." % get_path())
		# Defaults are already set in the variable declarations above


# physics_process remains the same as it already uses the state's local variables
# In ChaseState.gd

# physics_process remains the same as it already uses the state's local variables
func physics_process(delta):
	# Ensure enemy and target are valid
	if not is_instance_valid(enemy) or not is_instance_valid(enemy._target_node):
		change_state("IdleState")
		return

	# Get target position and calculate distance/direction
	var target_pos = enemy._target_node.global_position
	var vector_to_target = target_pos - enemy.global_position
	var distance = vector_to_target.length()
	var direction_to_target = vector_to_target.normalized()

	# --- Use the state's loaded config variables ---
	var current_preferred_attack_distance = self.preferred_attack_distance
	var current_preferred_distance_tolerance = self.preferred_distance_tolerance
	var current_aggression_level = self.aggression_level
	var current_chase_speed_multiplier = self.chase_speed_multiplier
	var current_direct_chase = self.direct_chase
	var current_chase_jump_chance = self.chase_jump_chance
	var current_chase_jump_force = self.chase_jump_force
	# --------------------------------------------

	# Calculate preferred distance difference
	var preferred_distance_diff = distance - current_preferred_attack_distance
	var move_strength = 1.0

	# Modulate movement strength based on proximity to preferred distance
	if abs(preferred_distance_diff) < current_preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / current_preferred_distance_tolerance

	# --- Movement Logic ---
	# Determine movement strategy using the loaded config values
	if current_direct_chase or abs(preferred_distance_diff) > current_preferred_distance_tolerance * (2.0 - current_aggression_level):
		# Direct approach or retreat
		if preferred_distance_diff > 0: # Too far
			var approach_speed = enemy.move_speed * current_chase_speed_multiplier * (1.0 + current_aggression_level * 0.5)
			enemy.target_velocity = direction_to_target * approach_speed
		else: # Too close
			var retreat_factor = max(0.2, 1.0 - current_aggression_level * 0.8)
			enemy.target_velocity = -direction_to_target * enemy.move_speed * 0.8 * retreat_factor
	else:
		# Orbital movement near preferred distance
		var orbit_factor = max(0.2, 1.0 - current_aggression_level * 0.7)
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x).normalized()
		if randf() < 0.01: orbit_dir *= -1
		enemy.target_velocity = orbit_dir * enemy.move_speed * 0.5 * move_strength * orbit_factor

	# --- Jumping Logic ---
	# Use loaded config value
	if enemy.is_on_floor() and randf() < current_chase_jump_chance * delta:
		enemy.velocity.y = -current_chase_jump_force

	# --- Attack Transition Check ---
	var can_initiate_attack = false
	var attack_check_range = current_preferred_attack_distance # Default range check, might be overridden by weapon

	# Prioritize weapon system for checks if available
	if enemy.weapon_system and is_instance_valid(enemy._target_node):
		# --- ADD DETAILED PRINTS HERE ---
		attack_check_range = enemy.weapon_system.get_attack_range() # Get actual range for check
		var ws_can_attack = enemy.weapon_system.can_attack()
		var has_los = enemy.check_line_of_sight()
		# Print every frame to see values change
		#if state_machine and state_machine.debug_mode: # Only print if debug enabled
		#print("Chase Check WS: Dist=%.1f, Range=%.1f, LOS=%s, WeaponReady=%s" % [distance, attack_check_range, has_los, ws_can_attack])
		# --- END DETAILED PRINTS ---

		# Check conditions using fetched values
		if distance <= attack_check_range and has_los and ws_can_attack:
			can_initiate_attack = true
			#if state_machine.debug_mode: print(">>> Chase Check WS: Attack Conditions MET <<<") # Confirmation

	# Fallback to legacy attack_types if weapon system didn't trigger attack
	elif "attack_types" in enemy and not can_initiate_attack:
		#if state_machine.debug_mode: print("Chase Check: Checking legacy attack_types...") # Indicate fallback
		for attack_type in enemy.attack_types:
			var attack_config = enemy.attack_types[attack_type]
			attack_check_range = attack_config.get("range", 50.0)
			var effective_attack_range = attack_check_range * (1.0 + current_aggression_level * 0.3)
			var legacy_has_los = enemy.check_line_of_sight() # Re-check LOS for this range
			var legacy_can_use = enemy.has_method("can_use_attack") and enemy.can_use_attack(attack_type)

			if state_machine.debug_mode: # Only print if debug enabled
					print("  Legacy Check '%s': Dist=%.1f, EffRange=%.1f, LOS=%s, CooldownOK=%s" % [attack_type, distance, effective_attack_range, legacy_has_los, legacy_can_use])

			if distance <= effective_attack_range and legacy_has_los and legacy_can_use:
				can_initiate_attack = true
				if state_machine.debug_mode: print(">>> Chase Check Legacy: Attack Conditions MET for '%s' <<<" % attack_type)
				break # Found a usable legacy attack

	# If conditions were met by either system, transition to TelegraphState
	if can_initiate_attack:
		if state_machine.debug_mode:
			print("%s: ChaseState initiating attack sequence -> TelegraphState" % enemy.name)
		change_state("TelegraphState")
		return # Exit physics process after changing state

	# --- Target Lost Check ---
	# Use loaded sight range value
	#if distance > self.sight_range * 1.1: # Add some buffer
		#if state_machine.debug_mode: print("%s: Target lost (out of sight range)" % enemy.name)
		#change_state("IdleState")
		#return

# handle_message is optional for ChaseState unless it needs to react to something specific
# func handle_message(msg, data=null):
#     pass
