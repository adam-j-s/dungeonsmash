# state_machines/states/chase_state.gd
class_name ChaseState
extends State

# Configuration parameters from enemy
var sight_range = 600.0
var preferred_attack_distance = 150.0 
var preferred_distance_tolerance = 50.0
var chase_speed_multiplier = 1.2
var direct_chase = false
var chase_jump_chance = 0.0
var chase_jump_force = 300.0
var aggression_level = 0.5

func enter():
	pass

func physics_process(delta):
	# Skip if no target
	if not is_instance_valid(enemy._target_node):
		change_state("IdleState")
		return

	# Get target position and calculate distance
	var target_pos = enemy._target_node.global_position
	var vector_to_target = target_pos - enemy.global_position
	var distance_sq = vector_to_target.length_squared()
	var distance = sqrt(distance_sq)

	# Direction to target
	var direction_to_target = vector_to_target.normalized()

	# Calculate preferred distance difference
	var preferred_distance_diff = distance - preferred_attack_distance
	var move_strength = 1.0

	# If we're close to the preferred distance, reduce movement speed
	if abs(preferred_distance_diff) < preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / preferred_distance_tolerance

	# Decide movement strategy based on aggression parameters and distance
	if direct_chase or abs(preferred_distance_diff) > preferred_distance_tolerance * (2.0 - aggression_level):
		# Direct approach or retreat based on preferred distance
		if preferred_distance_diff > 0:
			# Too far, move directly toward player
			var approach_speed = enemy.move_speed * chase_speed_multiplier * (1.0 + aggression_level * 0.5)
			enemy.target_velocity = direction_to_target * approach_speed
		else:
			# Too close, back away from player
			var retreat_factor = max(0.2, 1.0 - aggression_level * 0.8)
			enemy.target_velocity = -direction_to_target * enemy.move_speed * 0.8 * retreat_factor
	else:
		# At good distance, orbital movement
		var orbit_factor = max(0.2, 1.0 - aggression_level * 0.7)
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x)
		enemy.target_velocity = orbit_dir * enemy.move_speed * 0.5 * move_strength * orbit_factor

	# Random jumps during chase if enabled
	if enemy.is_on_floor() and randf() < chase_jump_chance * delta:
		enemy.velocity.y = -chase_jump_force

	# Check if within attack range and line of sight
	# First check with the weapon system if available
	if enemy.weapon_system and is_instance_valid(enemy._target_node):
		var weapon_range = enemy.weapon_system.get_attack_range()
		if distance <= weapon_range and enemy.check_line_of_sight() and enemy.weapon_system.can_attack():
			change_state("AttackState")
			return
	
	# Fallback to attack_types if no weapon system
	if "attack_types" in enemy:
		for attack_type in enemy.attack_types:
			var attack = enemy.attack_types[attack_type]
			var attack_range = attack.get("range", 50.0)
			
			# More aggressive enemies will attack from further away
			var effective_attack_range = attack_range * (1.0 + aggression_level * 0.3)
			
			if distance <= effective_attack_range and enemy.check_line_of_sight():
				if enemy.has_method("can_use_attack") and enemy.can_use_attack(attack_type):
					change_state("AttackState")
					break
