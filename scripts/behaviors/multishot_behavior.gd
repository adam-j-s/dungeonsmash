# Multishot Behavior - Creates multiple projectiles with spread
class_name MultishotBehavior
extends BehaviorBase

# Configuration
var projectile_count = 3
var projectile_spread = 15.0  # Angle in degrees

func _init_behavior():
	# Get basic parameters
	var count_str = get_param("projectile_count", "3")
	var spread_str = get_param("projectile_spread", "15.0")
	
	# Parse parameters
	projectile_count = int(count_str)
	projectile_spread = float(spread_str)
	
	if DEBUG:
		print("Initialized multishot behavior with count: ", projectile_count, " spread: ", projectile_spread)

func get_behavior_name() -> String:
	return "MultishotBehavior"

func on_weapon_used():
	if DEBUG:
		print("MultishotBehavior: weapon used")

# This overrides the number of projectiles fired
func get_actual_projectile_count():
	return projectile_count

# Called when the projectile is created
func on_projectile_created(projectile):
	# Find multishot index from metadata
	var index = projectile.get_meta("multishot_index", -1)
	
	if DEBUG:
		print("MULTISHOT DEBUG: Processing projectile with index: ", index)
	
	if index >= 0:
		# Calculate angle offset based on index relative to center
		var angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
		
		# Store the angle for other behaviors to use
		projectile.set_meta("angle_offset", angle_offset)
		
		if DEBUG:
			print("MULTISHOT DEBUG: Applied angle offset: ", angle_offset, " degrees to projectile ", index)
			
		# Get base direction
		var base_direction
		if "direction" in projectile:
			base_direction = projectile.direction
		else:
			# Default to right if no direction
			base_direction = Vector2.RIGHT
			
		# Apply angle offset to direction
		if typeof(base_direction) == TYPE_VECTOR2:
			var new_direction = base_direction.rotated(deg_to_rad(angle_offset))
			projectile.direction = new_direction
			
			# Also update velocity if present
			if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
				var speed = projectile.velocity.length()
				projectile.velocity = new_direction * speed
				
			if DEBUG:
				print("MULTISHOT DEBUG: Adjusted direction to: ", projectile.direction)
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
				
			if DEBUG:
				print("MULTISHOT DEBUG: Adjusted scalar direction to: ", projectile.direction)
		
		# Apply cluster bomb style position variations for better separation
		apply_bezier_variations(projectile, index)

# Apply special variations for bezier curves
func apply_bezier_variations(projectile, index):
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
	
	# Add color variations like in the original cluster bomb
	var colors = [
		Color(1.0, 0.5, 0.0),  # Orange
		Color(0.0, 0.8, 0.0),  # Green
		Color(0.0, 0.4, 1.0)   # Blue
	]
	
	# Apply color to any visual components
	projectile.modulate = colors[index % colors.size()]
	
	if DEBUG:
		print("MULTISHOT DEBUG: Applied bezier variation to projectile ", index, ":")
		print("  - Height factor: ", variation["height"])
		print("  - Distance factor: ", variation["distance"])
		print("  - Duration factor: ", variation["duration"])
		print("  - Color: ", colors[index % colors.size()])
