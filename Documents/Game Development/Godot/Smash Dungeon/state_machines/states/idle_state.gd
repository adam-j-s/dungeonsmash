# state_machines/states/idle_state.gd
class_name IdleState
extends State

# Local variables to store configuration values for this state instance
var wander_speed_multiplier: float = 0.4
var wander_interval_min: float = 1.5
var wander_interval_max: float = 4.0

# Runtime variables
var wander_timer: float = 0.0
var current_wander_direction: Vector2 = Vector2.ZERO

func enter():
	# Attempt to load configuration from the specific IdleStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.idle_config):
		var cfg: IdleStateConfig = enemy.config.idle_config # Assign the specific resource

		# Load values from the config resource's properties
		self.wander_speed_multiplier = cfg.wander_speed_multiplier
		self.wander_interval_min = cfg.wander_interval_min
		self.wander_interval_max = cfg.wander_interval_max
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: IdleState loaded config - speed_mult: %.2f, interval: %.1f-%.1f" % [enemy.name, wander_speed_multiplier, wander_interval_min, wander_interval_max])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: IdleState could not find valid idle_config resource. Using default values." % get_path())
		# Defaults are already set in the variable declarations above

	# Reset wander timer and pick a new direction using loaded/default config values
	_pick_new_wander_target()


func physics_process(delta):
	# Update wander timer
	wander_timer -= delta
	if wander_timer <= 0:
		_pick_new_wander_target()

	# Check for targets periodically
	if enemy.has_method("find_target"):
		enemy.find_target()

	# Set target velocity based on wandering direction and loaded speed multiplier
	if "target_velocity" in enemy:
		enemy.target_velocity = current_wander_direction * enemy.move_speed * self.wander_speed_multiplier


func _pick_new_wander_target():
	var random_angle = randf_range(0, TAU)
	current_wander_direction = Vector2.RIGHT.rotated(random_angle)
	# Use the loaded min/max interval values
	wander_timer = randf_range(self.wander_interval_min, self.wander_interval_max)

	if state_machine and state_machine.debug_mode:
		print("%s: Picked new wander direction: %s for %.2f seconds" %
			  [enemy.name, current_wander_direction.round(), wander_timer])


func handle_message(msg, data=null):
	match msg:
		"target_acquired":
			if state_machine.debug_mode: print("%s: IdleState received 'target_acquired', changing to ChaseState." % enemy.name)
			change_state("ChaseState")
