# Redesigned for dropping bombs
class_name ClusterBombBehavior
extends BehaviorBase

var bomb_count = 3  # Number of child bombs to spawn
var explosion_radius = 40.0  # Radius of each explosion
var drop_interval = 0.15  # Time between bomb drops
var drop_timer = 0.0  # Timer for dropping bombs
var bombs_dropped = 0  # Track number of bombs dropped
var gravity_strength = 2500.0  # Very strong gravity for faster drops

func _init_behavior():
	print("DEBUG: ClusterBombBehavior _init_behavior called!")
	# Get parameters
	explosion_radius = float(get_param("explosion_radius", "40.0"))
	bomb_count = int(get_param("bomb_count", "3"))
	
	if DEBUG:
		print("Initialized cluster bomb behavior with radius: ", explosion_radius)
		print("Bombs to drop: ", bomb_count)

func get_behavior_name() -> String:
	return "ClusterBombBehavior"

func on_projectile_created(projectile):
	# Set parameters on projectile
	projectile.set_meta("explosion_radius", explosion_radius)
	projectile.set_meta("bomb_count", bomb_count)
	projectile.set_meta("is_cluster", true)
	
	# Track dropped bombs
	projectile.set_meta("bombs_dropped", 0)
	projectile.set_meta("drop_timer", 0.0)
	
	# Make it visually distinct
	projectile.modulate = Color(1.0, 0.4, 0.2)  # Red-orange
	
	# Prevent player riding on projectiles
	projectile.collision_layer = 0
	
	if DEBUG:
		print("Applied cluster bomb behavior to projectile")

# Process the bomb's behavior each frame
func on_projectile_process(projectile, delta):
	# If this is the carrier bomb, check if we should drop a bomb
	if projectile.has_meta("is_cluster") and !projectile.has_meta("is_child_bomb"):
		# Update drop timer
		var timer = projectile.get_meta("drop_timer", 0.0) + delta
		projectile.set_meta("drop_timer", timer)
		
		# Check if it's time to drop a bomb
		var bombs_dropped = projectile.get_meta("bombs_dropped", 0)
		if bombs_dropped < bomb_count and timer >= drop_interval:
			# Reset timer
			projectile.set_meta("drop_timer", 0.0)
			
			# Drop a bomb
			drop_bomb(projectile)
			
			# Increment counter
			bombs_dropped += 1
			projectile.set_meta("bombs_dropped", bombs_dropped)
			
			# If we've dropped all bombs, we can destroy the carrier
			if bombs_dropped >= bomb_count:
				# Create a small explosion at carrier position for visual effect
				create_explosion(projectile, explosion_radius * 0.5)
				projectile.destroy()
				return true
	
	# Not handling any special cases
	return false

# Handle collision with terrain or enemies
func on_projectile_collision(projectile, collision):
	# If this is a child bomb, handle normally
	if projectile.has_meta("is_child_bomb"):
		return false
		
	# If it's the carrier, drop all remaining bombs at once
	if projectile.has_meta("is_cluster"):
		var bombs_dropped = projectile.get_meta("bombs_dropped", 0)
		var remaining = bomb_count - bombs_dropped
		
		# Drop any remaining bombs quickly
		for i in range(remaining):
			drop_bomb(projectile)
		
		# Create a small explosion at carrier position
		create_explosion(projectile, explosion_radius * 0.5)
		
		# Destroy the carrier
		projectile.destroy()
	
	# We've handled the collision
	return true

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	# If this is the carrier and we haven't dropped all bombs, drop them now
	if projectile.has_meta("is_cluster") and !projectile.has_meta("is_child_bomb"):
		var bombs_dropped = projectile.get_meta("bombs_dropped", 0)
		var remaining = bomb_count - bombs_dropped
		
		# Drop any remaining bombs quickly
		for i in range(remaining):
			drop_bomb(projectile)
		
		# Create a small explosion at carrier position
		create_explosion(projectile, explosion_radius * 0.5)

# Apply gravity to bombs
func on_projectile_physics_process(projectile, delta):
	# Apply stronger gravity to child bombs
	if projectile.has_meta("is_child_bomb") and "velocity" in projectile:
		projectile.velocity.y += gravity_strength * delta
		return false
	
	# Not handling other cases
	return false

