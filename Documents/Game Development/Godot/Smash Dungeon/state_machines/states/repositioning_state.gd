# state_machines/states/repositioning_state.gd
class_name RepositioningState
extends State

# Parameters
var reposition_min_time = 0.8
var reposition_max_time = 2.0
var reposition_chance = 0.3

# Runtime variables
var reposition_timer = 0.0

func enter():
	# Pick a direction to reposition to
	start_repositioning()
	
func physics_process(delta):
	# Update timer
	reposition_timer -= delta
	
	# Check if we should end repositioning
	if reposition_timer <= 0:
		change_state("ChaseState")
		return
		
	# Move in the repositioning direction
	enemy.target_velocity = enemy.reposition_direction * enemy.move_speed
	
	# Continue checking if target is still valid during repositioning
	if not enemy.is_instance_valid(enemy._target_node):
		change_state("IdleState")
		return

# Start repositioning behavior
func start_repositioning():
	# Pick a direction to reposition
	if not is_instance_valid(enemy._target_node):
		var dir_to_target = (enemy._target_node.global_position - enemy.global_position).normalized()
		
		# Create perpendicular vector (orbit direction)
		var perp = Vector2(-dir_to_target.y, dir_to_target.x)
		
		# Randomly choose clockwise or counter-clockwise
		if randf() > 0.5:
			perp = -perp
			
		# Add a slight angle variation
		var angle_offset = randf_range(-PI/4, PI/4)
		enemy.reposition_direction = perp.rotated(angle_offset)
		
		# Set timer
		reposition_timer = randf_range(reposition_min_time, reposition_max_time)
		
		if "debug_mode" in enemy and enemy.debug_mode:
			print("%s: REPOSITIONING for %.2f seconds in direction %s" % [enemy.name, reposition_timer, enemy.reposition_direction])
	else:
		# No target to reposition relative to, go back to idle
		change_state("IdleState")

# Handle messages
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# When damaged during repositioning, maybe change direction
			if randf() < 0.5: # 50% chance to pick new direction when hit
				start_repositioning()
