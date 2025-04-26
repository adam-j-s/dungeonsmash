# state_machines/states/idle_state.gd
class_name IdleState
extends State

# Local variables to store configuration values for this state instance
var wander_speed_multiplier: float = 0.4 # Default value if not in config
var wander_interval_min: float = 1.5   # Default value if not in config
var wander_interval_max: float = 4.0   # Default value if not in config

# Runtime variables
var wander_timer: float = 0.0
var current_wander_direction: Vector2 = Vector2.ZERO

func enter():
	# Load configuration parameters when entering the state
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.config):
		printerr("%s: IdleState cannot access enemy or enemy.config." % get_path())
		# Use the hardcoded defaults defined above
		_pick_new_wander_target() # Still need to initialize wander
		return

	if enemy.config.states_config.has("IdleState"):
		var idle_config = enemy.config.states_config["IdleState"]

		# Use .get() to safely retrieve values, falling back to defaults
		self.wander_speed_multiplier = idle_config.get("wander_speed_multiplier", wander_speed_multiplier)
		self.wander_interval_min = idle_config.get("wander_interval_min", wander_interval_min)
		self.wander_interval_max = idle_config.get("wander_interval_max", wander_interval_max)

		if state_machine.debug_mode:
			print("%s: IdleState loaded config - speed_mult: %.2f, interval: %.1f-%.1f" % [enemy.name, wander_speed_multiplier, wander_interval_min, wander_interval_max])
	else:
		if state_machine.debug_mode:
			print("%s: IdleState using default parameters (no config found)." % enemy.name)
		# Use the hardcoded defaults defined above if no "IdleState" config exists

	# Reset wander timer and pick a new direction using loaded config values
	_pick_new_wander_target()

func physics_process(delta):
	# Update wander timer
	wander_timer -= delta
	if wander_timer <= 0:
		_pick_new_wander_target() # Use the method to pick target based on loaded config

	# Check for targets periodically (using the enemy's method)
	if enemy.has_method("find_target"):
		enemy.find_target() # This might trigger handle_message("target_acquired")

	# Set target velocity based on wandering direction and loaded speed multiplier
	if "target_velocity" in enemy:
		# Use the loaded wander_speed_multiplier
		enemy.target_velocity = current_wander_direction * enemy.move_speed * self.wander_speed_multiplier

# Pick a new wandering direction and reset timer using loaded config values
func _pick_new_wander_target():
	var random_angle = randf_range(0, TAU) # TAU is 2 * PI
	current_wander_direction = Vector2.RIGHT.rotated(random_angle)
	# Use the loaded min/max interval values
	wander_timer = randf_range(self.wander_interval_min, self.wander_interval_max)

	# Use state_machine debug mode check which is more reliable
	if state_machine and state_machine.debug_mode:
		print("%s: Picked new wander direction: %s for %.2f seconds" %
			  [enemy.name, current_wander_direction.round(), wander_timer])

# Handle messages
func handle_message(msg, data=null):
	match msg:
		"target_acquired":
			# If the enemy's find_target method signals it found something, transition
			if state_machine.debug_mode: print("%s: IdleState received 'target_acquired', changing to ChaseState." % enemy.name)
			change_state("ChaseState")
