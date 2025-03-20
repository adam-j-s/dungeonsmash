extends CharacterBody2D
const DEBUG = false  # Set to true only when debugging

# Basic properties
var speed = 400.0
var direction = 1
var lifetime = 1.0
var timer = 0.0
var damage = 10
var knockback = 500
var effects = []
var hit_effect = ""
var wielder_ref = null
var config_params = null  # Store parameters if initialize is called before ready
var initial_position = Vector2.ZERO  # Track starting position for debugging

# Advanced projectile properties
var bounce_count = 0  # How many times it can bounce off walls
var homing_strength = 0.0  # How strongly it tracks targets (0-1)
var gravity_factor = 0.0  # How much gravity affects the projectile
var piercing = 0  # How many enemies it can hit before disappearing
var explosion_radius = 0  # Explosion radius when projectile hits
var vertical_velocity = 0.0  # Used for gravity calculations
var hit_targets = []  # Track which targets have been hit (for piercing)

# Called when the node enters the scene tree for the first time
func _ready():
	if has_meta("wielder"):
		wielder_ref = get_meta("wielder")
	
	# Store initial position for tracking
	initial_position = global_position
	# Set up proper collision detection
	collision_mask = 1  # Set collision with world only
	print("Collision mask set to: ", collision_mask)

	# Make the projectile actually use physics
	set_physics_process(true)  # Make sure physics is enabled
	
	# Apply stored config if initialize was called before ready
	if config_params != null:
		apply_config(config_params)
	
	# Make visually distinct for debugging
	modulate = Color(1.5, 1.5, 1.5)  # Brighter
	
	# Create a debug timer to verify the scene is processing
	var debug_timer = Timer.new()
	debug_timer.wait_time = 0.2
	debug_timer.one_shot = true
	debug_timer.timeout.connect(func(): 
		if DEBUG:
			print("Projectile timer fired - scene is processing")
	)
	add_child(debug_timer)
	debug_timer.start()
	
	if DEBUG:
		print("Projectile created at: ", global_position, " with direction: ", direction)

# Use regular process instead of physics_process for more direct control
func _process(delta):
	# Visual indicator - pulse color to show function is running
	modulate = Color(1.0 + sin(timer * 10) * 0.5, 1.0, 1.0)
	
	# Determine movement based on projectile type
	var movement = Vector2.ZERO
	
	# Apply gravity if enabled
	if gravity_factor > 0:
		vertical_velocity += 980 * gravity_factor * delta  # 980 is approx gravity in Godot
		movement.y = vertical_velocity * delta
	
	# Apply homing if enabled and there's an enemy
	if homing_strength > 0:
		# Simplified homing logic
		var players = get_tree().get_nodes_in_group("players")
		var enemy = null
	
	# Find the enemy (not the wielder)
		for player in players:
			if player != wielder_ref:
				enemy = player
				break
	
		if enemy:
			# Direct vector to enemy
			var to_enemy = (enemy.global_position - global_position).normalized()
			# Make homing much more aggressive
			movement = to_enemy * speed * delta
			# For debug
			print("Homing toward: " + enemy.name + ", position: " + str(enemy.global_position))
		else:
			# No enemy found
			movement.x = direction * speed * delta
	else:
		# Check for wave movement
		var is_wave = get_meta("is_wave", false)
		if is_wave:
			# Wave movement: forward motion plus sine wave for up/down
			var wave_amplitude = get_meta("wave_amplitude", 50.0)
			var wave_frequency = get_meta("wave_frequency", 3.0)
			
			# Only update X position with speed/direction
			movement.x += direction * speed * delta
			# Y position follows a sine wave
			global_position.y = get_meta("start_y", initial_position.y) + sin(timer * wave_frequency) * wave_amplitude
		else:
			# Normal projectile movement (direct line)
			movement.x += direction * speed * delta
	
	# Apply movement - special case for wave projectiles
	# FIXED: Corrected wave movement logic (was backward)
	if get_meta("is_wave", false) and gravity_factor <= 0 and homing_strength <= 0:
		# For wave projectiles, only X position is applied directly (Y is set above)
		global_position.x += direction * speed * delta
	else:
		# For all other projectiles, apply the calculated movement vector
		global_position += movement
	
	# Check for bouncing (if enabled)
	if bounce_count > 0:
		check_bounce()
	
	# Print debug info
	if DEBUG:
		var distance = global_position - initial_position
		print("Projectile lifetime: " + str(timer) + "/" + str(lifetime) + 
			", position: " + str(global_position) + 
			", distance: " + str(distance.length()) +
			", speed: " + str(speed) +
			", direction: " + str(direction))
	
	# Check lifetime
	timer += delta
	if timer >= lifetime:
		if DEBUG:
			print("Projectile reached end of lifetime, destroying")
		destroy()
