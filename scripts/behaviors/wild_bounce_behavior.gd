# Wild Bounce Behavior - Creates unpredictable bounces with random angles - JSON compatible
class_name WildBounceBehavior
extends BehaviorBase

var remaining_bounces = 0
var damping_factor = 0.9  # Higher energy retention than regular bounce
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces
var angle_randomness = 0.8  # How random the bounce angles are (0.0-1.0)
var reset_targets = true   # Whether to clear hit targets after bounce
var speed_boost = 0.0      # Optional speed boost on each bounce

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get bounce count
		if "bounce_count" in behavior_params:
			remaining_bounces = int(behavior_params.bounce_count)
		else:
			remaining_bounces = int(get_param("bounce_count", 5))
		
		# Get damping factor
		if "damping_factor" in behavior_params:
			damping_factor = float(behavior_params.damping_factor)
		else:
			damping_factor = float(get_param("damping_factor", 0.9))
			
		# Get angle randomness
		if "angle_randomness" in behavior_params:
			angle_randomness = float(behavior_params.angle_randomness)
		else:
			angle_randomness = float(get_param("angle_randomness", 0.8))
			
		# Get optional reset targets setting
		if "reset_targets" in behavior_params:
			reset_targets = bool(behavior_params.reset_targets)
		else:
			reset_targets = bool(get_param("reset_targets", true))
			
		# Get optional speed boost
		if "speed_boost" in behavior_params:
			speed_boost = float(behavior_params.speed_boost)
		else:
			speed_boost = float(get_param("speed_boost", 0.0))
	else:
		# Fallback to flat parameters
		remaining_bounces = int(get_param("bounce_count", 5))
		damping_factor = float(get_param("damping_factor", 0.9))
		angle_randomness = float(get_param("angle_randomness", 0.8))
		reset_targets = bool(get_param("reset_targets", true))
		speed_boost = float(get_param("speed_boost", 0.0))
	
	# Check weapon data for specific bounce settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for specific settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a wild bounce behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "wild_bounce":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get parameters if specified
						if "bounce_count" in behavior_params:
							remaining_bounces = int(behavior_params.bounce_count)
						if "angle_randomness" in behavior_params:
							angle_randomness = float(behavior_params.angle_randomness)
	
	# Ensure reasonable values
	remaining_bounces = max(1, remaining_bounces)  # Minimum of 1 bounce
	damping_factor = clamp(damping_factor, 0.5, 1.5)  # Reasonable damping range (allows boost)
	angle_randomness = clamp(angle_randomness, 0.0, 1.0)  # 0-1 range
	speed_boost = clamp(speed_boost, 0.0, 0.2)  # Reasonable boost range
	
	if DEBUG:
		print("Initialized Wild Bounce behavior with bounce count: ", remaining_bounces)
		print("Damping factor: ", damping_factor)
		print("Angle randomness: ", angle_randomness)
		if speed_boost > 0:
			print("Speed boost per bounce: ", speed_boost)

func get_behavior_name() -> String:
	return "WildBounceBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
		
	# Reset remaining bounces for each new projectile
	remaining_bounces = int(get_param("bounce_count", 5))
	bounce_cooldown = 0.0  # Reset cooldown
	
	# Set properties on the projectile
	projectile.set_meta("bounce_count", remaining_bounces)
	projectile.set_meta("wild_bounce_damping", damping_factor)
	projectile.set_meta("wild_bounce_randomness", angle_randomness)
	projectile.set_meta("wild_bounce_reset_targets", reset_targets)
	projectile.set_meta("wild_bounce_speed_boost", speed_boost)
	projectile.set_meta("wild_bounce_original_speed", projectile.speed)
	
	# Special appearance - make it more vibrant and flashy
	projectile.modulate = Color(1.0, 0.7, 0.1)  # Orange-yellow glow
	
	# Add trail effect
	create_trail_effect(projectile)
	
	if DEBUG:
		print("Wild Bounce behavior applied to projectile with bounce_count: ", remaining_bounces)

# Create a simple trail effect
func create_trail_effect(projectile):
	# Create a CPUParticles2D for the trail
	var particles = CPUParticles2D.new()
	particles.name = "WildBounceTrail"
	particles.amount = 15
	particles.lifetime = 0.3
	particles.local_coords = false  # Use global coordinates
	particles.emitting = true
	particles.one_shot = false
	
	# Set particle properties
	particles.direction = Vector2(0, 0)
	particles.spread = 10
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 0
	particles.initial_velocity_max = 0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	
	# Make particles fade out with a warm color
	var gradient = Gradient.new()
	gradient.colors = [Color(1.0, 0.7, 0.1, 0.5), Color(1.0, 0.7, 0.1, 0.0)]
	particles.color_ramp = gradient
	
	# Add to projectile
	projectile.add_child(particles)

# Update cooldown in process
func on_projectile_process(projectile, delta):
	# Validate projectile
	if !is_instance_valid(projectile):
		return false
		
	# Update cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	# Never take over movement
	return false

