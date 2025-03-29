# wild_bounce_behavior.gd - Creates unpredictable bounces with random angles
class_name WildBounceBehavior
extends BehaviorBase

var remaining_bounces = 0
var damping_factor = 0.9  # Higher energy retention than regular bounce
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces
var angle_randomness = 0.8  # How random the bounce angles are (0.0-1.0)

func _init_behavior():
	# Get parameters
	remaining_bounces = int(get_param("bounce_count", 5))  # More bounces by default
	damping_factor = float(get_param("damping_factor", 0.9))
	angle_randomness = float(get_param("angle_randomness", 0.8))

func get_behavior_name() -> String:
	return "WildBounceBehavior"

func on_projectile_created(projectile):
	# Reset remaining bounces for each new projectile
	remaining_bounces = int(get_param("bounce_count", 5))
	bounce_cooldown = 0.0  # Reset cooldown
	
	# Set properties on the projectile
	projectile.set_meta("bounce_count", remaining_bounces)
	
	# Special appearance - make it more vibrant and flashy
	projectile.modulate = Color(1.0, 0.7, 0.1)  # Orange-yellow glow
	
	if DEBUG:
		print("Wild Bounce behavior applied to projectile with bounce_count: ", remaining_bounces)

# Update cooldown in process
func on_projectile_process(projectile, delta):
	# Update cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	# Never take over movement
	return false

# Handle projectile collision
func on_projectile_collision(projectile, collision):
	# Skip if in cooldown
	if bounce_cooldown > 0.0:
		print("In bounce cooldown, skipping collision handling")
		return false
	
	# Get collider
	var collider = collision.get_collider()
	
	# Only bounce off walls, not characters
	if !collider.has_method("take_damage"):
		# If we have bounces remaining, bounce
		if remaining_bounces > 0:
			print("Wild Bounce behavior handling collision with wall, remaining bounces: ", remaining_bounces)
			
			# Tell the projectile not to destroy itself
			projectile.set_meta("cancel_destruction", true)
			
			# Set cooldown to prevent multiple bounces in rapid succession
			bounce_cooldown = 0.12  # Slightly faster than regular bounce
			
			# Get normal vector for bounce calculation
			var normal = collision.get_normal()
			
			# Calculate WILD reflection with randomness
			if typeof(projectile.direction) == TYPE_VECTOR2:
				# First calculate standard reflection
				var reflected = projectile.direction.reflect(normal)
				
				# Generate a random angle between -60 and +60 degrees
				var random_angle = (randf() - 0.5) * 2.0 * PI/3.0 * angle_randomness
				
				# Create a rotation matrix
				var rotation_matrix = Transform2D.IDENTITY.rotated(random_angle)
				
				# Apply the rotation to the reflected vector
				projectile.direction = (rotation_matrix * reflected).normalized()
				
				# Update velocity with new direction
				projectile.velocity = projectile.direction * projectile.speed * damping_factor
			else:
				# For scalar direction, add randomness to the inversion
				projectile.direction = -projectile.direction
				if randf() < 0.5:  # 50% chance to add a y component
					# Convert scalar to vector with random vertical component
					var y_component = (randf() - 0.5) * 2.0  # Random between -1 and 1
					projectile.direction = Vector2(projectile.direction, y_component).normalized()
					projectile.velocity = projectile.direction * projectile.speed * damping_factor
				else:
					# Just use the inverted scalar
					projectile.velocity = Vector2(projectile.direction * projectile.speed * damping_factor, 0)
			
			# Move away just enough to prevent getting stuck
			projectile.global_position += normal * 10
			
			# CRITICAL: Clear hit targets to allow hitting again after bounce
			if "hit_targets" in projectile:
				projectile.hit_targets.clear()
				print("Cleared hit targets array - projectile can damage targets again!")
			
			# Decrement bounce counter
			remaining_bounces -= 1
			
			# Visual feedback - change color slightly each bounce for visual variety
			var r = 0.7 + randf() * 0.3
			var g = 0.3 + randf() * 0.6
			var b = 0.1 + randf() * 0.2
			projectile.modulate = Color(r, g, b) * 1.5  # Make it brighter
			
			# Flash effect
			var original_modulate = projectile.modulate
			projectile.modulate = Color(2.0, 2.0, 2.0)  # Bright flash
			
			# Create timer to restore color
			var timer = Timer.new()
			timer.wait_time = 0.08  # Faster flash than regular bounce
			timer.one_shot = true
			projectile.add_child(timer)
			timer.timeout.connect(func():
				projectile.modulate = original_modulate
				timer.queue_free()
			)
			timer.start()
			
			print("Projectile wild bounced! New direction: ", projectile.direction, " velocity: ", projectile.velocity)
			return true
		else:
			# No bounces remaining, allow projectile to be destroyed
			print("No bounces remaining, allowing destruction")
			projectile.set_meta("cancel_destruction", false)
			return false
	else:
		# This is a collision with a character
		# Make sure we allow destruction so damage is applied
		projectile.set_meta("cancel_destruction", false)
	
	# Don't handle character collisions directly
	return false
