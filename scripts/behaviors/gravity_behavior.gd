# Gravity Behavior
class_name GravityBehavior
extends BehaviorBase

var gravity_factor = 0.5  # Strength of gravity effect
var initial_y_velocity = -200.0  # Initial upward velocity for arc trajectory

# Helper function for parsing parameters - included directly in this class
func parse_param_safely(param_string, param_name, default_value):
	# Skip if not a string
	if typeof(param_string) != TYPE_STRING:
		return default_value
		
	# First, check if we have a simple value
	if "," not in param_string and ":" not in param_string:
		return param_string.strip_edges()
	
	# Handle complex parameter string
	# Format might be like "gravity_factor=0.5,multishot:projectile_count=3,..."
	
	# Split by commas
	var parts = param_string.split(",")
	for part in parts:
		part = part.strip_edges()
		# Look for our parameter name
		if part.begins_with(param_name + "="):
			var value = part.split("=")[1].strip_edges()
			return value
			
	# If we get here, check for the parameter in the entire string
	# This catches cases where the format is complex
	if param_string.find(param_name + "=") != -1:
		var start_pos = param_string.find(param_name + "=") + param_name.length() + 1
		var end_pos = param_string.find(",", start_pos)
		if end_pos == -1:  # If no comma after the value
			end_pos = param_string.length()
		var value = param_string.substr(start_pos, end_pos - start_pos).strip_edges()
		return value
	
	# Parameter not found
	return default_value

func _init_behavior():
	# Get gravity parameters using our safe parsing
	var raw_param = get_param("gravity_factor", "0.5")
	var param_value = parse_param_safely(raw_param, "gravity_factor", "0.5")
	
	# Convert to float safely
	gravity_factor = float(param_value)
	
	# Get initial velocity with a default that creates a proper arc
	initial_y_velocity = -250.0  # Stronger upward velocity
	
	if DEBUG:
		print("Initialized gravity behavior with factor: ", gravity_factor)
		print("Initial Y velocity: ", initial_y_velocity)

func get_behavior_name() -> String:
	return "GravityBehavior"

func on_projectile_created(projectile):
	# Safety check
	if not is_instance_valid(projectile):
		return
	
	# Skip for child projectiles that already have velocity set
	if projectile.has_meta("is_cluster_child"):
		# Just set the gravity factor, velocity is already set
		projectile.set_meta("gravity_factor", gravity_factor)
		return
	
	# Set gravity properties on the projectile
	projectile.set_meta("gravity_factor", gravity_factor)
	
	# Apply initial upward velocity for non-cluster projectiles
	# For cluster bombs, this is handled by the multishot behavior
	if !projectile.has_meta("is_carrier") and "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		# Store the horizontal component
		var x_velocity = projectile.velocity.x
		
		# Apply upward velocity
		projectile.velocity.y = initial_y_velocity
		
		if DEBUG:
			print("Applied gravity behavior to projectile with velocity: ", projectile.velocity)
	
	# Mark the projectile to preserve Y velocity during movement calculations
	projectile.set_meta("preserve_y_velocity", true)

# Handle gravity in physics processing - consistent application
func on_projectile_physics_process(projectile, delta):
	# Safety check
	if not is_instance_valid(projectile):
		return false
	
	# For cluster child projectiles, always apply consistent gravity
	if projectile.has_meta("is_cluster_child") and "velocity" in projectile:
		# Apply standard gravity
		projectile.velocity.y += 980 * gravity_factor * delta
		
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("Applied gravity to cluster child, velocity: ", projectile.velocity)
			
		# Let normal physics continue
		return false
	
	# Apply gravity effect to regular projectiles
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		# Apply gravity using the engine default gravity value
		projectile.velocity.y += 980 * gravity_factor * delta
		
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("Applied gravity to projectile, velocity: ", projectile.velocity)
	
	# Let normal physics continue
	return false
