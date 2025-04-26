# state_machines/states/stunned_state.gd
class_name StunnedState
extends State

var stun_duration = 1.0  # Default stun time
var stun_timer = 0.0

func enter():
	# Initialize stun timer
	stun_timer = stun_duration
	
	# Stop movement immediately when stunned
	enemy.target_velocity = Vector2.ZERO
	enemy.velocity = Vector2.ZERO

func physics_process(delta):
	# Update stun timer
	stun_timer -= delta
	
	# Check if stun has ended
	if stun_timer <= 0:
		if not is_instance_valid(enemy._target_node):
			change_state("ChaseState")
		else:
			change_state("IdleState")
	
	# Can't move while stunned
	enemy.target_velocity = Vector2.ZERO

# Allow message to set stun duration
func handle_message(msg, data=null):
	match msg:
		"stun":
			if typeof(data) == TYPE_FLOAT or typeof(data) == TYPE_INT:
				stun_duration = data
				stun_timer = stun_duration
