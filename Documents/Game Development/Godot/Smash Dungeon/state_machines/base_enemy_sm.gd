# state_machines/base_enemy_sm.gd
class_name BaseEnemySM
extends BaseEnemy  # Extend the existing BaseEnemy class

# State machine reference - the only new property we need
@onready var state_machine = $StateMachine

# In BaseEnemySM.gd

func _ready():
	# Call parent _ready first to ensure BaseEnemy initialization happens
	super()

	# Set debug mode on the state machine if the enemy has debug_mode set
	# Check if config exists first, as _ready runs before config might be assigned by manager
	if is_instance_valid(state_machine): # Check if state_machine node itself is ready
		var debug_value_to_set = false # Default to false

		# Prioritize the value from the loaded config resource
		if config != null and "debug_mode" in config:
			debug_value_to_set = config.debug_mode
			print(">>> BaseEnemySM._ready(): Setting SM debug from CONFIG: ", debug_value_to_set)
		# Fallback to the direct property on this BaseEnemySM script/node if config not loaded yet
		elif "debug_mode" in self:
			debug_value_to_set = self.debug_mode
			print(">>> BaseEnemySM._ready(): Setting SM debug from SELF PROPERTY (fallback): ", debug_value_to_set)
		else:
			print(">>> BaseEnemySM._ready(): Cannot find debug_mode in config or self. Using default false.")
			# debug_value_to_set remains false

		# Set the value on the StateMachine node
		state_machine.debug_mode = debug_value_to_set

		# --- ADDED PRINT TO CONFIRM ---
		#print(">>> BaseEnemySM._ready(): state_machine.debug_mode IS NOW: ", state_machine.debug_mode)
		# -----------------------------

	#else:
		#printerr(">>> BaseEnemySM._ready(): StateMachine node not ready or invalid!")


# Override _physics_process to delegate to the state machine
# NOTE: The original physics logic from BaseEnemy is largely superseded
# by the logic within the individual State scripts. BaseEnemySM's physics_process
# primarily ensures the active state's physics_process is called and applies base movement.
func _physics_process(delta):
	# Skip if defeated (using the _is_defeated flag from BaseEnemy)
	if _is_defeated:
		# Ensure velocity is zeroed if defeated
		target_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		# Optionally disable physics processing entirely after a delay?
		return

	# Let the current state handle its physics logic (like setting target_velocity)
	if state_machine and state_machine.current_state:
		state_machine.current_state.physics_process(delta)

	# --- Apply Base Movement Physics (Copied from BaseEnemy) ---
	# This part remains crucial for applying movement based on the target_velocity
	# set by the current state, handling gravity, avoidance, and move_and_slide.

	# Update cooldowns for attacks (directly from BaseEnemy - still needed)
	# This should ideally be done once, either here or in BaseEnemy's process
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta

	# Calculate avoidance force if enabled
	var avoidance_vector = Vector2.ZERO
	# Check if 'use_avoidance' exists and is true (might be from BaseEnemy or config)
	var should_use_avoidance = use_avoidance # Default to BaseEnemy's value
	if config and "use_avoidance" in config: # Prefer config value if available
		should_use_avoidance = config.use_avoidance
	if should_use_avoidance:
		avoidance_vector = calculate_avoidance() # Assumes calculate_avoidance() exists in BaseEnemy

	# Apply gravity if not floating and gravity is enabled
	var should_use_gravity = use_gravity # Default to BaseEnemy's value
	if config and "use_gravity" in config: # Prefer config value
		should_use_gravity = config.use_gravity
	var current_motion_mode = motion_mode # Default to BaseEnemy's value
	if config and "motion_mode" in config: # Prefer config value
		current_motion_mode = config.motion_mode

	if not is_on_floor() and current_motion_mode != MOTION_MODE_FLOATING and should_use_gravity:
		velocity.y += gravity * delta

	# Calculate final velocity with dampening and acceleration
	# Ensure damping and acceleration are valid values
	var current_damping = damping # Use BaseEnemy default
	if config and "damping" in config: current_damping = config.damping
	var current_acceleration = acceleration # Use BaseEnemy default
	if config and "acceleration" in config: current_acceleration = config.acceleration
	var current_move_speed = move_speed # Use BaseEnemy default
	if config and "move_speed" in config: current_move_speed = config.move_speed

	# Prevent division by zero or negative values if config is bad
	current_damping = max(0.01, current_damping)
	current_acceleration = max(0.1, current_acceleration)
	current_move_speed = max(0.0, current_move_speed)


	# Apply damping (ensure delta is positive) - Apply to both components first
	if delta > 0:
		# Ensure damping factor is not too extreme (prevents velocity becoming NaN or infinite)
		var damping_factor = clamp(pow(current_damping, delta * 60.0), 0.0, 1.0)
		velocity *= damping_factor

	# --- Horizontal Velocity Update ---
	# Calculate target horizontal velocity (including avoidance)
	# Note: target_velocity.x is set by the current state
	var combined_target_velocity_x = target_velocity.x + avoidance_vector.x

	# Calculate max horizontal velocity change based on acceleration
	# Acceleration determines how quickly we reach the target speed
	var max_horizontal_delta = current_acceleration * delta # How much speed can change this frame
	if state_machine and state_machine.debug_mode: print("BaseEnemySM: TargetVel.x=%.1f, Avoid.x=%.1f, CombinedTarget.x=%.1f, MaxDelta=%.2f, CurrentVel.x=%.1f" % [target_velocity.x, avoidance_vector.x, combined_target_velocity_x, max_horizontal_delta, velocity.x])
	# Move horizontal velocity towards target horizontal velocity
	velocity.x = move_toward(velocity.x, combined_target_velocity_x, max_horizontal_delta)
	if state_machine and state_machine.debug_mode: print("BaseEnemySM: Final velocity.x = ", velocity.x)
	# --- Vertical Velocity ---
	# Vertical velocity (velocity.y) has already been affected by:
	# 1. Gravity (applied earlier in this function)
	# 2. Jump impulse (applied directly to velocity.y in ChaseState)
	# 3. Damping (applied above)
	# We DO NOT use move_toward for velocity.y here, letting gravity/jumps dominate.
	# Optional: Apply vertical avoidance directly if needed
	# velocity.y += avoidance_vector.y * delta # Simple way, might need refinement

	# Apply movement using the calculated velocity
	move_and_slide()

	# Update weapon position if we have a weapon system
	if weapon_system:
		weapon_system.update_position()


