# chase_state.gd
extends State
class_name ChaseState

@export var chase_speed_multiplier: float = 1.2
@export var preferred_attack_distance: float = 100.0
@export var preferred_distance_tolerance: float = 20.0
@export var direct_chase: bool = false
@export var aggression_level: float = 0.5

func enter():
	# Nothing special needed for entry
	pass

func process(delta):
	var owner_entity = state_machine.owner_entity
	var target = owner_entity._target_node
	
	# Return to idle if no target
	if not is_instance_valid(target):
		change_state("Idle")
		return
	
	# Get direction and distance to target
	var vector_to_target = target.global_position - owner_entity.global_position
	var distance = vector_to_target.length()
	var direction_to_target = vector_to_target.normalized()
	
	# Calculate preferred distance difference
	var preferred_distance_diff = distance - preferred_attack_distance
	var move_strength = 1.0
	
	# If we're close to preferred distance, reduce movement
	if abs(preferred_distance_diff) < preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / preferred_distance_tolerance
	
	# Decide movement strategy
	if direct_chase or abs(preferred_distance_diff) > preferred_distance_tolerance * (2.0 - aggression_level):
		# Direct approach or retreat
		if preferred_distance_diff > 0:
			# Too far, approach
			var approach_speed = owner_entity.move_speed * chase_speed_multiplier * (1.0 + aggression_level * 0.5)
			owner_entity.target_velocity = direction_to_target * approach_speed
		else:
			# Too close, back away
			var retreat_factor = max(0.2, 1.0 - aggression_level * 0.8)
			owner_entity.target_velocity = -direction_to_target * owner_entity.move_speed * 0.8 * retreat_factor
	else:
		# At good distance, orbit
		var orbit_factor = max(0.2, 1.0 - aggression_level * 0.7)
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x)
		owner_entity.target_velocity = orbit_dir * owner_entity.move_speed * 0.5 * move_strength * orbit_factor

func check_transitions():
	var owner_entity = state_machine.owner_entity
	var target = owner_entity._target_node
	
	# Return to idle if no target
	if not is_instance_valid(target):
		change_state("Idle")
		return
	
	# Check if can attack
	var distance = owner_entity.global_position.distance_to(target.global_position)
	
	# Check weapon range first if available
	if owner_entity.weapon_system and owner_entity.weapon_system.can_attack():
		var weapon_range = owner_entity.weapon_system.get_attack_range()
		if distance <= weapon_range and owner_entity.check_line_of_sight():
			change_state("Attack")
			return
	
	# Fallback to attack types
	for attack_type in owner_entity.attack_types:
		var attack = owner_entity.attack_types[attack_type]
		var attack_range = attack.get("range", 50.0)
		
		if distance <= attack_range and owner_entity.check_line_of_sight():
			if owner_entity.can_use_attack(attack_type):
				change_state("Attack")
				return
				
func handle_event(event_name: String, data = null) -> Variant:
	if event_name == "hit":
		# Maybe increase aggression temporarily
		var owner_entity = state_machine.owner_entity
		if owner_entity:
			owner_entity.aggression_level = min(owner_entity.aggression_level + 0.2, 1.0)
	return null
