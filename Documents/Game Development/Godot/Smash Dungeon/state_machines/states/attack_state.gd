# state_machines/states/attack_state.gd
class_name AttackState
extends State

# Configuration parameters
var attack_commitment = 0.5
var post_attack_pause = 0.0
var attack_retreat_distance = 0.0
var combat_movement_speed_multiplier = 0.5
var min_attack_state_duration = 0.5

# Internal tracking variables
var attack_state_timer = 0.0
var post_pause_timer = 0.0
var is_post_attack = false

func enter():
	attack_state_timer = 0.0
	post_pause_timer = 0.0
	is_post_attack = false

func physics_process(delta):
	# Update state timer
	attack_state_timer += delta
	
	# Check if we're in post-attack pause
	if is_post_attack:
		post_pause_timer -= delta
		if post_pause_timer <= 0:
			handle_post_attack_decision()
		return
	
	# Check if target is still valid
	if not is_instance_valid(enemy._target_node):
		change_state("IdleState")
		return
	
	# Move based on aggression level during combat
	if is_instance_valid(enemy._target_node):
		var direction_to_target = (enemy._target_node.global_position - enemy.global_position).normalized()
		
		# Get distance to target
		var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
		
		# High aggression = keep moving toward target during attacks
		if enemy.aggression_level > 0.7:
			# Continue moving toward target, just slightly slower
			enemy.target_velocity = direction_to_target * enemy.move_speed * combat_movement_speed_multiplier * 1.3
		# Medium aggression = maintain slight distance
		elif enemy.aggression_level > 0.3:
			# Strafe with forward tendency
			var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
			if randf() > 0.5: # Randomly reverse direction
				strafe_dir = -strafe_dir
				
			# Mix strafing with forward movement
			enemy.target_velocity = (strafe_dir * 0.7 + direction_to_target * 0.3) * enemy.move_speed * combat_movement_speed_multiplier
		# Low aggression = back off after attacking
		else:
			var preferred_distance_diff = distance - enemy.preferred_attack_distance
			
			if preferred_distance_diff < 0: # Too close
				enemy.target_velocity = -direction_to_target * enemy.move_speed * combat_movement_speed_multiplier
			else: # Good distance or too far
				# Strafe at the right distance
				var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
				if randf() > 0.5: # Randomly reverse direction
					strafe_dir = -strafe_dir
					
				enemy.target_velocity = strafe_dir * enemy.move_speed * combat_movement_speed_multiplier * 0.7
	else:
		enemy.target_velocity = Vector2.ZERO
	
	# Try to perform an attack if we've been in this state long enough
	if attack_state_timer >= min_attack_state_duration:
		perform_attack()

func perform_attack():
	var attack_success = false
	
	# First try with weapon system if available
	if enemy.can_attack and enemy.weapon_system and enemy.weapon_system.can_attack() and enemy.is_instance_valid(enemy._target_node):
		attack_success = enemy.weapon_system.perform_attack()
		if attack_success:
			enemy.can_attack = false
			handle_attack_success()
			return
			
	# Fallback to traditional attack system
	if not attack_success:
		# Check if target is in range
		if is_instance_valid(enemy._target_node):
			# Determine best attack to use based on distance
			var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
			var best_attack_type = ""
			
			for attack_type in enemy.attack_types:
				var attack = enemy.attack_types[attack_type]
				var attack_range = attack.get("range", 50.0)
				
				if distance <= attack_range and enemy.can_use_attack(attack_type):
					best_attack_type = attack_type
					break
					
			if best_attack_type != "":
				attack_success = enemy.perform_attack(best_attack_type)
				if attack_success:
					handle_attack_success()

func handle_attack_success():
	# Reset attack state timer
	attack_state_timer = 0.0
	
	# If pause time is set, enter post-attack pause state
	if post_attack_pause > 0.0:
		is_post_attack = true
		post_pause_timer = post_attack_pause
		# During pause, slow down or stop movement
		var pause_velocity_factor = attack_commitment * 0.5 # Higher commitment = less slowing
		enemy.target_velocity *= pause_velocity_factor
	else:
		# No pause, decide immediately
		handle_post_attack_decision()

func handle_post_attack_decision():
	is_post_attack = false
	
	# If retreat distance is set, apply immediate repositioning
	if attack_retreat_distance > 0.0 and enemy.is_instance_valid(enemy._target_node):
		var retreat_dir = (enemy.global_position - enemy._target_node.global_position).normalized()
		enemy.reposition_direction = retreat_dir
		change_state("RepositioningState")
		return
		
	# Calculate retreat based on attack_commitment (inverse relationship)
	var retreat_chance_mod = 1.0 - attack_commitment
	var should_retreat = randf() < (enemy.reposition_chance * retreat_chance_mod)
	
	if should_retreat:
		change_state("RepositioningState")
	elif attack_commitment > 0.7:
		# High commitment enemies go back to chasing
		change_state("ChaseState")
		
	# Otherwise, stay in attack state for another attempt

# Handle messages
func handle_message(msg, data=null):
	match msg:
		"damaged":
			# When damaged, maybe interrupt attack pattern
			if randf() < 0.3: # 30% chance to reposition when hit
				change_state("RepositioningState")
