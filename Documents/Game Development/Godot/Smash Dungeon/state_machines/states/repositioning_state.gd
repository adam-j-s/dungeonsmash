# state_machines/states/repositioning_state.gd
class_name RepositioningState
extends State

# Local variables to store configuration values for this state instance
var reposition_min_time: float = 0.5
var reposition_max_time: float = 1.0

# Runtime variables
var reposition_timer: float = 0.0

func enter():
	# Attempt to load configuration from the specific RepositioningStateConfig resource
	var loaded_config = false
	if is_instance_valid(enemy) and is_instance_valid(enemy.config) and is_instance_valid(enemy.config.repositioning_config):
		var cfg: RepositioningStateConfig = enemy.config.repositioning_config

		# Load values from the config resource's properties
		self.reposition_min_time = cfg.reposition_min_time
		self.reposition_max_time = cfg.reposition_max_time
		loaded_config = true

		if state_machine.debug_mode:
			print("%s: RepositioningState loaded config - time: %.1f-%.1f" % [enemy.name, reposition_min_time, reposition_max_time])

	if not loaded_config:
		# Log error or warning if config resource is missing or invalid
		printerr("%s: RepositioningState could not find valid repositioning_config resource. Using default values." % get_path())
		# Defaults are already set above

	# Calculate reposition direction and set timer using loaded config values
	_start_repositioning()

func physics_process(delta):
	reposition_timer -= delta

	if reposition_timer <= 0:
		if is_instance_valid(enemy._target_node): change_state("ChaseState")
		else: change_state("IdleState")
		return

	# Move in the calculated repositioning direction
	if "reposition_direction" in enemy:
		enemy.target_velocity = enemy.reposition_direction * enemy.move_speed
	else:
		enemy.target_velocity = Vector2.ZERO
		if reposition_timer > 0: change_state("IdleState") # Failsafe

	# Check if target lost mid-reposition
	if not is_instance_valid(enemy._target_node):
		change_state("IdleState")
		return

# Calculate repositioning direction and timer
func _start_repositioning():
	# Check if direction was already set (e.g., by AttackState retreat)
	var calculate_new_direction = true
	if "reposition_direction" in enemy and enemy.reposition_direction != Vector2.ZERO:
		# If direction is non-zero, assume it was set externally (retreat)
		# We just need to set the timer based on config
		calculate_new_direction = false
		if state_machine.debug_mode:
			print("%s: Repositioning using pre-set direction (likely retreat): %s" % [enemy.name, enemy.reposition_direction.round()])

	if calculate_new_direction:
		if is_instance_valid(enemy._target_node):
			var dir_to_target = (enemy._target_node.global_position - enemy.global_position).normalized()
			var perp = Vector2(-dir_to_target.y, dir_to_target.x)
			if randf() > 0.5: perp = -perp
			var angle_offset = randf_range(-PI/4, PI/4)

			if "reposition_direction" in enemy:
				enemy.reposition_direction = perp.rotated(angle_offset)
			else:
				printerr("%s: Enemy script is missing 'reposition_direction' variable." % enemy.name)
				change_state("IdleState")
				return
			if state_machine and state_machine.debug_mode:
				print("%s: Repositioning calculated new direction: %s" % [enemy.name, enemy.reposition_direction.round()])
		else:
			if state_machine.debug_mode: print("%s: Cannot calculate reposition direction without target, going Idle." % enemy.name)
			change_state("IdleState")
			return # Exit if no target and no pre-set direction

	# Set timer using loaded min/max values regardless of how direction was set
	reposition_timer = randf_range(self.reposition_min_time, self.reposition_max_time)
	if state_machine and state_machine.debug_mode:
		print("%s: Reposition timer set for %.2f seconds." % [enemy.name, reposition_timer])

	# Safety clear pre-set direction if we calculated a new one, just in case
	# (Though it should have been overwritten above if variable exists)
	# if calculate_new_direction and "reposition_direction" in enemy:
	#     enemy.reposition_direction = Vector2.ZERO # Clear if needed, but overwrite should handle it

func handle_message(msg, data=null):
	match msg:
		"damaged":
			# When damaged during repositioning, maybe just shorten duration?
			if randf() < 0.5: # 50% chance to react
				var reduced_time = max(0.1, reposition_timer * 0.5) # Halve remaining time (min 0.1s)
				if state_machine.debug_mode: print("%s: Repositioning interrupted by damage, reducing timer to %.2f." % [enemy.name, reduced_time])
				reposition_timer = reduced_time
				# Optionally recalculate direction too:
				# _start_repositioning()
