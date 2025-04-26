# state_machines/states/attack_state.gd
class_name AttackState
extends State

# Configuration parameters (can be accessed via enemy.config or specific state config)
var attack_commitment: float = 0.5
# var post_attack_pause: float = 0.0 # Less relevant with immediate transition
var attack_retreat_distance: float = 0.0 # Still potentially useful for transition logic
var combat_movement_speed_multiplier: float = 0.5
# var min_attack_state_duration: float = 0.0 # Attack now triggered differently

func enter():
	if DEBUG: print("AttackState Entered")
	# Default behavior: Try to attack immediately upon entering
	_try_attack_and_transition()

func physics_process(delta):
	# --- Movement Logic during Attack State ---
	# This logic runs *while* the attack is happening (e.g., during animation/hitbox duration)
	# It no longer triggers the attack itself.
	if not is_instance_valid(enemy._target_node):
		enemy.target_velocity = Vector2.ZERO
		# Consider if an early transition is needed if target is lost mid-attack animation
		# For now, let the planned transition handle it.
		return

	# Only apply combat movement if an attack is logically "in progress"
	# This might need refinement depending on how long attacks take visually.
	# If attacks are instant, movement might only happen *before* the enter() call.
	# If attacks have duration (hitbox active), movement here makes sense.

	var direction_to_target = (enemy._target_node.global_position - enemy.global_position).normalized()
	var distance = enemy.global_position.distance_to(enemy._target_node.global_position)

	# Apply config: Get specific speed multiplier from state config or fallback
	var speed_multiplier = combat_movement_speed_multiplier # Default
	if enemy and enemy.config and enemy.config.states_config.has("AttackState") \
	and enemy.config.states_config["AttackState"].has("combat_movement_speed_multiplier"):
		speed_multiplier = enemy.config.states_config["AttackState"].combat_movement_speed_multiplier

	var effective_speed = enemy.move_speed * speed_multiplier

	# Apply config: Get aggression level from state config or fallback
	var aggression = 0.5 # Default aggression
	if enemy and enemy.config and enemy.config.states_config.has("AttackState") \
	and enemy.config.states_config["AttackState"].has("aggression_level"):
		aggression = enemy.config.states_config["AttackState"].aggression_level
	elif enemy and "aggression_level" in enemy: # Fallback to base enemy property
		aggression = enemy.aggression_level


	# Simplified movement options based on aggression
	if aggression > 0.6: # High aggression: move towards
		enemy.target_velocity = direction_to_target * effective_speed
	elif aggression > 0.2: # Medium aggression: strafe/hold position
		var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x) * (1.0 if randf() > 0.5 else -1.0)
		enemy.target_velocity = (strafe_dir * 0.8 + direction_to_target * 0.2).normalized() * effective_speed * 0.8
	else: # Low aggression: back off slightly if too close
		if distance < enemy.preferred_attack_distance * 0.8:
			enemy.target_velocity = -direction_to_target * effective_speed * 0.7
		else:
			enemy.target_velocity = Vector2.ZERO # Or slow strafe


# --- Protected Helper Functions ---
# These are now defined in the base class for derived states to call.
# Add underscore prefix convention for protected methods.

# Encapsulates the whole process for default entry or specific triggers (like telegraph end)
func _try_attack_and_transition():
	if _check_attack_conditions():
		_execute_attack()
		# Transition happens AFTER attack execution attempt
	# else: # Condition check failed, already transitioned in _check_attack_conditions
		# pass

	# Ensure transition always happens if conditions were met or not
	_transition_after_attack()


# Checks if attacking is possible right now
func _check_attack_conditions() -> bool:
	if not is_instance_valid(enemy._target_node):
		if DEBUG: print("Attack check failed: Invalid target.")
		# Transition handled by caller using _transition_after_attack
		return false

	if not enemy.can_attack:
		if DEBUG: print("Attack check failed: Enemy cannot attack (cooldown?).")
		# Transition handled by caller using _transition_after_attack
		return false

	# --- Optional: Add basic LOS/Range checks here if base attack needs them ---
	# var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
	# var max_range = enemy.preferred_attack_distance + enemy.preferred_distance_tolerance
	# if distance > max_range:
	#	 if DEBUG: print("Attack check failed: Target out of range (%s > %s)." % [distance, max_range])
	#	 return false # Let caller handle transition
	#
	# if not enemy.has_line_of_sight(): # Assuming this method exists on BaseEnemySM
	#	 if DEBUG: print("Attack check failed: No line of sight.")
	#	 return false # Let caller handle transition
	# --- End Optional Checks ---

	if DEBUG: print("Attack check passed.")
	return true

# Performs the actual attack via weapon system
func _execute_attack() -> bool: # Return success status
	if DEBUG: print("AttackState: _execute_attack()")
	var attack_success = false
	if enemy.weapon_system:
		attack_success = enemy.weapon_system.perform_attack()
		if attack_success:
			enemy.can_attack = false
			if DEBUG: print("AttackState: Attack initiated, enemy.can_attack set to false.")
		# else: # weapon_system.perform_attack already handles logging failure
		#	 if DEBUG: print("AttackState: weapon_system.perform_attack() returned false.")
	# else:
		# if DEBUG: print("AttackState: No weapon system found.")
		# Handle fallback to legacy system if needed

	return attack_success

# Determines the next state after an attack attempt
func _transition_after_attack():
	# Apply config: Get retreat distance from state config or fallback
	var retreat_dist = 0.0
	if enemy and enemy.config and enemy.config.states_config.has("AttackState") \
	and enemy.config.states_config["AttackState"].has("attack_retreat_distance"):
		retreat_dist = enemy.config.states_config["AttackState"]["attack_retreat_distance"]
	elif enemy and "attack_retreat_distance" in enemy: # Fallback to base enemy property
		retreat_dist = enemy.attack_retreat_distance

	if retreat_dist > 0.0 and is_instance_valid(enemy._target_node):
		# Handle retreat if configured
		var retreat_dir = (enemy.global_position - enemy._target_node.global_position).normalized()
		enemy.reposition_direction = retreat_dir # Assuming BaseEnemySM handles this variable
		if DEBUG: print("AttackState: Transitioning to RepositioningState (Retreat)")
		change_state("RepositioningState")
	else:
		# Default: Go back to chasing
		if DEBUG: print("AttackState: Transitioning to ChaseState")
		change_state("ChaseState")

# --- Message Handling ---
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# Apply config: Get commitment from state config or fallback
			var commit = 0.5
			if enemy and enemy.config and enemy.config.states_config.has("AttackState") \
			and enemy.config.states_config["AttackState"].has("attack_commitment"):
				commit = enemy.config.states_config["AttackState"]["attack_commitment"]
			elif enemy and "attack_commitment" in enemy:
				commit = enemy.attack_commitment

			var interrupt_chance = 0.3 * (1.0 - commit) # Less chance if high commitment
			if randf() < interrupt_chance:
				if DEBUG: print("AttackState interrupted by damage, repositioning.")
				# Ensure we are not already transitioning
				if state_machine.current_state == self:
					change_state("RepositioningState")
