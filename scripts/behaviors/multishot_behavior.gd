# Multishot Behavior
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

# This overrides the number of projectiles fired
func get_actual_projectile_count():
	return projectile_count

# Called when the projectile is created
func on_projectile_created(projectile):
	# Set metadata to track which multishot projectile this is
	var index = projectile.get_meta("multishot_index", -1)
	if index >= 0:
		# This is a multishot child - calculate angle offset
		var angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
		
		if DEBUG:
			print("Multishot projectile ", index, " angle offset: ", angle_offset)
			
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
				print("Multishot projectile ", index, " adjusted direction to: ", projectile.direction)
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
				print("Multishot projectile ", index, " adjusted direction to: ", projectile.direction)

# When the weapon attack style creates multiple projectiles,
# this helps position them correctly
func setup_projectile(projectile, index, total_count):
	# Store which projectile this is in the spread
	projectile.set_meta("multishot_index", index)
	
	# Calculate angle offset from center
	var angle_offset = projectile_spread * (index - (total_count-1)/2.0) / ((total_count-1)/2.0)
	
	if DEBUG:
		print("Setting up multishot projectile ", index, " of ", total_count, " with angle offset: ", angle_offset)
	
	return projectile
