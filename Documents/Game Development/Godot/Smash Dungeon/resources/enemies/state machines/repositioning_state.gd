# repositioning_state.gd
extends State
class_name RepositioningState

@export var reposition_min_time: float = 0.8
@export var reposition_max_time: float = 2.0
@export var reposition_speed_multiplier: float = 1.0

var reposition_timer: float = 0.0
var reposition_direction: Vector2 = Vector2.ZERO

func enter():
	var owner_entity = state_machine.owner_entity
	
	# Get target position
	if is_instance_valid(owner_entity._target_node):
		# Calculate direction perpendicular to target with some randomness
		var dir_to_target = (owner_entity._target_node.global_position - owner_entity.global_position).normalized()
		
		# Create perpendicular vector (orbit direction)
		var perp = Vector2(-dir_to_target.y, dir_to_target.x)
		
		# Randomly choose clockwise or counter-clockwise
		if randf() > 0.5:
			perp = -perp
		
		# Add a slight angle variation
		var angle_offset = randf_range(-PI/4, PI/4)
		reposition_direction = perp.rotated(angle_offset)
	else:
		# No target, pick random direction
		var random_angle = randf() * TAU
		reposition_direction = Vector2.RIGHT.rotated(random_angle)
	
	# Set timer
	reposition_timer = randf_range(reposition_min_time, reposition_max_time)

func process(delta):
	var owner_entity = state_machine.owner_entity
	
	# Move in the reposition direction
	owner_entity.target_velocity = reposition_direction * owner_entity.move_speed * reposition_speed_multiplier
	
	# Update timer
	reposition_timer -= delta

func check_transitions():
	var owner_entity = state_machine.owner_entity
	
	# Check if we should return to chasing
	if reposition_timer <= 0:
		change_state("Chase")
		return
	
	# If target is lost, return to Idle
	if not is_instance_valid(owner_entity._target_node):
		change_state("Idle")
		return

func handle_event(event_name: String, data = null) -> Variant:
	if event_name == "hit":
		# When hit, check if we should change state
		if randf() < 0.5:  # 50% chance to react to hit
			change_state("Chase")
	return null