# Add this function to handle gravity properly
func _physics_process(delta):
	# Handle gravity-affected projectiles through the physics engine
	if gravity_factor > 0:
		# Apply gravity
		velocity.y += 980 * gravity_factor * delta
		
		# Move and check for collisions
		var collision = move_and_collide(velocity * delta)
		
		# Handle collisions
		if collision:
			print("Physics collision detected!")
			
			if bounce_count > 0:
				# Calculate bounce
				var normal = collision.get_normal()
				
				# Bounce velocity off the surface
				velocity = velocity.bounce(normal) * 0.8  # Dampening factor
				
				bounce_count -= 1
				print("Bounced! Remaining: ", bounce_count)
				
				# Prevent sticking to surfaces
				global_position += normal * 5
			else:
				# No more bounces left
				destroy()

# Find the closest valid target for homing
func find_closest_target():
	# Debug for homing missiles
	if homing_strength > 0 and DEBUG:
		print("Homing Debug ----")
		print("Wielder: ", wielder_ref.name if wielder_ref else "None")
		
	var target_layer = 4 if wielder_ref and wielder_ref.name == "Player1" else 2
	
	if homing_strength > 0 and DEBUG:
		print("Looking for targets on layer: ", target_layer)
	
	var closest_target = null
	var closest_dist = 500.0  # Maximum homing range
	
	# Get all potential targets
	var potential_targets = get_tree().get_nodes_in_group("players")
	
	if homing_strength > 0 and DEBUG:
		print("Found ", potential_targets.size(), " players in group")
	
	for target in potential_targets:
		if homing_strength > 0 and DEBUG:
			print("Checking target: ", target.name, " with layer: ", target.collision_layer)
		
		# Skip self or already hit targets (for piercing)
		if target == wielder_ref:
			if homing_strength > 0 and DEBUG:
				print("  Skipping self")
			continue
			
		if target in hit_targets:
			if homing_strength > 0 and DEBUG:
				print("  Already hit, skipping")
			continue
			
		# Check collision mask match (only target enemies)
		# FIXED: Debug this check
		if homing_strength > 0 and DEBUG:
			print("  Layer check: ", target_layer, " & ", target.collision_layer, 
				  " = ", (target_layer & target.collision_layer))
		
		if (target_layer & target.collision_layer) == 0:
			if homing_strength > 0 and DEBUG:
				print("  Layer mismatch, skipping")
			continue
			
		var dist = global_position.distance_to(target.global_position)
		
		if homing_strength > 0 and DEBUG:
			print("  Distance to target: ", dist)
		
		if dist < closest_dist:
			closest_dist = dist
			closest_target = target
			
			if homing_strength > 0 and DEBUG:
				print("  New closest target: ", target.name)
	
	if homing_strength > 0 and DEBUG:
		print("Final target: ", closest_target.name if closest_target else "None")
		
	return closest_target

# Check if we should bounce off walls - UPDATED to handle environment collisions
func check_bounce():
	# First check for actual collisions with physics
	var collision = move_and_collide(Vector2.ZERO, true)  # Test collision without moving
	
	if collision:
		var normal = collision.get_normal()
		var bounced = false
		
		# Bounce based on the collision normal
		if abs(normal.x) > 0.5:  # Horizontal surface (wall)
			direction = -direction
			bounced = true
		
		if abs(normal.y) > 0.5 and gravity_factor > 0:  # Vertical surface (floor/ceiling)
			vertical_velocity = -vertical_velocity * 0.8
			bounced = true
		
		if bounced:
			# Count the bounce
			bounce_count -= 1
			
			# Slightly adjust position to avoid getting stuck
			global_position += normal * 5
			
			if DEBUG:
				print("Projectile bounced off environment! Remaining: " + str(bounce_count))
				
			if bounce_count <= 0:
				destroy()
				
			return
	
	# If no environment collision, check screen bounds as fallback
	var viewport_rect = get_viewport_rect().size
	var screen_bounds = Rect2(Vector2.ZERO, viewport_rect)
	
	# Detect if we're outside screen bounds
	var bounced = false
	
	# Left/right bounds
	if global_position.x < 0 or global_position.x > screen_bounds.size.x:
		direction = -direction  # Reverse horizontal direction
		bounced = true
	
	# Top/bottom bounds (only check if affected by gravity or is a wave)
	if gravity_factor > 0:
		if global_position.y > screen_bounds.size.y:
			vertical_velocity = -vertical_velocity * 0.8  # Bounce up with some dampening
			bounced = true
		elif global_position.y < 0:
			vertical_velocity = abs(vertical_velocity) * 0.8  # Bounce down with some dampening
			bounced = true
	
	if bounced:
		bounce_count -= 1
		if DEBUG:
			print("Projectile bounced off screen edge! Remaining: " + str(bounce_count))
		
		# If we're out of bounces, destroy the projectile
		if bounce_count <= 0:
			destroy()

