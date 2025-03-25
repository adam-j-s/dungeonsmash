#Makes projectiles affected by gravity
class_name GravityBehavior
extends BehaviorBase

var gravity_factor = 0.0  # Strength of gravity effect
var vertical_velocity = 0.0  # Current vertical velocity

func _init_behavior():
	# Get gravity parameters
	gravity_factor = float(get_param("gravity_factor", 0.5))
	vertical_velocity = float(get_param("vertical_velocity", -100.0))  # Initial upward velocity
	
	if DEBUG:
		print("Initialized gravity behavior with factor: ", gravity_factor)

func get_behavior_name() -> String:
	return "GravityBehavior"

func on_projectile_created(projectile):
	# Set gravity properties on the projectile
	projectile.set_meta("gravity_factor", gravity_factor)
	projectile.set_meta("vertical_velocity", vertical_velocity)
	
	if DEBUG:
		print("Applied gravity behavior to projectile with factor: ", gravity_factor)

# Handle gravity in physics processing
func on_projectile_physics_process(projectile, delta):
	# Skip if projectile already handles gravity
	if "gravity_factor" in projectile and projectile.has_method("apply_gravity"):
		return false  # Let projectile handle it
	
	# Get base gravity from project settings
	var base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	# Apply gravity to velocity
	vertical_velocity += base_gravity * gravity_factor * delta
	
	# Get current projectile velocity
	var current_velocity = projectile.velocity
	
	# Adjust for vertical component
	if typeof(current_velocity) == TYPE_VECTOR2:
		# If velocity is a Vector2, add vertical component
		current_velocity.y += vertical_velocity * delta
		projectile.velocity = current_velocity
		
		# Update position directly for more reliable movement
		projectile.global_position += Vector2(0, vertical_velocity * delta)
		
		return true  # Handled movement
	
	return false  # Let standard movement handle it

