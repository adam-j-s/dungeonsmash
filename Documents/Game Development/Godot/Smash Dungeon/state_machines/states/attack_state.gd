# state_machines/states/attack_state.gd
class_name AttackState
extends State

# Local variables to store configuration values for this state instance
var attack_commitment: float = 0.0 # Default value if not in config
var attack_retreat_distance: float = 0.0 # Default value if not in config

# Internal timer for attack commitment delay
var commit_timer: Timer

func _ready():
	commit_timer = Timer.new()
	commit_timer.one_shot = true
	commit_timer.timeout.connect(_on_commit_timer_timeout)
	add_child(commit_timer)

func enter():
	if state_machine.debug_mode: print("%s: Entering AttackState" % enemy.name)

	# Attempt to load configuration from the specific AttackStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.attack_config):
		var cfg: AttackStateConfig = enemy.config.attack_config # Assign the specific resource

		# Load values from the config resource's properties
		self.attack_commitment = cfg.attack_commitment
		self.attack_retreat_distance = cfg.attack_retreat_distance
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: AttackState loaded config - commitment: %.2f, retreat_dist: %.1f" % [enemy.name, attack_commitment, attack_retreat_distance])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: AttackState could not find valid attack_config resource. Using default values." % get_path())
		# Defaults are already set above

	# Immediately execute the attack
	var attack_success = _execute_attack()

	# Handle transition after execution using loaded config values
	# Use self.attack_commitment
	if self.attack_commitment > 0.0 and attack_success:
		commit_timer.wait_time = self.attack_commitment # Use loaded value
		commit_timer.start()
		if state_machine.debug_mode: print("%s: AttackState started commit timer: %.2fs" % [enemy.name, self.attack_commitment])
	else:
		_decide_next_state()

func exit():
	if state_machine.debug_mode: print("%s: Exiting AttackState" % enemy.name)
	if commit_timer.is_running():
		commit_timer.stop()

# Performs the actual attack via weapon system
func _execute_attack() -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.weapon_system):
		printerr("%s: AttackState cannot execute attack - invalid enemy or weapon system." % enemy.name)
		return false

	var success = enemy.weapon_system.perform_attack()

	if success:
		enemy.can_attack = false
		if state_machine.debug_mode: print("%s: AttackState executed attack via weapon system." % enemy.name)
	else:
		if state_machine.debug_mode: print("%s: AttackState: weapon_system.perform_attack() returned false." % enemy.name)

	return success

# Determines the next state after the attack (and commitment period, if any)
func _decide_next_state():
	if state_machine.current_state != self: return
	if not is_instance_valid(enemy):
		printerr("AttackState: Cannot decide next state, enemy invalid.")
		return

	# Check if retreating is configured and possible using loaded config value
	# Use self.attack_retreat_distance
	if self.attack_retreat_distance > 0.0 and is_instance_valid(enemy._target_node):
		var retreat_dir = (enemy.global_position - enemy._target_node.global_position).normalized()
		if enemy.has_method("set_reposition_direction"):
			enemy.set_reposition_direction(retreat_dir)
		else: enemy.reposition_direction = retreat_dir

		if state_machine.debug_mode: print("%s: AttackState deciding next state: RepositioningState (Retreat)" % enemy.name)
		change_state("RepositioningState")
	else:
		# Default transition
		if is_instance_valid(enemy._target_node):
			if state_machine.debug_mode: print("%s: AttackState deciding next state: ChaseState" % enemy.name)
			change_state("ChaseState")
		else:
			if state_machine.debug_mode: print("%s: AttackState deciding next state: IdleState (Target lost)" % enemy.name)
			change_state("IdleState")


func _on_commit_timer_timeout():
	if state_machine.debug_mode: print("%s: AttackState commit timer finished." % enemy.name)
	_decide_next_state()

# Handle messages (e.g., damage for interruption)
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# Attack interruption logic - use the loaded config value
			# Use self.attack_commitment
			var current_commitment = self.attack_commitment # Read directly from state var

			var allow_interrupt = true
			# Don't interrupt if commit timer is running AND commitment time is significant
			if commit_timer.is_running() and current_commitment > 0.1:
				allow_interrupt = false

			if allow_interrupt:
				if state_machine.debug_mode: print("%s: AttackState interrupted by damage." % enemy.name)
				if state_machine.current_state == self:
					if state_machine.states.has("StunnedState"):
						change_state("StunnedState")
					else:
						change_state("RepositioningState") # Fallback
