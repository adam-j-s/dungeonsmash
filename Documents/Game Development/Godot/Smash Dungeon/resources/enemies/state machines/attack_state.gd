# attack_state.gd
extends State
class_name AttackState

@export var min_attack_duration: float = 0.5
@export var attack_commitment: float = 0.5
@export var post_attack_pause: float = 0.0
@export var reposition_chance: float = 0.3
@export var combat_movement_speed_multiplier: float = 0.5

var attack_timer: float = 0.0

func enter():
	attack_timer = 0.0
	perform_attack()

func exit():
	attack_timer = 0.0

func process(delta):
	var owner_entity = state_machine.owner_entity
	var target = owner_entity._target_node
	
	# Update timer
	attack_timer += delta
	
	# Move based on aggression during attack
	if is_instance_valid(target):
		var direction_to_target = (target.global_position - owner_entity.global_position).normalized()
		var distance = owner_entity.global_position.distance_to(target.global_position)
		
		# Movement based on aggression level
		if owner_entity.aggression_level > 0.7:
			# High aggression, move toward target
			owner_entity.target_velocity = direction_to_target * owner_entity.move_speed * combat_movement_speed_multiplier * 1.3
		elif owner_entity.aggression_level > 0.3:
			# Medium aggression, strafe
			var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
			if randf() > 0.5:
				strafe_dir = -strafe_dir
			
			owner_entity.target_velocity = (strafe_dir * 0.7 + direction_to_target * 0.3) * owner_entity.move_speed * combat_movement_speed_multiplier
		else:
			# Low aggression, back away if too close
			var preferred_distance_diff = distance - owner_entity.preferred_attack_distance
			
			if preferred_distance_diff < 0:
				owner_entity.target_velocity = -direction_to_target * owner_entity.move_speed * combat_movement_speed_multiplier
			else:
				var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
				if randf() > 0.5:
					strafe_dir = -strafe_dir
				
				owner_entity.target_velocity = strafe_dir * owner_entity.move_speed * combat_movement_speed_multiplier * 0.7

func handle_event(event_name: String, data = null) -> Variant:
	if event_name == "hit":
		# When hit, check if we should change state
		if randf() < 0.3:  # 30% chance to react to hit
			change_state("Repositioning")
	return null

func check_transitions():
	var owner_entity = state_machine.owner_entity
	
	# Return to chase if no target
	if not is_instance_valid(owner_entity._target_node):
		change_state("Chase")
		return
	
	# Only continue checking after minimum attack duration
	if attack_timer < min_attack_duration:
		return
	
	# Check if we should reposition
	var retreat_chance_mod = 1.0 - attack_commitment
	var should_retreat = randf() < (reposition_chance * retreat_chance_mod)
	
	if should_retreat:
		change_state("Repositioning")
	else:
		# After attack finishes, return to chase
		change_state("Chase")

func perform_attack():
	var owner_entity = state_machine.owner_entity
	
	# Try weapon system first
	if owner_entity.weapon_system and owner_entity.weapon_system.can_attack():
		owner_entity.weapon_system.perform_attack()
	else:
		# Fallback to traditional attack
		owner_entity.attack_closest_target()