# Create an explosion effect
func create_explosion():
	if explosion_radius <= 0:
		return
		
	if DEBUG:
		print("Creating explosion with radius: " + str(explosion_radius))
	
	# Create explosion area
	var explosion = Area2D.new()
	explosion.name = "Explosion"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	collision.shape = shape
	explosion.add_child(collision)
	
	# Set collision properties
	explosion.collision_layer = 0
	if wielder_ref and wielder_ref.name == "Player1":
		explosion.collision_mask = 4  # Detect Player 2
	else:
		explosion.collision_mask = 2  # Detect Player 1
	
	# Add visual
	var circle = ColorRect.new()
	circle.color = Color(1.0, 0.6, 0.1, 0.7)  # Orange for explosion
	var size = explosion_radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	explosion.add_child(circle)
	
	# Add to scene (only once)
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# NOW create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(_on_explosion_hit)
	
	# Store damage and other data
	explosion.set_meta("damage", damage)
	explosion.set_meta("knockback", knockback)
	explosion.set_meta("wielder", wielder_ref)
	
	# Remove after effect completes
	await get_tree().create_timer(0.5).timeout
	if explosion and is_instance_valid(explosion):
		explosion.queue_free()

# Handle explosion hits
func _on_explosion_hit(body):
	# Ignore the explosion hitting its owner
	if body == wielder_ref:
		return
		
	if DEBUG:
		print("Explosion hit: ", body.name)
	
	# Skip if already hit by the original projectile
	if body in hit_targets:
		return
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction away from explosion center
		var hit_dir = (body.global_position - global_position).normalized()
		
		# Get damage and knockback from explosion
		var explosion_damage = int(damage * 0.7)  # Explosion does 70% of projectile damage
		
		# Apply damage and knockback
		body.take_damage(explosion_damage, hit_dir, knockback)
		
		if DEBUG:
			print("Explosion dealt " + str(explosion_damage) + " damage to " + body.name)

# Clean projectile destruction with effects
func destroy():
	# Create explosion if radius > 0
	if explosion_radius > 0:
		create_explosion()
	
	# Queue free after all effects are done
	queue_free()

# Add hit target for piercing projectiles
func add_hit_target(target):
	if not target in hit_targets:
		hit_targets.append(target)
		
	# Reduce piercing counter
	piercing -= 1

# Check if a body has already been hit (for piercing)
func has_hit_target(target):
	return target in hit_targets

# Initialize the projectile with configuration
func initialize(config):
	if DEBUG:
		print("Initialize called with: ", config)
	config_params = config
	
	# If already added to the scene tree, apply config immediately
	if is_inside_tree():
		apply_config(config)
	# Otherwise config will be applied in _ready
	
	return self  # Return self to allow method chaining

# Actually apply the configuration
func apply_config(config):
	# Set basic properties - convert types explicitly
	speed = float(config.get("speed", 400.0))
	
	# Handle vector or float direction
	if typeof(config.get("direction")) == TYPE_VECTOR2:
		direction = config.get("direction")
	else:
		direction = float(config.get("direction", 1))
		
	lifetime = float(config.get("lifetime", 1.0))
	damage = int(config.get("damage", 10))
	knockback = float(config.get("knockback", 500))
	effects = config.get("effects", [])
	hit_effect = config.get("hit_effect", "")
	
	# Set advanced properties - ensure proper type conversion
	bounce_count = int(config.get("bounce_count", "0"))
	homing_strength = float(config.get("homing_strength", "0.0"))
	gravity_factor = float(config.get("gravity_factor", "0.0"))
	piercing = int(config.get("piercing", "0"))
	explosion_radius = float(config.get("explosion_radius", "0"))
	
	# Add wave properties support
	if config.get("is_wave", false):
		set_meta("is_wave", true)
		set_meta("start_y", global_position.y)
		set_meta("wave_amplitude", float(config.get("wave_amplitude", 50.0)))
		set_meta("wave_frequency", float(config.get("wave_frequency", 3.0)))
	
	# Set initial velocity
	velocity = Vector2(direction * speed, 0) if typeof(direction) != TYPE_VECTOR2 else direction * speed
	
	if DEBUG:
		print("Projectile initialized - Speed: ", speed, 
			", Direction: ", direction, 
			", Bounce: ", bounce_count,
			", Homing: ", homing_strength,
			", Gravity: ", gravity_factor)
