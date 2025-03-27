# minimal_gravity_behavior.gd - Simplified for stability
class_name GravityBehavior
extends BehaviorBase

var gravity_factor = 0.5  # Strength of gravity effect

func _init_behavior():
	# Get gravity parameters - handle string/float conversion safely
	var param_value = get_param("gravity_factor", "0.5")
	
	# Handle potential format issues
	if typeof(param_value) == TYPE_STRING:
		# Remove any leading zeros before decimal point
		if param_value.begins_with("0") and param_value.length() > 1 and param_value[1] != '.':
			param_value = param_value.substr(1)
	
	# Convert to float safely
	gravity_factor = float(param_value)
	
	if DEBUG:
		print("Initialized gravity behavior with factor: ", gravity_factor)

func get_behavior_name() -> String:
	return "GravityBehavior"

func on_projectile_created(projectile):
	# Safety check
	if not is_instance_valid(projectile):
		return
	
	# Set gravity properties on the projectile
	projectile.set_meta("gravity_factor", gravity_factor)
	
	# Apply initial upward velocity - simple approach
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		projectile.velocity.y = -200  # Initial upward velocity
	
	if DEBUG:
		print("Applied gravity behavior to projectile")

# Handle gravity in physics processing - super simplified
func on_projectile_physics_process(projectile, delta):
	# Safety check
	if not is_instance_valid(projectile):
		return false
	
	# Apply gravity effect
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		# Use a fixed gravity value to avoid potential errors
		projectile.velocity.y += 980 * gravity_factor * delta
	
	# Let normal physics continue
	return false
