# state_machines/states/stunned_state.gd
class_name StunnedState
extends State

# Local variable to store configuration value for this state instance
var stun_duration: float = 1.0 # Default value if not in config

# Runtime variable for the timer
var stun_timer: float = 0.0

func enter():
	# Load configuration parameter when entering the state
	# Note: stun_duration might be overridden by handle_message("stun", duration) later
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.config):
		printerr("%s: StunnedState cannot access enemy or enemy.config." % get_path())
		# Use the hardcoded default defined above
	elif enemy.config.states_config.has("StunnedState"):
		var stun_config = enemy.config.states_config["StunnedState"]
		# Use .get() to safely retrieve value, falling back to default
		self.stun_duration = stun_config.get("stun_duration", stun_duration)
	else:
		if state_machine and state_machine.debug_mode:
			print("%s: StunnedState using default duration (no config found)." % enemy.name)
		# Use the hardcoded default defined above if no "StunnedState" config exists

	# Initialize stun timer with the loaded (or default) duration
	stun_timer = self.stun_duration
	if state_machine and state_machine.debug_mode:
		print("%s: Entering StunnedState for %.2f seconds." % [enemy.name, stun_timer])

	# Stop movement immediately when stunned
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO
	if "velocity" in enemy: enemy.velocity = Vector2.ZERO

func physics_process(delta):
	# Update stun timer
	stun_timer -= delta

	# Check if stun has ended
	if stun_timer <= 0:
		# Stun finished, decide next state based on target validity
		if state_machine and state_machine.debug_mode: print("%s: Stun finished." % enemy.name)
		# CORRECTED LOGIC: Go to Chase if target exists, otherwise Idle
		if is_instance_valid(enemy._target_node):
			if state_machine.debug_mode: print("   -> Transitioning to ChaseState")
			change_state("ChaseState")
		else:
			if state_machine.debug_mode: print("   -> Transitioning to IdleState")
			change_state("IdleState")
		return # Exit after changing state

	# Ensure enemy remains stationary while stunned
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO
	# Optionally reset velocity too, though gravity/physics might re-apply it
	# if "velocity" in enemy: enemy.velocity.x = 0

# Allow external messages to set/override stun duration dynamically
func handle_message(msg, data=null):
	match msg:
		"stun":
			# Expecting data to be the desired duration (float or int)
			if typeof(data) == TYPE_FLOAT or typeof(data) == TYPE_INT:
				var duration = float(data)
				if duration > 0:
					# Override the default/config duration with the message data
					self.stun_duration = duration
					# Reset the timer with the new duration
					stun_timer = self.stun_duration
					if state_machine and state_machine.debug_mode:
						print("%s: Stun duration overridden by message: %.2f seconds." % [enemy.name, stun_timer])
				else:
					if state_machine and state_machine.debug_mode:
						print("%s: Received 'stun' message with invalid duration (<= 0)." % enemy.name)
			else:
				if state_machine and state_machine.debug_mode:
					print("%s: Received 'stun' message without valid duration data." % enemy.name)
					# Optionally, just reset timer with current/default duration if message is received without data?
					# stun_timer = self.stun_duration