# Drop a bomb from the carrier
func drop_bomb(carrier):
	# Get scene
	var scene = carrier.get_tree().current_scene
	if !scene:
		print("ERROR: No scene found for cluster bombs")
		return
	
	# Determine direction from carrier
	var dir_x = 1
	if "direction" in carrier:
		if typeof(carrier.direction) == TYPE_VECTOR2:
			dir_x = sign(carrier.direction.x)
		else:
			dir_x = sign(carrier.direction)
	elif "velocity" in carrier and carrier.velocity.x != 0:
		dir_x = sign(carrier.velocity.x)
	
	# Get bomb count for determining drop pattern
	var dropped = carrier.get_meta("bombs_dropped", 0)
	
	# Colors for visual distinction
	var colors = [
		Color(1.0, 0.6, 0.1),  # Orange
		Color(0.2, 0.8, 0.3),  # Green
		Color(0.3, 0.5, 1.0)   # Blue
	]
	
	# Create a new explosive projectile
	var bomb = ExplosiveProjectile.new()
	
	# Basic setup
	bomb.explosion_radius = explosion_radius
	bomb.damage = int(carrier.damage * 0.7)
	bomb.knockback = carrier.knockback
	bomb.lifetime = 2.0  # Enough time to fall
	bomb.wielder_ref = carrier.wielder_ref
	
	# Mark as child bomb
	bomb.set_meta("is_child_bomb", true)
	
	# Visual appearance
	var sprite = ColorRect.new()
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -8)  # Center
	sprite.color = colors[dropped % colors.size()]
	bomb.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	bomb.add_child(collision)
	
	# Collision properties
	bomb.collision_layer = 0
	var enemy_mask = 4 if carrier.wielder_ref and carrier.wielder_ref.name == "Player1" else 2
	var world_mask = 1
	bomb.collision_mask = enemy_mask | world_mask
	
	# Position directly below the carrier with slight offset
	var offset_x = (dropped - bomb_count/2.0) * 15.0 * dir_x
	bomb.global_position = carrier.global_position + Vector2(offset_x, 0)
	
	# Add to scene before setting velocity
	scene.add_child(bomb)
	
	# Set velocity - inherit carrier's horizontal velocity, add slight downward velocity
	var vel_x = 0
	if "velocity" in carrier and typeof(carrier.velocity) == TYPE_VECTOR2:
		vel_x = carrier.velocity.x * 0.8  # Slightly slower than carrier
	
	bomb.velocity = Vector2(vel_x, 100)  # Start with slight downward velocity
	
	# Add this behavior to handle gravity for the child bomb
	bomb.add_behavior(self)
	
	if DEBUG:
		print("Dropped child bomb ", dropped, " at ", bomb.global_position)

# Create a simple explosion effect
func create_explosion(projectile, radius):
	# Create explosion area
	var explosion = Area2D.new()
	explosion.name = "ClusterExplosion"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	explosion.add_child(collision)
	
	# Set collision properties
	explosion.collision_layer = 0
	if projectile.wielder_ref and projectile.wielder_ref.name == "Player1":
		explosion.collision_mask = 4  # Detect Player 2
	else:
		explosion.collision_mask = 2  # Detect Player 1
	
	# Add visual
	var circle = ColorRect.new()
	circle.color = Color(1.0, 0.6, 0.1, 0.7)  # Orange for explosion
	var size = radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	explosion.add_child(circle)
	
	# Add to scene
	projectile.get_tree().current_scene.add_child(explosion)
	explosion.global_position = projectile.global_position
	
	# Create fade out tween
	var tween = circle.create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Create a timer to remove explosion
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	explosion.add_child(timer)
	timer.timeout.connect(func():
		if explosion and is_instance_valid(explosion):
			explosion.queue_free()
	)
	timer.start()
	
	# Apply damage to nearby enemies
	for body in explosion.get_overlapping_bodies():
		if body != projectile.wielder_ref and body.has_method("take_damage"):
			# Calculate direction
			var hit_dir = (body.global_position - explosion.global_position).normalized()
			
			# Calculate damage with falloff
			var distance = body.global_position.distance_to(explosion.global_position)
			var distance_factor = 1.0 - min(distance / radius, 1.0)
			var damage = int(projectile.damage * 0.8 * distance_factor)
			var knockback = projectile.knockback * distance_factor
			
			# Apply damage
			body.take_damage(damage, hit_dir, knockback)
