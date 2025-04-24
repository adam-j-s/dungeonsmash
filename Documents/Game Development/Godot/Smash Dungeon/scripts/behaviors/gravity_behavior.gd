# Gravity Behavior - JSON compatible version
class_name GravityBehavior
extends BehaviorBase

var gravity_factor = 0.5  # Strength of gravity effect
var initial_y_velocity = -250.0  # Initial upward velocity for arc trajectory
var use_engine_gravity = true  # Whether to use the engine's gravity constant

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get gravity factor from params
		if "gravity_strength" in behavior_params:
			gravity_factor = float(behavior_params.gravity_strength)
		elif "gravity_factor" in behavior_params:
			gravity_factor = float(behavior_params.gravity_factor)
		else:
			# Default value
			gravity_factor = float(get_param("gravity_factor", 0.5))
			
		# Get initial velocity if specified
		if "initial_y_velocity" in behavior_params:
			initial_y_velocity = float(behavior_params.initial_y_velocity)
	else:
		# Try flat structure parameters
		var raw_gravity = get_param("gravity_strength", get_param("gravity_factor", 0.5))
		
		# Handle different parameter types
		if typeof(raw_gravity) == TYPE_STRING:
			gravity_factor = float(raw_gravity)
		else:
			gravity_factor = float(raw_gravity)
	
	# Check weapon data for specific arc parameters
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for specific gravity settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is an arc or gravity behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "arc" or behavior_type == "gravity":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get gravity strength/factor
						if "gravity_strength" in behavior_params:
							gravity_factor = float(behavior_params.gravity_strength)
						elif "gravity_factor" in behavior_params:
							gravity_factor = float(behavior_params.gravity_factor)
	
	# Ensure reasonable values
	gravity_factor = max(0.1, gravity_factor)  # Minimum of 0.1
	
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
	
	# Get gravity factor from projectile if it has one set
	var factor = projectile.get_meta("gravity_factor", gravity_factor)
	
	# For cluster child projectiles, always apply consistent gravity
	if projectile.has_meta("is_cluster_child") and "velocity" in projectile:
		# Apply standard gravity
		projectile.velocity.y += 980 * factor * delta
		
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("Applied gravity to cluster child, velocity: ", projectile.velocity)
			
		# Let normal physics continue
		return false
	
	# Apply gravity effect to regular projectiles
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		# Apply gravity using the engine default gravity value
		projectile.velocity.y += 980 * factor * delta
		
		if DEBUG and Engine.get_frames_drawn() % 30 == 0:
			print("Applied gravity to projectile, velocity: ", projectile.velocity)
	
	# Let normal physics continue
	return false
