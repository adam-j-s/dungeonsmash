# bounce_behavior.gd - Makes projectiles bounce off surfaces
class_name BounceBehavior
extends Behavior

var remaining_bounces = 0
var damping_factor = 0.8  # Energy lost on each bounce
var bounce_sound = "res://assets/audio/bounce.wav"

func _init_behavior():
	# Any additional setup specific to bouncing
	pass

func get_behavior_name() -> String:
	return "BounceBehavior"

func on_projectile_created(projectile):
	# Get bounce count from parameters
	remaining_bounces = int(get_param("bounce_count", 3))
	
	# Set properties on the projectile
	projectile.bounce_count = remaining_bounces
	projectile.set_meta("bounce_count", remaining_bounces)
	projectile.projectile_type = "bouncing"
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["bounce_count"] = remaining_bounces
		config["projectile_type"] = "bouncing"
		projectile.apply_config(config)
	
	# Add this behavior directly to the projectile for callbacks
	if projectile.has_method("add_behavior"):
		projectile.add_behavior(self)
	
	if DEBUG:
		print("Applied bounce behavior to projectile with bounce_count: ", remaining_bounces)

# Process function - we don't need to control movement directly
func on_projectile_process(projectile, delta):
	# Let the projectile handle normal movement
	return false

# The collision detection and bounce happens in physics_process
func on_projectile_physics_process(projectile, delta):
	# Check for collisions with the world layer (1)
	var collision = projectile.move_and_collide(Vector2.ZERO, true)
	if collision and remaining_bounces > 0:
		var collider = collision.get_collider()
		
		# Only bounce off world objects, not characters
		if !collider.has_method("take_damage"):
			# Get normal vector for bounce calculation
			var normal = collision.get_normal()
			
			# Calculate bounce but with stronger effect
			var old_velocity = projectile.velocity
			var new_velocity = projectile.velocity.bounce(normal) * damping_factor
			
			# Apply new velocity with direct property set
			projectile.velocity = new_velocity
			
			# Push away from surface to avoid getting stuck
			projectile.global_position += normal * 20
			
			# Print debug info
			print("DEBUG: Velocity before bounce: ", old_velocity)
			print("DEBUG: Velocity after bounce: ", new_velocity)
			print("DEBUG: Collision normal: ", normal)
			
			# Apply bounce handling
			handle_bounce(projectile, normal)
			
			return true
	
	# Let projectile handle movement if no bounce occurred
	return false

# Handle what happens when projectile hits a surface
func handle_bounce(projectile, normal):
	# Only bounce if we have bounces remaining
	if remaining_bounces <= 0:
		return false
	
	# Calculate bounce but with a minimum velocity
	var bounced_velocity = projectile.velocity.bounce(normal) * damping_factor
	
	# Ensure minimum speed after bounce
	var min_speed = 200.0
	if bounced_velocity.length() < min_speed:
		bounced_velocity = bounced_velocity.normalized() * min_speed
	
	# Apply the velocity with a direct property set
	projectile.velocity = bounced_velocity
	
	# Ensure position is updated to avoid getting stuck in collision
	projectile.global_position += normal * 15
	
	# Add a random element to make bounces more interesting
	projectile.velocity = projectile.velocity.rotated(randf_range(-0.1, 0.1))
	
	# Extend lifetime on bounce to ensure projectile lives long enough
	if "lifetime" in projectile and "timer" in projectile:
		projectile.lifetime += 0.3  # Add time on each bounce
	
	# Decrement bounce counter
	remaining_bounces -= 1
	projectile.bounce_count = remaining_bounces
	
	# Visual feedback
	projectile.modulate = Color(1.5, 1.5, 1.5)  # Bright flash
	
	# Timer for color reset
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = true
	projectile.add_child(timer)
	timer.timeout.connect(func():
		projectile.modulate = Color(0.2, 1.0, 0.4)  # Back to green
		timer.queue_free()
	)
	timer.start()
	
	print("DEBUG: Bounce applied - new velocity: ", projectile.velocity)
	print("Projectile bounced! Remaining bounces: ", remaining_bounces)
	
	return true

# Called when projectile hits something
func on_projectile_hit(projectile, target):
	# Handle enemy hits normally, but don't reduce bounce count
	# This allows bouncing projectiles to hit multiple enemies
	# without affecting their ability to bounce off walls
	if DEBUG:
		print("Bouncing projectile hit enemy: ", target.name)

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	if DEBUG:
		print("Bouncing projectile destroyed with ", remaining_bounces, " bounces remaining")
