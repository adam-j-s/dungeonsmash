# standard_projectile.gd - Basic linear projectile
class_name StandardProjectile
extends ProjectileBase

func _ready():
	super._ready()
	# Standard projectile-specific setup
	
	# Visual setup - default is red for standard projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(1.0, 0.2, 0.2)  # Red color

# Override base movement to ensure linear motion
func _handle_movement(delta):
	# Simple linear movement
	if typeof(direction) == TYPE_VECTOR2:
		global_position += direction * speed * delta
		velocity = direction * speed
	else:
		global_position += Vector2(direction * speed, 0) * delta
		velocity = Vector2(direction * speed, 0)
	
	return true  # Movement handled
