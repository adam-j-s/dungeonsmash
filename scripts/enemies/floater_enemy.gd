# floater_enemy.gd
extends BaseEnemy

@export var hover_amplitude = 30.0
@export var hover_frequency = 2.0

var starting_y = 0.0
var time_passed = 0.0

func _ready():
	# Store initial Y position for hovering
	starting_y = global_position.y

func _physics_process(delta):
	time_passed += delta
	
	# Move toward player horizontally
	if _target_node:
		var dir_x = sign(_target_node.global_position.x - global_position.x)
		velocity.x = dir_x * move_speed
	
	# Hover up and down
	var hover_offset = sin(time_passed * hover_frequency) * hover_amplitude
	global_position.y = starting_y + hover_offset
	
	# Move horizontally only
	velocity.y = 0
	global_position.x += velocity.x * delta
