# idle_state.gd
extends State
class_name IdleState

@export var wander_speed_multiplier: float = 0.4
@export var wander_interval_min: float = 1.5
@export var wander_interval_max: float = 4.0
@export var detection_range: float = 300.0

var wander_timer: float = 0.0
var current_direction: Vector2 = Vector2.ZERO

func enter():
	pick_new_wander_direction()

func process(delta):
	# Decrease timer
	wander_timer -= delta
	
	# Pick new direction when timer expires
	if wander_timer <= 0:
		pick_new_wander_direction()
	
	# Apply movement
	var owner_entity = state_machine.owner_entity
	owner_entity.target_velocity = current_direction * owner_entity.move_speed * wander_speed_multiplier

func check_transitions():
	# Check for player in detection range
	var target = find_target()
	if target:
		change_state("Chase")

func pick_new_wander_direction():
	var random_angle = randf_range(0, TAU)
	current_direction = Vector2.RIGHT.rotated(random_angle)
	wander_timer = randf_range(wander_interval_min, wander_interval_max)

func find_target():
	var owner_entity = state_machine.owner_entity
	
	# Get all players
	var players = get_tree().get_nodes_in_group("players")
	
	for player in players:
		var dist = owner_entity.global_position.distance_to(player.global_position)
		if dist <= detection_range and owner_entity.check_line_of_sight_to_point(player.global_position):
			# Set target and return
			owner_entity._target_node = player
			return player
	
	return null

func handle_event(event_name: String, data = null) -> Variant:
	if event_name == "hit":
		# Transition to chase if hit
		change_state("Chase")
	return null
