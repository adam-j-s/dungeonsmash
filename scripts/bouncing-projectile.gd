# bouncing_projectile.gd - Projectile that bounces off surfaces
class_name BouncingProjectile
extends ProjectileBase

var bounce_count = 3  # How many bounces remaining
var damping_factor = 0.8  # Energy lost on each bounce (0.8 = 80% energy retained)
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces on the same collision

func _ready():
	super._ready()
	
	# Get bounce count from metadata if available
	if has_meta("bounce_count"):
		bounce_count = get_meta("bounce_count")
	
	# Set visual appearance - green for bouncing projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.2, 1.0, 0.4)  # Green color
	
	# Adjust collision mask - bouncing projectiles should hit both world and enemies
	setup_collision_masks()

# Update cooldown timer in process
func _process(delta):
	# Update bounce cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	# Call the parent process
	super._process(delta)

# Override to handle bouncing off surfaces
func _handle_collision(collision):
	var collider = collision.get_collider()
	
	# Check if this is a world object (not a player)
	var is_world = !collider.has_method("take_damage")
	
	if is_world:
		# Bounce off world objects if we have bounces remaining
		if bounce_count > 0 and bounce_cooldown <= 0.0:
			bounce_off_surface(collision.get_normal())
			return
		
		# If no bounces left, destroy
		destroy()
	else:
		# Handle hit with enemy
		if collider != wielder_ref:
			_handle_hit(collider)

# Handle bouncing off a surface
func bounce_off_surface(normal):
	# Skip if in cooldown
	if bounce_cooldown > 0.0:
		return
	
	# Set a brief cooldown to prevent multiple bounces
	bounce_cooldown = 0.2  # 200ms cooldown
	
	if DEBUG:
		print("Bouncing against normal: ", normal)
	
	# Calculate new direction based on how direction is stored
	if typeof(direction) != TYPE_VECTOR2:
		# If direction is a scalar (like 1 or -1), invert it
		direction = -direction
		
		if DEBUG:
			print("Changed direction to: ", direction)
	else:
		# If direction is a Vector2, reflect it
		direction = direction.reflect(normal)
	
	# Update velocity to match new direction
	if typeof(direction) != TYPE_VECTOR2:
		velocity = Vector2(direction * speed, 0)
	else:
		velocity = direction * speed * damping_factor
	
	# Move projectile away from collision to avoid getting stuck
	global_position += normal * 10
	
	# Decrement bounce counter
	bounce_count -= 1
	
	# Visual feedback
	for child in get_children():
		if child is ColorRect:
			# Bright flash on bounce
			child.modulate = Color(2.0, 2.0, 2.0)  # Bright white flash
			
			# Create a timer to restore normal color
			var timer = Timer.new()
			timer.wait_time = 0.1
			timer.one_shot = true
			add_child(timer)
			
			# When timer finishes, restore color
			timer.timeout.connect(func():
				child.modulate = Color(0.2, 1.0, 0.4)  # Back to green
				timer.queue_free()
			)
			
			timer.start()
	
	if DEBUG:
		print("Bounce applied - direction: ", direction, " velocity: ", velocity)
		print("Projectile bounced! Remaining bounces: ", bounce_count)
