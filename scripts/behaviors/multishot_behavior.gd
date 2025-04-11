# Multishot Behavior - Creates multiple projectiles with spread - JSON compatible
class_name MultishotBehavior
extends BehaviorBase

# Configuration
var projectile_count = 3
var projectile_spread = 15.0  # Angle in degrees
var position_spread = 15.0  # Perpendicular offset
var enable_color_variation = true  # Whether to apply colors
var enable_bezier_variation = true  # Whether to apply bezier variations

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get projectile count
		if "projectile_count" in behavior_params:
			projectile_count = int(behavior_params.projectile_count)
		else:
			projectile_count = int(get_param("projectile_count", 3))
		
		# Get projectile spread
		if "projectile_spread" in behavior_params:
			projectile_spread = float(behavior_params.projectile_spread)
		else:
			projectile_spread = float(get_param("projectile_spread", 15.0))
			
		# Get position spread
		if "position_spread" in behavior_params:
			position_spread = float(behavior_params.position_spread)
		else:
			position_spread = float(get_param("position_spread", 15.0))
			
		# Optional flags
		if "enable_color_variation" in behavior_params:
			enable_color_variation = bool(behavior_params.enable_color_variation)
		if "enable_bezier_variation" in behavior_params:
			enable_bezier_variation = bool(behavior_params.enable_bezier_variation)
	else:
		# Fallback to flat parameters
		projectile_count = int(get_param("projectile_count", 3))
		projectile_spread = float(get_param("projectile_spread", 15.0))
		position_spread = float(get_param("position_spread", 15.0))
	
	# Check weapon data for direct properties
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for direct multishot properties in weapon data
		if "projectile_count" in weapon_data:
			projectile_count = int(weapon_data.projectile_count)
		if "projectile_spread" in weapon_data:
			projectile_spread = float(weapon_data.projectile_spread)
		
		# Check for specific settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a multishot behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "multishot":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get projectile count if specified
						if "projectile_count" in behavior_params:
							projectile_count = int(behavior_params.projectile_count)
						
						# Get projectile spread if specified
						if "projectile_spread" in behavior_params:
							projectile_spread = float(behavior_params.projectile_spread)
	
	# Ensure reasonable values
	projectile_count = max(1, projectile_count)  # Minimum of 1 projectile
	projectile_spread = max(0.0, projectile_spread)  # Non-negative spread
	
	if DEBUG:
		print("MULTISHOT INIT: count=", projectile_count, ", spread=", projectile_spread)
		print("MULTISHOT INIT: position_spread=", position_spread)

func get_behavior_name() -> String:
	return "MultishotBehavior"

func on_weapon_used():
	if DEBUG:
		print("MULTISHOT DEBUG: on_weapon_used called")

# This overrides the number of projectiles fired
func get_actual_projectile_count():
	if DEBUG:
		print("MULTISHOT DEBUG: Reporting actual projectile count: ", projectile_count)
	return projectile_count

