# surface_movement_component.gd
extends Node
class_name SurfaceMovementComponent

@export var surface_speed: float = 70.0
@export var corner_behavior: int = 0 # 0=follow, 1=reverse, 2=jump
@export var jump_force: Vector2 = Vector2(150, -150)
@export var change_direction_chance: float = 0.02
@export var raycast_distance: float = 32.0
@export var stuck_threshold: float = 1.0

@onready var owner_entity = get_parent()
@onready var ray_front = $RayCast2D_Front
@onready var ray_down = $RayCast2D_Down

var direction: int = 1
var last_position: Vector2
var stuck_timer: float = 0.0

func _ready():
	if not ray_front or not ray_down:
		create_raycasts()
	
	last_position = owner_entity.global_position

func _physics_process(delta):
	# Skip if state machine is handling movement
	if owner_entity.state_machine and owner_entity.state_machine.current_state and owner_entity.state_machine.current_state.name != "Idle":
		return
	
	update_raycasts()
	apply_surface_movement(delta)
	check_stuck(delta)
	
	# Random direction change
	if randf() < change_direction_chance * delta:
		direction *= -1

func create_raycasts():
	ray_front = RayCast2D.new()
	ray_front.name = "RayCast2D_Front"
	ray_front.target_position = Vector2(raycast_distance, 0)
	ray_front.enabled = true
	add_child(ray_front)
	
	ray_down = RayCast2D.new()
	ray_down.name = "RayCast2D_Down"
	ray_down.target_position = Vector2(0, raycast_distance)
	ray_down.enabled = true
	add_child(ray_down)

func update_raycasts():
	ray_front.target_position = Vector2(direction * raycast_distance, 0)
	ray_down.target_position = Vector2(0, raycast_distance)

func apply_surface_movement(delta):
	var movement_vector = Vector2.ZERO
	
	if ray_down.is_colliding():
		# Moving on floor
		movement_vector = Vector2(direction * surface_speed, 0)
	elif ray_front.is_colliding():
		# Moving on wall
		movement_vector = Vector2(0, direction * surface_speed)
	else:
		# In corner or air, handle based on corner behavior
		match corner_behavior:
			0: # Follow corner
				movement_vector = Vector2(direction * surface_speed * 0.7, direction * surface_speed * 0.7)
			1: # Reverse direction
				direction *= -1
				movement_vector = Vector2(direction * surface_speed, 0)
			2: # Jump
				movement_vector = jump_force * Vector2(direction, 1)
	
	# Apply movement
	owner_entity.target_velocity = movement_vector

func check_stuck(delta):
	var current_pos = owner_entity.global_position
	var movement = current_pos.distance_to(last_position)
	
	if movement < 1.0:
		stuck_timer += delta
		if stuck_timer > stuck_threshold:
			direction *= -1
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	
	last_position = current_pos
