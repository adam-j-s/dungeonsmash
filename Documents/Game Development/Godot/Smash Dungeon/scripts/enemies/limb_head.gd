# LimbHead.gd (Revised - No Visuals Here)
extends CharacterBody2D
class_name LimbHeadEnemy

# --- Variables ---
@export var move_speed: float = 80.0
@export var acceleration: float = 15.0
# @export var turn_speed: float = 5.0 # No visual polygon to turn anymore
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _target_node: Node2D = null
var target_velocity: Vector2 = Vector2.ZERO

# @onready var polygon_node: Polygon2D = $HeadPolygon # REMOVED
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Removed procedural appearance variables

func _ready():
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	set_physics_process(true)
	# Adjust collision shape radius based on desired head size
	if collision_shape and collision_shape.shape is CircleShape2D:
		# You might want to pass the desired radius from the main limb script
		# Or set a default here
		collision_shape.shape.radius = 12.0 # Example radius


func _physics_process(delta: float):
	# Apply gravity
	velocity.y += gravity * delta

	# --- Target Following ---
	if is_instance_valid(_target_node):
		var direction_to_target = (_target_node.global_position - global_position).normalized()
		target_velocity = direction_to_target * move_speed
	else:
		target_velocity = Vector2.ZERO

	# --- Apply Movement ---
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * 60)
	move_and_slide()

# --- Public Methods ---
func set_target(target: Node2D):
	_target_node = target

# Removed setup_head and generate_shape

# Add collision detection / damage dealing here if needed
# func _on_body_entered(body): ...
