# arc_projectile_behavior.gd - Improved for more pronounced arcs
class_name ArcProjectileBehavior
extends BehaviorBase

var gravity_strength = 2500.0  # Strong gravity for pronounced arcs
var initial_y_velocity = -800.0  # Strong upward velocity for higher arcs

func _init_behavior():
	# Get custom gravity parameter
	var gravity_param = get_param("gravity_strength", "2500.0")
	
	# Parse parameters
	gravity_strength = float(gravity_param)
	
	if DEBUG:
		print("Initialized arc behavior with gravity: ", gravity_strength)
		print("Initial Y velocity: ", initial_y_velocity)

func get_behavior_name() -> String:
	return "ArcProjectileBehavior"

# Set up the projectile with arc movement
func on_projectile_created(projectile):
	# Skip if already a child projectile with its own physics
	if projectile.has_meta("is_child_bomb"):
		return
		
	# Set metadata
	projectile.set_meta("gravity_strength", gravity_strength)
	projectile.set_meta("is_arc_projectile", true)
	
	# Determine direction
	var dir_x = 1
	
	# Get direction from projectile
	if "direction" in projectile:
		if typeof(projectile.direction) == TYPE_VECTOR2:
			dir_x = sign(projectile.direction.x)
		else:
			dir_x = sign(projectile.direction)
	elif "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		dir_x = sign(projectile.velocity.x)
	
	# Apply initial velocity with proper direction
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		var speed = abs(projectile.velocity.x)
		projectile.velocity = Vector2(speed * dir_x, initial_y_velocity)
		
		if DEBUG:
			print("Applied arc velocity to projectile: ", projectile.velocity, " with direction ", dir_x)
	
	# Mark projectile to preserve vertical component during movement
	projectile.set_meta("preserve_y_velocity", true)
	
	if DEBUG:
		print("Applied arc behavior to projectile")

# Apply gravity in physics processing
func on_projectile_physics_process(projectile, delta):
	# Skip if this isn't an arc projectile or if it's a child bomb
	if !projectile.has_meta("is_arc_projectile") or projectile.has_meta("is_child_bomb"):
		return false
		
	# Apply gravity
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		projectile.velocity.y += gravity_strength * delta
		
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("Applied gravity to projectile, velocity: ", projectile.velocity)
	
	# Let normal physics continue
	return false