# Handle projectile collision
func on_projectile_collision(projectile, collision):
	# Validate projectile and collision
	if !is_instance_valid(projectile) or !collision:
		return false
		
	# Skip if in cooldown
	if bounce_cooldown > 0.0:
		if DEBUG:
			print("In bounce cooldown, skipping collision handling")
		return false
	
	# Get collider
	var collider = collision.get_collider()
	if !is_instance_valid(collider):
		return false
	
	# Only bounce off walls, not characters
	if !collider.has_method("take_damage"):
		# Get cached values from projectile if available
		var bounce_count = projectile.get_meta("bounce_count", remaining_bounces)
		var damping = projectile.get_meta("wild_bounce_damping", damping_factor)
		var randomness = projectile.get_meta("wild_bounce_randomness", angle_randomness)
		var should_reset_targets = projectile.get_meta("wild_bounce_reset_targets", reset_targets)
		var boost = projectile.get_meta("wild_bounce_speed_boost", speed_boost)
		
		# If we have bounces remaining, bounce
		if bounce_count > 0:
			if DEBUG:
				print("Wild Bounce behavior handling collision with wall, remaining bounces: ", bounce_count)
			
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
				var random_angle = (randf() - 0.5) * 2.0 * PI/3.0 * randomness
				
				# Create a rotation matrix
				var rotation_matrix = Transform2D.IDENTITY.rotated(random_angle)
				
				# Apply the rotation to the reflected vector
				projectile.direction = (rotation_matrix * reflected).normalized()
				
				# Apply speed boost if configured
				var current_speed = projectile.speed
				if boost > 0:
					current_speed += projectile.get_meta("wild_bounce_original_speed", projectile.speed) * boost
					projectile.speed = current_speed
				
				# Update velocity with new direction and damping
				projectile.velocity = projectile.direction * current_speed * damping
			else:
				# For scalar direction, add randomness to the inversion
				projectile.direction = -projectile.direction
				if randf() < 0.5:  # 50% chance to add a y component
					# Convert scalar to vector with random vertical component
					var y_component = (randf() - 0.5) * 2.0  # Random between -1 and 1
					projectile.direction = Vector2(projectile.direction, y_component).normalized()
					
					# Apply speed boost if configured
					var current_speed = projectile.speed
					if boost > 0:
						current_speed += projectile.get_meta("wild_bounce_original_speed", projectile.speed) * boost
						projectile.speed = current_speed
						
					projectile.velocity = projectile.direction * current_speed * damping
				else:
					# Just use the inverted scalar
					
					# Apply speed boost if configured
					var current_speed = projectile.speed
					if boost > 0:
						current_speed += projectile.get_meta("wild_bounce_original_speed", projectile.speed) * boost
						projectile.speed = current_speed
						
					projectile.velocity = Vector2(projectile.direction * current_speed * damping, 0)
			
			# Move away just enough to prevent getting stuck
			projectile.global_position += normal * 10
			
			# CRITICAL: Clear hit targets to allow hitting again after bounce
			if should_reset_targets and "hit_targets" in projectile:
				projectile.hit_targets.clear()
				if DEBUG:
					print("Cleared hit targets array - projectile can damage targets again!")
			
			# Decrement bounce counter and update projectile
			bounce_count -= 1
			projectile.set_meta("bounce_count", bounce_count)
			
			# Apply bounce visual effects
			apply_bounce_visuals(projectile)
			
			if DEBUG:
				print("Projectile wild bounced! New direction: ", projectile.direction, " velocity: ", projectile.velocity)
			return true
		else:
			# No bounces remaining, allow projectile to be destroyed
			if DEBUG:
				print("No bounces remaining, allowing destruction")
			projectile.set_meta("cancel_destruction", false)
			return false
	else:
		# This is a collision with a character
		# Make sure we allow destruction so damage is applied
		projectile.set_meta("cancel_destruction", false)
	
	# Don't handle character collisions directly
	return false

# Apply visual effects on bounce
func apply_bounce_visuals(projectile):
	if !is_instance_valid(projectile):
		return
		
	# Visual feedback - change color slightly each bounce for visual variety
	var r = 0.7 + randf() * 0.3
	var g = 0.3 + randf() * 0.6
	var b = 0.1 + randf() * 0.2
	var original_modulate = Color(r, g, b) * 1.5  # Make it brighter
	
	# Store this as the new color
	projectile.set_meta("wild_bounce_color", original_modulate)
			
	# Flash effect - start with bright white
	projectile.modulate = Color(2.0, 2.0, 2.0)  # Bright flash
	
	# Create timer to restore color
	var timer = Timer.new()
	timer.wait_time = 0.08  # Faster flash than regular bounce
	timer.one_shot = true
	projectile.add_child(timer)
	
	# Create a callable for cleanup
	var cleanup_callable = func():
		if is_instance_valid(projectile):
			projectile.modulate = original_modulate
		if is_instance_valid(timer):
			timer.queue_free()
	
	# Store callable for cleanup
	timer.set_meta("cleanup_callable", cleanup_callable)
	
	# Connect and start timer
	timer.timeout.connect(cleanup_callable)
	timer.start()
	
	# Create a bounce particle effect at the bounce point
	create_bounce_particles(projectile)

# Create particles at bounce point
func create_bounce_particles(projectile):
	if !is_instance_valid(projectile):
		return
		
	# Get current position
	var pos = projectile.global_position
	
	# Create a particle emitter at the bounce position
	var particles = CPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 10
	particles.lifetime = 0.3
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 60
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	
	# Get color from projectile or use default
	var particle_color = projectile.get_meta("wild_bounce_color", Color(1.0, 0.7, 0.1))
	particles.color = particle_color
	
	# Add to scene
	projectile.get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	
	# Create timer to remove
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	particles.add_child(timer)
	
	# Create a callable for cleanup
	var cleanup_callable = func():
		if is_instance_valid(particles):
			particles.queue_free()
	
	# Connect and start timer
	timer.timeout.connect(cleanup_callable)
	timer.start()