# --- configure_states function is now REMOVED ---


# configure_weapon_system might still be useful if called externally
# or if BaseEnemy doesn't handle it sufficiently in _ready
func configure_weapon_system():
	if weapon_system and weapon_id != "":
		weapon_system.initialize(self, weapon_id)
		if weapon_system.has_signal("cooldown_complete") and not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
			weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)
		if weapon_system.weapon and "can_attack" in weapon_system.weapon:
			can_attack = weapon_system.weapon.can_attack
		return true
	return false

# _on_weapon_cooldown_complete remains necessary
func _on_weapon_cooldown_complete():
	can_attack = true
	if weapon_system and weapon_system.weapon and "can_attack" in weapon_system.weapon:
		weapon_system.weapon.can_attack = true

# Override take_damage to notify state machine - This is CORRECT
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	#print("--- BaseEnemySM take_damage ENTERED ---")
	#print("!!! take_damage CALLED on ", name, " with amount: ", amount, ", knockback: ", knockback_strength)
	super(amount, hit_direction, knockback_strength) # Call BaseEnemy's take_damage first
	#print("--- BaseEnemySM take_damage AFTER SUPER ---")
	if state_machine and not _is_defeated: # Only notify if not already defeated
		state_machine.send_message("damaged", {
			"amount": amount,
			"direction": hit_direction,
			"knockback": knockback_strength
		})

# Override die to use state machine - This is CORRECT
func die():
	if _is_defeated: return # Prevent multiple calls

	# Let BaseEnemy handle basic death flags and signal first
	# This ensures health is 0, _is_defeated is true, and base signal fires
	super()

	# Now, change state if state machine is active
	if state_machine and state_machine.states.has("DeathState"):
		# Check if we are already in DeathState to prevent re-entry issues
		if not state_machine.current_state is DeathState:
			state_machine.change_state("DeathState")
			# Note: DeathState's enter() calls play_death_effects() from BaseEnemy
	else:
		# If no state machine or DeathState, BaseEnemy.die() already
		# called play_death_effects(), so nothing more needed here.
		pass


# Compatibility method - This is useful
func get_current_state_name():
	if state_machine and state_machine.current_state_name:
		return state_machine.current_state_name
	# Fallback to BaseEnemy's enum state if needed for compatibility
	# return AIState.keys()[current_ai_state]
	return "IDLE" # Simpler fallback


# Helper method to bridge existing code - Keep this for compatibility if needed
func change_ai_state(new_state_enum_value):
	# This method is primarily for EXTERNAL code that might still use the old enum system
	# The state machine itself uses change_state("StateName")
	var state_map = {
		AIState.IDLE: "IdleState",
		AIState.CHASING: "ChaseState",
		AIState.ATTACKING: "AttackState", # Might map AttackState or TelegraphState depending on intent
		AIState.REPOSITIONING: "RepositioningState",
		AIState.FLEEING: "FleeState", # Assuming FleeState exists
		AIState.STUNNED: "StunnedState"
	}
	if state_machine and new_state_enum_value in state_map:
		var state_name = state_map[new_state_enum_value]
		if state_machine.states.has(state_name):
			state_machine.change_state(state_name)


# --- Keep Telegraph Helpers if defined here ---
func _show_telegraph_visual(active: bool, _duration: float = 0.0):
	if active: modulate = Color(1.0, 0.7, 0.7, 1.0)
	else: modulate = Color(1.0, 1.0, 1.0, 1.0)

func _execute_default_movement(_delta):
	target_velocity.x = 0

func set_reposition_direction(direction: Vector2):
	reposition_direction = direction
# ----------------------------------------------