# Called when the projectile is created
func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
		
	if DEBUG:
		print("MULTISHOT DEBUG: on_projectile_created called")
		print("MULTISHOT DEBUG: Projectile ID: ", projectile.get_instance_id())
	
	# Get index from metadata (set by ProjectileAttackStyle)
	var index = projectile.get_meta("projectile_index", -1)
	
	if index < 0:
		if DEBUG:
			print("MULTISHOT DEBUG: No projectile index found, skipping spread adjustments")
		return
	
	if DEBUG:
		print("MULTISHOT DEBUG: Processing projectile with index: ", index)
	
	# Calculate angle offset based on index relative to center
	var angle_offset = 0.0
	if projectile_count > 1:
		angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
	
	if DEBUG:
		print("MULTISHOT DEBUG: Calculated angle offset: ", angle_offset)
	
	# Get base direction
	var base_direction
	if "direction" in projectile:
		base_direction = projectile.direction
	else:
		# Default to right if no direction
		base_direction = Vector2.RIGHT
	
	# Calculate position offset factor (from -1.0 to 1.0 for full spread)
	var offset_factor = 0.0
	if projectile_count > 1:
		offset_factor = (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
	
	# Apply position offset perpendicular to firing direction
	# Scale offset based on spread angle - wider spread = wider position separation
	var offset_scale = clamp(projectile_spread / 30.0, 0.5, 2.0)
	var perpendicular_offset = position_spread * offset_factor * offset_scale
	
	# Calculate perpendicular direction
	var perp_direction
	if typeof(base_direction) == TYPE_VECTOR2:
		perp_direction = base_direction.rotated(PI/2).normalized()
	else:
		# Handle scalar direction
		perp_direction = Vector2(0, -1)  # Up direction
	
	# IMPORTANT: Apply position offset perpendicular to firing direction
	var position_offset = perp_direction * perpendicular_offset
	
	if DEBUG:
		print("MULTISHOT DEBUG: Applying position offset: ", position_offset)
	
	if is_instance_valid(projectile):
		projectile.global_position += position_offset
	
	# Calculate forward offset for additional depth perception
	var forward_offset = 5.0 * abs(offset_factor) # Outermost projectiles slightly ahead
	
	# Only apply forward offset if we have a vector direction and valid projectile
	if typeof(base_direction) == TYPE_VECTOR2 and is_instance_valid(projectile):
		projectile.global_position += base_direction.normalized() * forward_offset
	
	# Apply angle offset to direction if projectile is valid
	if !is_instance_valid(projectile):
		return
		
	if typeof(base_direction) == TYPE_VECTOR2:
		var new_direction = base_direction.rotated(deg_to_rad(angle_offset))
		projectile.direction = new_direction
		
		# Also update velocity if present
		if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
			var speed = projectile.velocity.length()
			projectile.velocity = new_direction * speed
	else:
		# Handle scalar direction case
		var dir_vector = Vector2(base_direction, 0)
		var new_vector = dir_vector.rotated(deg_to_rad(angle_offset))
		
		# Keep the direction as scalar if it was scalar originally
		projectile.direction = sign(new_vector.x)
		
		# Update velocity if present
		if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
			var speed = projectile.velocity.length()
			projectile.velocity = new_vector.normalized() * speed
	
	# Apply color for visual distinction if enabled
	if enable_color_variation:
		apply_color(projectile, index)
	
	# Apply cluster bomb style position variations only for bezier projectiles if enabled
	if enable_bezier_variation and projectile.has_behavior("BezierProjectileBehavior"):
		apply_bezier_variations(projectile, index)

# Apply color for visual distinction
func apply_color(projectile, index):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
		
	# Add color variations 
	var colors = [
		Color(1.0, 0.5, 0.0),  # Orange
		Color(0.0, 0.8, 0.0),  # Green
		Color(0.0, 0.4, 1.0),  # Blue
		Color(0.8, 0.2, 0.8),  # Purple
		Color(0.8, 0.8, 0.2)   # Yellow
	]
	
	# Apply color to make projectiles visually distinct
	projectile.modulate = colors[index % colors.size()]

# Apply special variations for bezier curves
func apply_bezier_variations(projectile, index):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
		
	# Only apply if projectile has bezier behavior
	if not projectile.has_behavior("BezierProjectileBehavior"):
		if DEBUG:
			print("MULTISHOT DEBUG: Projectile has no bezier behavior, skipping bezier variations")
		return
		
	if DEBUG:
		print("MULTISHOT DEBUG: Applying bezier variations")
	
	# Define different variations like in the original cluster bomb
	var variation_factors = [
		{"height": 1.6, "distance": 1.4, "duration": 0.9},  # High, far, fast
		{"height": 1.0, "distance": 1.0, "duration": 1.0},  # Medium
		{"height": 0.7, "distance": 0.6, "duration": 1.2}   # Low, close, slow
	]
	
	# Apply significant variations to create distinct arcs
	var variation = variation_factors[index % variation_factors.size()]
	
	# Add bezier variation metadata for the bezier behavior to use
	projectile.set_meta("bezier_height_factor", variation["height"])
	projectile.set_meta("bezier_distance_factor", variation["distance"])
	projectile.set_meta("bezier_duration_factor", variation["duration"])
	
	if DEBUG:
		print("MULTISHOT DEBUG: Applied bezier variation to projectile ", index, ":")
		print("  - Height factor: ", variation["height"])
		print("  - Distance factor: ", variation["distance"])
		print("  - Duration factor: ", variation["duration"])
