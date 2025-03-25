# improved_bounce_behavior.gd - Makes projectiles bounce off surfaces
class_name ImprovedBounceBehavior
extends BehaviorBase

var remaining_bounces = 0
var damping_factor = 0.8  # Energy lost on each bounce
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces on same collision

func _init_behavior():
	# Get parameters
	remaining_bounces = int(get_param("bounce_count", 3))
	damping_factor = float(get_param("damping_factor", 0.8))

func get_behavior_name() -> String:
	return "BounceBehavior"

func on_projectile_created(projectile):
	# Set properties on the projectile
	projectile.set_meta("bounce_count", remaining_bounces)
	
	# If projectile is already a BouncingProjectile, update its properties
	if projectile is BouncingProjectile:
		projectile.bounce_count = remaining_bounces
		projectile.damping_factor = damping_factor
	
	if DEBUG:
		print("Applied bounce behavior to projectile with bounce_count: ", remaining_bounces)

# The physics handling is the main part of bounce behavior
func on_projectile_physics_process(projectile, delta):
	# Update cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	# If this is a BouncingProjectile, let it handle its own bounces
	if projectile is BouncingProjectile:
		return false  # Let projectile handle it
	
	# Only process if we have bounces remaining
	if remaining_bounces <= 0:
		return false
		
	# Check for collisions with the world
	var collision = projectile.move_and_collide(Vector2.ZERO, true)
	if collision and bounce_cooldown <= 0.0:
		var collider = collision.get_collider()
		
		# Only bounce off world objects, not characters
		if !collider.has_method("take_damage"):
			# Get normal vector for bounce calculation
			var normal = collision.get_normal()
			
			# Handle bounce
			handle_bounce(projectile, normal)
			
			# We've handled this collision
			return true
	
	# Let projectile handle movement if no bounce occurred
	return false

# Handle what happens when projectile hits a surface
func handle_bounce(projectile, normal):
	# Skip if we're in cooldown
	if bounce_cooldown > 0.0:
		return
		
	# Set a brief cooldown to prevent multiple bounces
	bounce_cooldown = 0.2  # 200ms cooldown
	
	if DEBUG:
		print("Bouncing against normal: ", normal)
	
	# Calculate new direction and velocity
	if "direction" in projectile:
		if typeof(projectile.direction) != TYPE_VECTOR2:
			# If direction is a scalar (like 1 or -1), invert it
			projectile.direction = -projectile.direction
		else:
			# If direction is a Vector2, reflect it
			projectile.direction = projectile.direction.reflect(normal)
		
		# Update velocity to match new direction
		if typeof(projectile.direction) != TYPE_VECTOR2:
			projectile.velocity = Vector2(projectile.direction * projectile.speed, 0)
		else:
			projectile.velocity = projectile.direction * projectile.speed * damping_factor
	else:
		# Directly reflect velocity if no direction property
		projectile.velocity = projectile.velocity.bounce(normal) * damping_factor
	
	# Move projectile away from collision
	projectile.global_position += normal * 10
	
	# Decrement bounce counter
	remaining_bounces -= 1
	
	# Visual feedback
	projectile.modulate = Color(2.0, 2.0, 2.0)  # Bright flash
	
	# Create timer to restore normal color
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = true
	projectile.add_child(timer)
	timer.timeout.connect(func():
		projectile.modulate = Color(0.2, 1.0, 0.4)  # Green color
		timer.queue_free()
	)
	timer.start()
	
	if DEBUG:
		print("Bounce applied - velocity: ", projectile.velocity)
		print("Projectile bounced! Remaining bounces: ", remaining_bounces)
