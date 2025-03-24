# bounce_behavior.gd - Makes projectiles bounce off surfaces
class_name BounceBehavior
extends Behavior

var remaining_bounces = 0
var damping_factor = 0.8  # Energy lost on each bounce
var bounce_sound = "res://assets/audio/bounce.wav"
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces on same collision

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

# Process function - update cooldown
func on_projectile_process(projectile, delta):
	# Decrement cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	return false  # Return false to let standard movement continue

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
			
			# Print debug info
			print("DEBUG: Collision detected with normal: ", normal)
			print("DEBUG: Velocity before bounce: ", projectile.velocity)
			
			# Apply bounce handling
			handle_bounce(projectile, normal)
			
			return true
	
	# Let projectile handle movement if no bounce occurred
	return false

# Handle what happens when projectile hits a surface
func handle_bounce(projectile, normal):
	# Skip if we're in cooldown
	if bounce_cooldown > 0.0:
		return false
		
	# Only bounce if we have bounces remaining
	if remaining_bounces <= 0:
		return false
	
	# Set a brief cooldown to prevent multiple bounces
	bounce_cooldown = 0.2  # 200ms cooldown
	
	# Print debug info
	print("DEBUG: Bouncing against normal: ", normal)
	
	# Calculate new direction - crucial for horizontal bounces
	if typeof(projectile.direction) != TYPE_VECTOR2:
		# If direction is a scalar (like 1 or -1), invert it
		projectile.direction = -projectile.direction
		print("DEBUG: Changed direction to: ", projectile.direction)
	else:
		# If direction is a Vector2, reflect it
		projectile.direction = projectile.direction.bounce(normal)
	
	# Update velocity to match new direction
	if typeof(projectile.direction) != TYPE_VECTOR2:
		projectile.velocity = Vector2(projectile.direction * projectile.speed, 0)
	else:
		projectile.velocity = projectile.direction * projectile.speed
	
	# Move projectile away from collision
	projectile.global_position += normal * 60
	
	# Decrement bounce counter
	remaining_bounces -= 1
	projectile.bounce_count = remaining_bounces
	
	# Visual feedback
	projectile.modulate = Color(2.0, 2.0, 2.0)  # Bright flash
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = true
	projectile.add_child(timer)
	timer.timeout.connect(func():
		projectile.modulate = Color(0.2, 1.0, 0.4)  # Green color
		timer.queue_free()
	)
	timer.start()
	
	print("DEBUG: Bounce applied - direction: ", projectile.direction, " velocity: ", projectile.velocity)
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
