# bouncer_enemy.gd
extends BaseEnemy

@export var direction = 1.0  # 1 = right, -1 = left

var last_position = Vector2.ZERO
var stuck_timer = 0.0

func _ready():
	super._ready() # Call parent _ready if it exists
	last_position = global_position

func _physics_process(delta):
	# Apply gravity
	velocity.y += gravity * delta
	
	# Move horizontally - using parent class move_speed
	velocity.x = move_speed * direction
	move_and_slide()
	
	# Check if we're stuck
	var distance_moved = global_position.distance_to(last_position)
	if distance_moved < 1.0 and is_on_floor():
		stuck_timer += delta
		if stuck_timer > 0.5:  # If stuck for half a second
			direction *= -1
			stuck_timer = 0
	else:
		stuck_timer = 0
		
	last_position = global_position
	
# Add set_target method if needed by your battle arena
func set_target(target):
	_target_node = target
