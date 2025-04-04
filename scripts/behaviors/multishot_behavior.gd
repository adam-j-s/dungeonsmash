# Multishot Behavior - Creates multiple projectiles with spread
class_name MultishotBehavior
extends BehaviorBase

# Configuration
var projectile_count = 3
var projectile_spread = 15.0  # Angle in degrees

func _init_behavior():
	# Get basic parameters
	var count_str = get_param("projectile_count", "3")
	projectile_count = int(count_str)
	
	# Check if the weapon already has a spread value in its base properties
	var weapon_spread = 0.0
	if weapon and "projectile_spread" in weapon.weapon_data:
		weapon_spread = float(weapon.weapon_data.projectile_spread)
	
	# Only use parameter spread if no weapon spread exists
	# Only use parameter spread if no weapon spread exists
	var spread_str = get_param("projectile_spread", "15.0")
	if weapon_spread > 0:
		projectile_spread = weapon_spread
	else:
		projectile_spread = float(spread_str)

	print("MULTISHOT INIT: count=", projectile_count, ", spread=", projectile_spread)

func get_behavior_name() -> String:
	return "MultishotBehavior"

func on_weapon_used():
	print("MULTISHOT DEBUG: on_weapon_used called")

# This overrides the number of projectiles fired
func get_actual_projectile_count():
	print("MULTISHOT DEBUG: Reporting actual projectile count: ", projectile_count)
	return projectile_count

# Called when the projectile is created
func on_projectile_created(projectile):
	print("MULTISHOT DEBUG: on_projectile_created called")
	print("MULTISHOT DEBUG: Projectile ID: ", projectile.get_instance_id())
	
	# Get index from metadata (set by ProjectileAttackStyle)
	var index = projectile.get_meta("projectile_index", -1)
	
	if index < 0:
		print("MULTISHOT DEBUG: No projectile index found, skipping spread adjustments")
		return
	
	print("MULTISHOT DEBUG: Processing projectile with index: ", index)
	
	# Calculate angle offset based on index relative to center
	var angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
	print("MULTISHOT DEBUG: Calculated angle offset: ", angle_offset)
	
	# Get base direction
	var base_direction
	if "direction" in projectile:
		base_direction = projectile.direction
	else:
		# Default to right if no direction
		base_direction = Vector2.RIGHT
	
	# Calculate position offset factor (from -1.0 to 1.0 for full spread)
	var offset_factor = 0
	if projectile_count > 1:
		offset_factor = (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
	
	# Apply position offset perpendicular to firing direction
	# Scale offset based on spread angle - wider spread = wider position separation
	var offset_scale = clamp(projectile_spread / 30.0, 0.5, 2.0)
	var perpendicular_offset = 15.0 * offset_factor * offset_scale
	
	# Calculate perpendicular direction
	var perp_direction
	if typeof(base_direction) == TYPE_VECTOR2:
		perp_direction = base_direction.rotated(PI/2).normalized()
	else:
		# Handle scalar direction
		perp_direction = Vector2(0, -1)  # Up direction
	
	# IMPORTANT: Apply position offset perpendicular to firing direction
	var position_offset = perp_direction * perpendicular_offset
	print("MULTISHOT DEBUG: Applying position offset: ", position_offset)
	projectile.global_position += position_offset
	
	# Calculate forward offset for additional depth perception
	var forward_offset = 5.0 * abs(offset_factor) # Outermost projectiles slightly ahead
	
	# Only apply forward offset if we have a vector direction
	if typeof(base_direction) == TYPE_VECTOR2:
		projectile.global_position += base_direction.normalized() * forward_offset
	
	# Apply angle offset to direction
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
	
	# Apply color for visual distinction
	apply_color(projectile, index)
	
	# Apply cluster bomb style position variations only for bezier projectiles
	if projectile.has_behavior("BezierProjectileBehavior"):
		apply_bezier_variations(projectile, index)

# Apply color for visual distinction
func apply_color(projectile, index):
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
	# Only apply if projectile has bezier behavior
	if not projectile.has_behavior("BezierProjectileBehavior"):
		print("MULTISHOT DEBUG: Projectile has no bezier behavior, skipping bezier variations")
		return
		
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
	
	print("MULTISHOT DEBUG: Applied bezier variation to projectile ", index, ":")
	print("  - Height factor: ", variation["height"])
	print("  - Distance factor: ", variation["distance"])
	print("  - Duration factor: ", variation["duration"])
