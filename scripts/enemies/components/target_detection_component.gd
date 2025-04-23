# Target Detection Component
class_name TargetDetectionComponent
extends EnemyComponent

@export var detection_range: float = 300.0
@export var attack_range: float = 60.0
@export var attack_angle: float = PI/3  # 60 degrees field of view
@export var check_line_of_sight: bool = true

func process(delta: float):
	# Skip if stunned or defeated
	if enemy.current_ai_state == enemy.AIState.STUNNED or enemy._is_defeated:
		return
	
	# Find or update target
	find_or_update_target()
	
	# Handle state transitions
	handle_ai_state_transitions()

func find_or_update_target():
	# Keep current target if valid
	if enemy._target_node and is_instance_valid(enemy._target_node):
		var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
		if distance <= detection_range:
			if !check_line_of_sight or enemy.check_line_of_sight():
				return  # Target still valid
	
	# Find a new target
	enemy._target_node = null
	var potential_targets = enemy.get_tree().get_nodes_in_group("players")
	var closest_distance = detection_range
	
	for target in potential_targets:
		if is_instance_valid(target) and target is Node2D:
			# Skip defeated targets
			if "is_defeated" in target and target.is_defeated:
				continue
				
			# Check distance
			var distance = enemy.global_position.distance_to(target.global_position)
			if distance < closest_distance:
				# Check line of sight if needed
				if check_line_of_sight and !enemy.check_line_of_sight_to_point(target.global_position):
					continue
					
				# This is our new closest target
				enemy._target_node = target
				closest_distance = distance

func handle_ai_state_transitions():
	if enemy._target_node and is_instance_valid(enemy._target_node):
		# Check if we should attack
		var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
		
		if distance <= attack_range:
			if enemy.current_ai_state != enemy.AIState.ATTACKING:
				enemy.change_ai_state(enemy.AIState.ATTACKING)
		else:
			if enemy.current_ai_state == enemy.AIState.IDLE:
				enemy.change_ai_state(enemy.AIState.CHASING)
			elif enemy.current_ai_state == enemy.AIState.ATTACKING:
				enemy.change_ai_state(enemy.AIState.CHASING)
	else:
		# No target, go to idle
		if enemy.current_ai_state != enemy.AIState.IDLE:
			enemy.change_ai_state(enemy.AIState.IDLE)
