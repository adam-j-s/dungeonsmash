# arc_projectile_behavior.gd - Improved for more pronounced arcs
class_name ArcProjectileBehavior
extends BehaviorBase

var gravity_strength = 2500.0  # Strong gravity for pronounced arcs
var initial_y_velocity = -800.0  # Strong upward velocity for higher arcs

func _init_behavior():
	# Get custom gravity parameter with improved JSON structure handling
	var gravity_param = get_param("gravity_strength", "2500.0")
	
	# Handle parameter coming from different JSON formats
	if typeof(gravity_param) == TYPE_DICTIONARY and gravity_param.has("value"):
		gravity_strength = float(gravity_param.value)
	elif typeof(gravity_param) == TYPE_STRING:
		# Check if it might be a complex parameter string (legacy format)
		if "=" in gravity_param:
			var parts = gravity_param.split("=")
			if parts.size() > 1:
				gravity_strength = float(parts[1].strip_edges())
		else:
			gravity_strength = float(gravity_param)
	else:
		# Direct conversion for simple types
		gravity_strength = float(gravity_param)
	
	# Get initial velocity parameter with fallback
	var velocity_param = get_param("initial_y_velocity", "-800.0")
	if velocity_param != null and velocity_param != "":
		initial_y_velocity = float(velocity_param)
	
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
