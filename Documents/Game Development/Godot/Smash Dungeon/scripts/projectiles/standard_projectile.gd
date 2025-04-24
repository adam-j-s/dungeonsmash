# Basic linear projectile
class_name StandardProjectile
extends ProjectileBase

func _ready():
	super._ready()
	# Standard projectile-specific setup
	
	# Visual setup - default is red for standard projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(1.0, 0.2, 0.2)  # Red color

# Override the new calculation method instead of _handle_movement
func _calculate_movement(delta):
	# Simple linear movement - only set velocity
	if typeof(direction) == TYPE_VECTOR2:
		velocity = direction * speed
	else:
		velocity = Vector2(direction * speed, 0)
	
	return true  # Movement handled

# Keep original method for backward compatibility
# But make it use our new approach
func _handle_movement(delta):
	# Delegate to the new method
	_calculate_movement(delta)
	
	# The actual movement will happen in _physics_process
	return true
