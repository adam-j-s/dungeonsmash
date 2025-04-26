# state_machines/states/idle_state.gd
class_name IdleState
extends State

# Configuration parameters
var wander_speed_multiplier = 0.4
var wander_interval_min = 1.5
var wander_interval_max = 4.0

# Runtime variables
var wander_timer = 0.0
var current_wander_direction = Vector2.ZERO

func enter():
	# Reset wander timer and pick a new direction
	pick_new_wander_target()

func physics_process(delta):
	# Update wander timer
	wander_timer -= delta
	if wander_timer <= 0:
		pick_new_wander_target()
	
	# Set movement velocity based on wandering direction
	if enemy.has_method("find_target"):
		enemy.find_target()
	
	# Set target velocity based on wandering direction
	if "target_velocity" in enemy:
		enemy.target_velocity = current_wander_direction * enemy.move_speed * wander_speed_multiplier

# Pick a new wandering direction
func pick_new_wander_target():
	var random_angle = randf_range(0, TAU) # TAU is 2 * PI
	current_wander_direction = Vector2.RIGHT.rotated(random_angle)
	wander_timer = randf_range(wander_interval_min, wander_interval_max)
	
	if "debug_mode" in enemy and enemy.debug_mode:
		print("%s: Picked new wander direction: %s for %.2f seconds" % 
			  [enemy.name, current_wander_direction.round(), wander_timer])

# Handle messages
func handle_message(msg, data=null):
	match msg:
		"target_acquired":
			# If we found a target, transition to chase state
			change_state("ChaseState")
