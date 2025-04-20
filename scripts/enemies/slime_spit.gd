# slime_spit.gd
extends Area2D

@export var speed = 300
@export var lifetime = 2.0

var direction = Vector2.RIGHT
var damage = 5
var source_entity = null  # Changed from owner_node

func _ready():
	# Connect signal
	body_entered.connect(_on_body_entered)
	
	# Create the visual if needed
	create_visual()
	
	# Start lifetime timer
	if lifetime > 0:
		var timer = get_node_or_null("Timer")
		if timer:
			timer.wait_time = lifetime
			timer.one_shot = true
			timer.timeout.connect(queue_free)
			timer.start()
		else:
			# If no timer node, create a timed callback
			var auto_destroy_timer = get_tree().create_timer(lifetime)
			auto_destroy_timer.timeout.connect(queue_free)

func create_visual():
	var polygon = get_node_or_null("Polygon2D")
	if polygon:
		# Create a simple droplet shape
		var points = [
			Vector2(0, -8),   # Top
			Vector2(6, 0),    # Right
			Vector2(4, 6),    # Bottom-right
			Vector2(0, 8),    # Bottom
			Vector2(-4, 6),   # Bottom-left
			Vector2(-6, 0)    # Left
		]
		polygon.polygon = points
		
		# Set the color (blue-green for slime)
		polygon.color = Color(0.2, 0.7, 0.8, 0.8)

func _physics_process(delta):
	# Move the projectile
	position += direction * speed * delta
	
	# Set rotation to match direction
	rotation = direction.angle()

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()
	rotation = direction.angle()

func set_damage(new_damage: int):
	damage = new_damage

func set_source(node): 
	source_entity = node  

func _on_body_entered(body):
	# Don't hit the source entity
	if body == source_entity:
		return
		
	# Apply damage if possible
	if body.has_method("take_damage"):
		body.take_damage(damage, direction, 100)
		
	# Destroy the projectile
	queue_free()
