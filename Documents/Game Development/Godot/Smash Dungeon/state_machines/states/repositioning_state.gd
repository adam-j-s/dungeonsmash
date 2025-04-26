# state_machines/states/repositioning_state.gd
class_name RepositioningState
extends State

# Local variables to store configuration values for this state instance
var reposition_min_time: float = 0.5   # Default value if not in config
var reposition_max_time: float = 1.0   # Default value if not in config
# Note: reposition_chance is likely checked *before* entering this state,
# so it might not be needed *within* the state itself.

# Runtime variables
var reposition_timer: float = 0.0

func enter():
	# Load configuration parameters when entering the state
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.config):
		printerr("%s: RepositioningState cannot access enemy or enemy.config." % get_path())
		# Use hardcoded defaults and attempt to reposition
		_start_repositioning()
		return

	if enemy.config.states_config.has("RepositioningState"):
		var repo_config = enemy.config.states_config["RepositioningState"]

		# Use .get() to safely retrieve values, falling back to defaults
		self.reposition_min_time = repo_config.get("reposition_min_time", reposition_min_time)
		self.reposition_max_time = repo_config.get("reposition_max_time", reposition_max_time)

		if state_machine.debug_mode:
			print("%s: RepositioningState loaded config - time: %.1f-%.1f" % [enemy.name, reposition_min_time, reposition_max_time])
	else:
		if state_machine.debug_mode:
			print("%s: RepositioningState using default parameters (no config found)." % enemy.name)
		# Use the hardcoded defaults defined above if no "RepositioningState" config exists

	# Pick a direction to reposition to using loaded config values
	_start_repositioning()

func physics_process(delta):
	# Update timer
	reposition_timer -= delta

	# Check if we should end repositioning
	if reposition_timer <= 0:
		# Decide next state based on target validity
		if is_instance_valid(enemy._target_node):
			change_state("ChaseState")
		else:
			change_state("IdleState")
		return

	# Move in the calculated repositioning direction stored on the enemy
	# We assume the direction was set correctly either by AttackState (retreat) or by _start_repositioning
	if "reposition_direction" in enemy:
		enemy.target_velocity = enemy.reposition_direction * enemy.move_speed
	else:
		# Fallback if the variable doesn't exist for some reason
		enemy.target_velocity = Vector2.ZERO
		if reposition_timer > 0: # Avoid infinite loop if stuck
			change_state("IdleState") # Go idle if something is wrong

	# Continue checking if target becomes invalid during repositioning
	if not is_instance_valid(enemy._target_node):
		# Target lost mid-reposition, switch to Idle
		change_state("IdleState")
		return

# Calculate repositioning direction and timer
func _start_repositioning():
	# Only calculate a new direction if a target exists
	# If entering this state due to AttackState retreat, enemy.reposition_direction might already be set.
	# This logic is for when RepositioningState is entered *without* a pre-set direction.
	if is_instance_valid(enemy._target_node): # Corrected logic: MUST have target
		var dir_to_target = (enemy._target_node.global_position - enemy.global_position).normalized()

		# Create perpendicular vector (orbit direction)
		var perp = Vector2(-dir_to_target.y, dir_to_target.x)

		# Randomly choose clockwise or counter-clockwise
		if randf() > 0.5:
			perp = -perp

		# Add a slight angle variation
		var angle_offset = randf_range(-PI/4, PI/4)

		# Store the calculated direction on the enemy instance
		if "reposition_direction" in enemy:
			enemy.reposition_direction = perp.rotated(angle_offset)
		else:
			printerr("%s: Enemy script is missing 'reposition_direction' variable." % enemy.name)
			change_state("IdleState") # Cannot reposition without the variable
			return

		# Set timer using loaded min/max values
		reposition_timer = randf_range(self.reposition_min_time, self.reposition_max_time)

		if state_machine and state_machine.debug_mode:
			print("%s: REPOSITIONING for %.2f seconds in direction %s" % [enemy.name, reposition_timer, enemy.reposition_direction.round()])
	else:
		# No target to reposition relative to, cannot calculate direction, go back to idle
		if state_machine.debug_mode: print("%s: Cannot start repositioning without a target, going Idle." % enemy.name)
		change_state("IdleState")


# Handle messages
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# When damaged during repositioning, maybe change direction slightly or shorten duration
			if randf() < 0.3: # 30% chance to pick new direction when hit
				if state_machine.debug_mode: print("%s: Repositioning interrupted by damage, recalculating." % enemy.name)
				_start_repositioning() # Recalculate direction and timer
