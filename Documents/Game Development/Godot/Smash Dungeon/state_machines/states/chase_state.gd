# state_machines/states/chase_state.gd
class_name ChaseState
extends State

# Local variables to store configuration values for this state instance
var sight_range: float = 600.0 # Default value if not in config
var preferred_attack_distance: float = 150.0 # Default value if not in config
var preferred_distance_tolerance: float = 50.0 # Default value if not in config
var chase_speed_multiplier: float = 1.2 # Default value if not in config
var direct_chase: bool = false # Default value if not in config
var chase_jump_chance: float = 0.0 # Default value if not in config
var chase_jump_force: float = 300.0 # Default value if not in config
var aggression_level: float = 0.5 # Default value if not in config

func enter():
	# Load configuration parameters when entering the state
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.config):
		printerr("%s: ChaseState cannot access enemy or enemy.config." % get_path())
		# Use the hardcoded defaults defined above
		return

	if enemy.config.states_config.has("ChaseState"):
		var chase_config = enemy.config.states_config["ChaseState"]

		# Use .get() to safely retrieve values, falling back to defaults if key is missing
		# Note: Using self. prefix explicitly to assign to the state's variables
		self.sight_range = chase_config.get("sight_range", sight_range)
		self.preferred_attack_distance = chase_config.get("preferred_attack_distance", preferred_attack_distance)
		self.preferred_distance_tolerance = chase_config.get("preferred_distance_tolerance", preferred_distance_tolerance)
		self.chase_speed_multiplier = chase_config.get("chase_speed_multiplier", chase_speed_multiplier)
		self.direct_chase = chase_config.get("direct_chase", direct_chase)
		self.chase_jump_chance = chase_config.get("chase_jump_chance", chase_jump_chance)
		self.chase_jump_force = chase_config.get("chase_jump_force", chase_jump_force)
		self.aggression_level = chase_config.get("aggression_level", aggression_level)

		if state_machine.debug_mode:
			print("%s: ChaseState loaded config - aggression: %.2f, speed_mult: %.2f, tolerance: %.1f" % [enemy.name, aggression_level, chase_speed_multiplier, preferred_distance_tolerance])
	else:
		if state_machine.debug_mode:
			print("%s: ChaseState using default parameters (no config found)." % enemy.name)
		# Use the hardcoded defaults defined above if no "ChaseState" config exists

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
	var current_preferred_attack_distance = self.preferred_attack_distance # Use state's value
	var current_preferred_distance_tolerance = self.preferred_distance_tolerance # Use state's value
	var current_aggression_level = self.aggression_level # Use state's value
	var current_chase_speed_multiplier = self.chase_speed_multiplier # Use state's value
	var current_direct_chase = self.direct_chase # Use state's value
	var current_chase_jump_chance = self.chase_jump_chance # Use state's value
	var current_chase_jump_force = self.chase_jump_force # Use state's value
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
	var attack_range = current_preferred_attack_distance # Base range on state's value

	# Prioritize weapon system for checks if available
	if enemy.weapon_system and is_instance_valid(enemy._target_node):
		attack_range = enemy.weapon_system.get_attack_range()
		if distance <= attack_range and enemy.check_line_of_sight() and enemy.weapon_system.can_attack():
			can_initiate_attack = true
	# Fallback to legacy attack_types if no weapon system or if it didn't meet criteria
	elif "attack_types" in enemy and not can_initiate_attack:
		for attack_type in enemy.attack_types:
			var attack_config = enemy.attack_types[attack_type]
			attack_range = attack_config.get("range", 50.0)
			# Use loaded aggression level for effective range calc
			var effective_attack_range = attack_range * (1.0 + current_aggression_level * 0.3)

			if distance <= effective_attack_range and enemy.check_line_of_sight():
				if enemy.has_method("can_use_attack") and enemy.can_use_attack(attack_type):
					can_initiate_attack = true
					break

	# If conditions are met, transition to TelegraphState
	if can_initiate_attack:
		if state_machine.debug_mode:
			print("%s: ChaseState initiating attack sequence -> TelegraphState" % enemy.name)
		change_state("TelegraphState")
		return

	# --- Target Lost Check ---
	# Use loaded sight range value
	if distance > self.sight_range * 1.1: # Add some buffer
		if state_machine.debug_mode: print("%s: Target lost (out of sight range)" % enemy.name)
		change_state("IdleState")
		return
