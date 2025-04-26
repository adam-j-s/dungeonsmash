# fodder_chase_state.gd
extends ChaseState
class_name FodderChaseState

@export var jump_chance: float = 0.2
const DEBUG = true  # Easy to disable all debugging
var attack_check_counter = 0  # Counter to track consecutive attack checks

func enter():
	attack_check_counter = 0
	if DEBUG:
		print("FodderChaseState entered")

func physics_process(delta):
	# Get target info
	if is_instance_valid(enemy._target_node):
		var target_pos = enemy._target_node.global_position
		var vector_to_target = target_pos - enemy.global_position
		var distance = vector_to_target.length()
		var direction_to_target = vector_to_target.normalized()
		
		# Override movement to ensure enemy gets close enough
		# This bypasses the parent implementation which might not be aggressive enough
		var chase_speed = enemy.move_speed * enemy.chase_speed_multiplier
		enemy.target_velocity = direction_to_target * chase_speed
		
		# Debug output
		if DEBUG:
			var attack_range = 50.0
			if enemy.weapon_system and enemy.weapon_system.has_method("get_attack_range"):
				attack_range = enemy.weapon_system.get_attack_range()
			print("Chase: Distance: " + str(distance) + 
				  ", Range: " + str(attack_range) + 
				  ", Speed: " + str(chase_speed))
		
		# Occasionally jump when approaching target
		if enemy.is_on_floor() and randf() < jump_chance * delta * 2:
			enemy.velocity.y = -300  # Simple jump
	else:
		# No target, call parent method
		super.physics_process(delta)
	
	# Always check transitions
	check_transitions()

# Override the check_transitions method from parent class
func check_transitions():
	if DEBUG:
		print("FodderChaseState.check_transitions() called")
	
	# Check if target is valid
	if not is_instance_valid(enemy._target_node):
		if DEBUG: print("No valid target, going to idle")
		change_state("IdleState")
		return
		
	# Get distance to target
	var distance = enemy.global_position.distance_to(enemy._target_node.global_position)
	
	# Check if we can attack - first check direct enemy flag
	var can_attack_enemy = enemy.can_attack
	
	# Next, get weapon info
	var can_use_weapon = false
	var attack_range = 45.0 # Default
	
	if enemy.weapon_system:
		# First try the proper can_attack method
		if enemy.weapon_system.has_method("can_attack"):
			can_use_weapon = enemy.weapon_system.can_attack()
		# Fallback to checking weapon directly
		elif enemy.weapon_system.weapon and "can_attack" in enemy.weapon_system.weapon:
			can_use_weapon = enemy.weapon_system.weapon.can_attack
		
		if enemy.weapon_system.has_method("get_attack_range"):
			attack_range = enemy.weapon_system.get_attack_range()
	
	# Check line of sight
	var has_los = enemy.check_line_of_sight()
	
	# Check if we're in range
	var in_range = distance <= attack_range
	
	# Debug weapon system state
	if DEBUG:
		print("Attack check - Distance: " + str(distance) + 
			  ", Range: " + str(attack_range) + 
			  ", In range: " + str(in_range) + 
			  ", Has LOS: " + str(has_los) + 
			  ", Can use weapon: " + str(can_use_weapon) + 
			  ", Enemy can attack: " + str(can_attack_enemy))
		
		if enemy.weapon_system and enemy.weapon_system.weapon:
			var weapon = enemy.weapon_system.weapon
			print("Weapon details: " + 
				 "ID=" + str(weapon.weapon_id if "weapon_id" in weapon else "unknown") + 
				 ", can_attack=" + str(weapon.can_attack if "can_attack" in weapon else "unknown"))
			
			# Check cooldown timer if available
			if "cooldown_timer" in weapon and weapon.cooldown_timer:
				print("Cooldown timer: " + str(weapon.cooldown_timer.time_left))
				
		# List reasons for not attacking
		if !in_range: print("Not in range")
		if !has_los: print("No line of sight")
		if !can_use_weapon: print("Weapon not ready")
		if !can_attack_enemy: print("Enemy not ready to attack")
	
	# For enemies, prioritize the enemy's can_attack flag
	# but sync it with weapon state for consistency
	if in_range and has_los:
		# Synchronize the states if they're mismatched
		if can_attack_enemy != can_use_weapon:
			if DEBUG: 
				print("Attack state mismatch - syncing states")
			
			# If the enemy thinks it can attack but weapon doesn't, 
			# go with the enemy's state and try to transition
			if can_attack_enemy:
				if DEBUG: 
					print("*** TRANSITIONING TO ATTACK STATE (enemy ready) ***")
				change_state("AttackState")
				return
				
			# If the weapon is ready but enemy isn't, update enemy state
			if can_use_weapon and enemy.has_method("set_can_attack"):
				enemy.set_can_attack(true)
				if DEBUG: 
					print("Updated enemy can_attack state to match weapon")
				# Now both states should be true, transition next frame
		
		# Normal transition when both states are ready
		elif can_attack_enemy and can_use_weapon:
			if DEBUG: 
				print("*** TRANSITIONING TO ATTACK STATE (all systems ready) ***")
			change_state("AttackState")
			return
