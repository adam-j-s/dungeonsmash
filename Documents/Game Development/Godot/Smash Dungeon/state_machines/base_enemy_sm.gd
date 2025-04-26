# state_machines/base_enemy_sm.gd
class_name BaseEnemySM
extends BaseEnemy  # Extend the existing BaseEnemy class

# State machine reference - the only new property we need
@onready var state_machine = $StateMachine

func _ready():
	# Call parent _ready first to ensure BaseEnemy initialization happens
	super()
	
	# Then configure the state machine after BaseEnemy initialization is complete
	if state_machine:
		configure_states()

# Override _physics_process to replace the enum state handling
func _physics_process(delta):
	# Skip if defeated
	if _is_defeated:
		return

	# Update cooldowns for attacks (directly from BaseEnemy)
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta

	# The rest of the physics processing stays the same as BaseEnemy
	var avoidance_vector = Vector2.ZERO
	if use_avoidance:
		avoidance_vector = calculate_avoidance()

	if not is_on_floor() and motion_mode != MOTION_MODE_FLOATING and use_gravity:
		velocity.y += gravity * delta

	velocity *= pow(damping, delta * 60.0)
	var combined_target_velocity = target_velocity + avoidance_vector
	var max_delta_velocity = acceleration * move_speed * delta
	velocity = velocity.move_toward(combined_target_velocity, max_delta_velocity)

	move_and_slide()
	
	if weapon_system:
		weapon_system.update_position()

# Configure state machine states with parameters from this enemy
func configure_states():
	# Make sure we have a state machine
	if not state_machine:
		push_error("No StateMachine found in enemy: " + name)
		return
	
	# Set debug mode on state machine
	state_machine.debug_mode = debug_mode
	
	# Configure idle state
	var idle_state = state_machine.states.get("IdleState")
	if idle_state:
		idle_state.wander_speed_multiplier = wander_speed_multiplier
		idle_state.wander_interval_min = wander_interval_min
		idle_state.wander_interval_max = wander_interval_max
	
	# Configure chase state
	var chase_state = state_machine.states.get("ChaseState")
	if chase_state:
		chase_state.sight_range = sight_range
		chase_state.preferred_attack_distance = preferred_attack_distance
		chase_state.preferred_distance_tolerance = preferred_distance_tolerance
		chase_state.chase_speed_multiplier = chase_speed_multiplier
		chase_state.direct_chase = direct_chase
		chase_state.chase_jump_chance = chase_jump_chance
		chase_state.chase_jump_force = chase_jump_force
		chase_state.aggression_level = aggression_level
	
	# Configure attack state
	var attack_state = state_machine.states.get("AttackState")
	if attack_state:
		attack_state.attack_commitment = attack_commitment
		attack_state.post_attack_pause = post_attack_pause
		attack_state.attack_retreat_distance = attack_retreat_distance
		attack_state.combat_movement_speed_multiplier = combat_movement_speed_multiplier
		attack_state.min_attack_state_duration = min_attack_state_duration
	
	# Configure repositioning state
	var reposition_state = state_machine.states.get("RepositioningState")
	if reposition_state:
		reposition_state.reposition_min_time = reposition_min_time
		reposition_state.reposition_max_time = reposition_max_time
		reposition_state.reposition_chance = reposition_chance

func configure_weapon_system():
	# Make sure the weapon system is properly set up
	if weapon_system and weapon_id != "":
		# Initialize the weapon
		weapon_system.initialize(self, weapon_id)
		
		# Connect the cooldown signal if needed
		if weapon_system.has_signal("cooldown_complete") and not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
			weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)
			
		# Check if we can directly sync the can_attack states
		if weapon_system.weapon and "can_attack" in weapon_system.weapon:
			can_attack = weapon_system.weapon.can_attack
			
		return true
	
	return false

func _on_weapon_cooldown_complete():
	can_attack = true
	
	# Also update the weapon's state if needed
	if weapon_system and weapon_system.weapon and "can_attack" in weapon_system.weapon:
		weapon_system.weapon.can_attack = true

# Override take_damage to notify state machine
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Call the parent implementation first
	super(amount, hit_direction, knockback_strength)
	
	# Then notify the state machine
	if state_machine:
		state_machine.send_message("damaged", {
			"amount": amount,
			"direction": hit_direction,
			"knockback": knockback_strength
		})

# Override die to use state machine
func die():
	# Set variables
	current_health = 0
	_is_defeated = true
	
	# Notify state machine of death
	if state_machine and state_machine.states.has("DeathState"):
		state_machine.change_state("DeathState")
		
		# Emit signal before visual effects in case listeners need to react
		emit_signal("defeated")
	else:
		# Fall back to original behavior if no state machine or death state
		super()

# Compatibility method to help systems that might check the current state
func get_current_state_name():
	if state_machine and state_machine.current_state_name:
		return state_machine.current_state_name
	return "IDLE"  # Default fallback for compatibility

# Helper method to bridge existing code to state machine 
func change_ai_state(new_state):
	# Convert enum state to string state for state machine
	var state_map = {
		AIState.IDLE: "IdleState",
		AIState.CHASING: "ChaseState",
		AIState.ATTACKING: "AttackState",
		AIState.REPOSITIONING: "RepositioningState",
		AIState.FLEEING: "FleeState",
		AIState.STUNNED: "StunnedState"
	}
	
	# Change state if state machine exists and has the requested state
	if state_machine and new_state in state_map:
		var state_name = state_map[new_state]
		if state_machine.states.has(state_name):
			state_machine.change_state(state_name)
