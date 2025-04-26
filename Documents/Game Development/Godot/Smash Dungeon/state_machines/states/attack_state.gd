# state_machines/states/attack_state.gd
class_name AttackState
extends State

# Configuration parameters (pulled from enemy.config.states_config["AttackState"])
var attack_commitment: float = 0.0 # Time spent in this state AFTER attack execution
var attack_retreat_distance: float = 0.0 # Used to decide transition

# Internal timer for attack commitment delay
var commit_timer: Timer

func _ready():
	# Create and configure the internal timer node for commitment
	commit_timer = Timer.new()
	commit_timer.one_shot = true
	# Connect the timeout signal using Godot 4 syntax
	commit_timer.timeout.connect(_on_commit_timer_timeout)
	add_child(commit_timer)

func enter():
	if state_machine.debug_mode: print("%s: Entering AttackState" % enemy.name)

	# Load configuration for this state
	if enemy and enemy.config and enemy.config.states_config.has("AttackState"):
		var attack_config = enemy.config.states_config["AttackState"]
		attack_commitment = attack_config.get("attack_commitment", 0.0)
		attack_retreat_distance = attack_config.get("attack_retreat_distance", 0.0)
	else:
		printerr("%s: AttackState could not find its configuration. Using defaults." % enemy.name)
		# Default values are set above

	# Immediately execute the attack
	var attack_success = _execute_attack()

	# Handle transition after execution
	if attack_commitment > 0.0 and attack_success:
		# Start commit timer if commitment time is set and attack was initiated
		commit_timer.wait_time = attack_commitment
		commit_timer.start()
		if state_machine.debug_mode: print("%s: AttackState started commit timer: %.2fs" % [enemy.name, attack_commitment])
	else:
		# If no commitment time or attack failed, decide next state immediately
		_decide_next_state()

func exit():
	if state_machine.debug_mode: print("%s: Exiting AttackState" % enemy.name)
	# Ensure the timer is stopped cleanly if exiting prematurely (e.g., via message)
	if commit_timer.is_running():
		commit_timer.stop()

# physics_process is no longer needed for movement logic in the base AttackState
# func physics_process(delta):
#	 pass

# Performs the actual attack via weapon system
func _execute_attack() -> bool:
	if not is_instance_valid(enemy) or not enemy.weapon_system:
		printerr("%s: AttackState cannot execute attack - invalid enemy or weapon system." % enemy.name)
		return false

	# Call the weapon system to perform the attack
	# It's assumed TelegraphState finished because the weapon was ready,
	# but perform_attack itself might have internal checks.
	var success = enemy.weapon_system.perform_attack()

	# Update enemy state if attack was successfully initiated
	if success:
		enemy.can_attack = false # Mark enemy as having just attacked (for potential cooldown checks)
		if state_machine.debug_mode: print("%s: AttackState executed attack via weapon system." % enemy.name)
	else:
		if state_machine.debug_mode: print("%s: AttackState: weapon_system.perform_attack() returned false." % enemy.name)

	return success

# Determines the next state after the attack (and commitment period, if any)
func _decide_next_state():
	# Check if the state is still active before changing
	if state_machine.current_state != self:
		return

	if not is_instance_valid(enemy):
		printerr("AttackState: Cannot decide next state, enemy invalid.")
		return # Should not happen, but safety check

	# Check if retreating is configured and possible
	# Use _target_node for consistency
	if attack_retreat_distance > 0.0 and is_instance_valid(enemy._target_node): # MODIFIED
		# Set up retreat direction for RepositioningState
		# Use _target_node for consistency
		var retreat_dir = (enemy.global_position - enemy._target_node.global_position).normalized() # MODIFIED
		if enemy.has_method("set_reposition_direction"):
			enemy.set_reposition_direction(retreat_dir)
		else:
			# Fallback if method doesn't exist (e.g., store on enemy directly)
			enemy.reposition_direction = retreat_dir

		if state_machine.debug_mode: print("%s: AttackState deciding next state: RepositioningState (Retreat)" % enemy.name)
		change_state("RepositioningState")
	else:
		# Default transition: Go back to chasing if target exists, otherwise Idle
		# Use _target_node for consistency
		if is_instance_valid(enemy._target_node): # Check if target still exists # MODIFIED
			if state_machine.debug_mode: print("%s: AttackState deciding next state: ChaseState" % enemy.name)
			change_state("ChaseState")
		else:
			if state_machine.debug_mode: print("%s: AttackState deciding next state: IdleState (Target lost)" % enemy.name)
			change_state("IdleState")


# Called by the commit_timer when its time is up
func _on_commit_timer_timeout():
	if state_machine.debug_mode: print("%s: AttackState commit timer finished." % enemy.name)
	_decide_next_state()


# Handle messages (e.g., damage for interruption)
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# Attack interruption logic based on commitment
			# Recalculate commitment here in case config changes dynamically (unlikely but safe)
			var current_commitment = 0.0
			if enemy and enemy.config and enemy.config.states_config.has("AttackState"):
				current_commitment = enemy.config.states_config["AttackState"].get("attack_commitment", 0.0)

			# Allow interrupt only if commitment time is very low or not running
			# (i.e., during the brief execution moment or if commitment is zero)
			# Or potentially add a specific 'interruptible_during_commit' config flag
			var allow_interrupt = true # Default to allowing interrupt if damaged in this state
			if commit_timer.is_running() and current_commitment > 0.1: # Example: Don't interrupt if in >0.1s commitment
				allow_interrupt = false

			if allow_interrupt:
				if state_machine.debug_mode: print("%s: AttackState interrupted by damage." % enemy.name)
				# Ensure we are not already transitioning due to timer timeout race condition
				if state_machine.current_state == self:
					# Transition immediately, likely to a hurt or reposition state
					# Using RepositioningState as a generic "recover" state here
					if state_machine.states.has("StunnedState"): # Prefer Stunned if available
						change_state("StunnedState")
					else:
						change_state("RepositioningState")
