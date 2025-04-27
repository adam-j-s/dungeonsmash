# state_machines/states/stunned_state.gd
class_name StunnedState
extends State

# Local variable to store configuration value for this state instance
var stun_duration: float = 1.0 # Default value if not in config

# Runtime variable for the timer
var stun_timer: float = 0.0

func enter():
	# Default duration (used if config is missing or message doesn't override)
	var duration_to_use = self.stun_duration

	# Attempt to load configuration from the specific StunnedStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.stunned_config):
		var cfg: StunnedStateConfig = enemy.config.stunned_config

		# Load value from the config resource's property
		duration_to_use = cfg.stun_duration # Use config value as the base
		self.stun_duration = duration_to_use # Update the state default too
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: StunnedState loaded config duration: %.2f" % [enemy.name, duration_to_use])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: StunnedState could not find valid stunned_config resource. Using default value: %.2f." % [get_path(), duration_to_use])
		# Default duration_to_use is already set from the variable declaration

	# Initialize stun timer with the loaded (or default) duration
	# Note: This might be immediately overridden by handle_message if called right after transition
	stun_timer = duration_to_use
	if state_machine and state_machine.debug_mode:
		print("%s: Entering StunnedState for %.2f seconds (may be overridden by message)." % [enemy.name, stun_timer])

	# Stop movement immediately when stunned
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO
	if "velocity" in enemy: enemy.velocity = Vector2.ZERO # Stop current momentum too

func physics_process(delta):
	stun_timer -= delta

	if stun_timer <= 0:
		if state_machine and state_machine.debug_mode: print("%s: Stun finished." % enemy.name)
		if is_instance_valid(enemy._target_node):
			if state_machine.debug_mode: print("   -> Transitioning to ChaseState")
			change_state("ChaseState")
		else:
			if state_machine.debug_mode: print("   -> Transitioning to IdleState")
			change_state("IdleState")
		return

	# Ensure enemy remains stationary while stunned
	if "target_velocity" in enemy: enemy.target_velocity = Vector2.ZERO

# Allow external messages to set/override stun duration dynamically
func handle_message(msg, data=null):
	match msg:
		"stun": # Typically called immediately after transitioning TO StunnedState
			if typeof(data) == TYPE_FLOAT or typeof(data) == TYPE_INT:
				var duration_from_message = float(data)
				if duration_from_message > 0:
					# Override the default/config duration with the message data
					# Update the state's base duration too for consistency if needed elsewhere
					self.stun_duration = duration_from_message
					# Reset the timer immediately with the new duration
					stun_timer = self.stun_duration
					if state_machine and state_machine.debug_mode:
						print("%s: Stun duration set by message: %.2f seconds." % [enemy.name, stun_timer])
				else:
					if state_machine and state_machine.debug_mode:
						print("%s: Received 'stun' message with invalid duration (<= 0). Using default/config duration: %.2f" % [enemy.name, self.stun_duration])
						stun_timer = self.stun_duration # Ensure timer uses valid duration
			else:
				if state_machine and state_machine.debug_mode:
					print("%s: Received 'stun' message without valid duration data. Using default/config duration: %.2f" % [enemy.name, self.stun_duration])
				# Use the duration loaded from config or the hardcoded default
				stun_timer = self.stun_duration

		"damaged": # Handle potential damage *while already stunned*
			# Maybe reset the stun timer? Or ignore?
			if state_machine.debug_mode: print("%s: Received 'damaged' message while already stunned. (Ignoring)" % enemy.name)
			pass
