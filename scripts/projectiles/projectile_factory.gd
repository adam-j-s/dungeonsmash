# projectile_factory.gd - Creates appropriate projectile instances based on configuration
class_name ProjectileFactory
extends Node

const DEBUG = true  # Set to true for debugging

# Create a projectile of the appropriate type based on configuration
static func create_projectile(config: Dictionary, wielder = null, explicit_type = null):
	if DEBUG:
		print("Creating projectile with config: ", config)
	
	# Determine projectile type based on properties or explicit type	
	var projectile_type = explicit_type if explicit_type else determine_projectile_type(config)
	
	# Create the specific projectile class
	var projectile = create_projectile_instance(projectile_type)
	if !projectile:
		if DEBUG:
			print("Failed to create projectile, falling back to StandardProjectile")
		projectile = StandardProjectile.new()
	
	# Add basic visual representation
	add_projectile_visual(projectile, projectile_type, config)
	
	# Add collision shape
	add_collision_shape(projectile, config)
	
	# Save the wielder reference
	if wielder:
		projectile.wielder_ref = wielder
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("wielder_name", wielder.name if wielder else "Unknown")
	
	# Store weapon reference if provided
	if config.has("weapon"):
		projectile.set_meta("weapon", config.weapon)
	
	# Store weapon ID if provided
	if config.has("weapon_id"):
		projectile.weapon_id = config.weapon_id
		projectile.set_meta("weapon_id", config.weapon_id)
	
	# Check to allow for self-damage
	if config.has("allow_self_damage"):
		var self_damage_value = config["allow_self_damage"]
		projectile.set_meta("allow_self_damage", config["allow_self_damage"])
		print("DEBUG: Set allow_self_damage=" + str(self_damage_value) + " on projectile ID: " + str(projectile.get_instance_id()))
	else:
		print("DEBUG: config does not contain allow_self_damage key!")
	# Initialize the projectile with the configuration
	projectile.initialize(config)
	
	# ***NEW CODE: Add collision safety delay to prevent immediate collisions***
	apply_collision_safety(projectile, config, wielder)
	
	return projectile

# NEW FUNCTION: Apply collision safety to prevent immediate collisions with player or other projectiles
static func apply_collision_safety(projectile, config: Dictionary, wielder):
	# Store original collision mask
	var original_mask = projectile.collision_mask
	
	print("COLLISION DEBUG: Initial position: ", projectile.global_position)
	print("COLLISION DEBUG: Wielder position: ", wielder.global_position if wielder else "No wielder")
	print("COLLISION DEBUG: Original mask: ", original_mask)
	
	# Disable ALL collisions initially for a brief moment
	projectile.collision_mask = 0  # Completely disable collisions initially
	# IMPRTANT: set collision layer to 0 so that objects can't collide with projectile - players can't ride
	projectile.collision_layer = 0
	
	# Add to projectiles group to identify them for collision filtering
	projectile.add_to_group("player_projectiles")
	
	# Create forward offset to ensure projectiles spawn away from player
	var forward_offset = Vector2.ZERO
	if "direction" in projectile and typeof(projectile.direction) == TYPE_VECTOR2:
		forward_offset = projectile.direction.normalized() * 60.0  # Increased to 60
	elif "direction" in projectile:
		forward_offset = Vector2(float(projectile.direction), 0).normalized() * 60.0
	
	# Apply the offset
	if forward_offset != Vector2.ZERO:
		projectile.global_position += forward_offset
		print("COLLISION DEBUG: Applied forward offset: ", forward_offset)
		print("COLLISION DEBUG: New position: ", projectile.global_position)
	
	# Set creation time for debugging
	projectile.set_meta("creation_time", Time.get_ticks_msec())
	
	# Set initial color for visual debugging
	projectile.modulate = Color(1.0, 0.2, 0.2)  # Start red
	
	# Set a timer to restore collision after a short delay
	var timer = Timer.new()
	timer.wait_time = 0.25  # Increased to 250ms
	timer.one_shot = true
	projectile.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(projectile):
			projectile.collision_mask = original_mask  # Restore original mask
			projectile.modulate = Color(0.2, 1.0, 0.2)  # Change to green when collisions enabled
			print("COLLISION DEBUG: Restored collision mask for projectile ID: ", projectile.get_instance_id())
			print("COLLISION DEBUG: Time since creation: ", (Time.get_ticks_msec() - projectile.get_meta("creation_time")) / 1000.0, " seconds")
	)
	timer.start()
	
	# Add a second timer to change color to blue after a bit longer
	var color_timer = Timer.new()
	color_timer.wait_time = 0.4  # 400ms
	color_timer.one_shot = true
	projectile.add_child(color_timer)
	color_timer.timeout.connect(func():
		if is_instance_valid(projectile):
			projectile.modulate = Color(0.2, 0.2, 1.0)  # Change to blue
	)
	color_timer.start()
	print("COLLISION DEBUG: Applied collision safety delay to projectile ID: ", projectile.get_instance_id())

# Determine the projectile type based on configuration
static func determine_projectile_type(config: Dictionary) -> String:
	# Check for explicit type first
	if config.has("projectile_type"):
		return config.projectile_type
	
	# Check for singularity
	if config.get("is_singularity", false):
		return "singularity"
	
	# Check for wave projectile
	if config.get("is_wave", false) or config.get("wave_amplitude", 0.0) > 0:
		return "wave"
	
	# Check for homing
	if config.get("homing_strength", 0.0) > 0:
		return "homing"
	
	# Check for bouncing
	if config.get("bounce_count", 0) > 0:
		return "bouncing"
	
	# Check for explosion
	if config.get("explosion_radius") and config.explosion_radius > 0:
		return "explosive"
	
	# Default to standard
	return "standard"

# Create the appropriate projectile instance based on type
static func create_projectile_instance(projectile_type: String):
	match projectile_type:
		"standard":
			return StandardProjectile.new()
		"homing":
			return HomingProjectile.new()
		"bouncing":
			return BouncingProjectile.new()
		"explosive":
			return ExplosiveProjectile.new()
		"wave":
			return WaveProjectile.new()
		"singularity":
			return SingularityProjectile.new()
		_:
			if DEBUG:
				print("Unknown projectile type: ", projectile_type)
			return StandardProjectile.new()  # Default fallback

# Add visual representation to the projectile
static func add_projectile_visual(projectile, projectile_type: String, config: Dictionary):
	# Create visual with proper size
	var sprite_size = Vector2(20, 20)  # Default size
	
	# Allow custom size from config
	if config.has("size"):
		sprite_size = config.size
	
	# Create sprite as ColorRect
	var sprite = ColorRect.new()
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2  # Center the sprite
	
	# Set default color based on projectile type
	match projectile_type:
		"standard":
			sprite.color = Color(1.0, 0.2, 0.2)  # Red for standard
		"homing":
			sprite.color = Color(0.2, 0.4, 1.0)  # Blue for homing
		"bouncing":
			sprite.color = Color(0.2, 1.0, 0.4)  # Green for bouncing
		"explosive":
			sprite.color = Color(1.0, 0.6, 0.2)  # Orange for explosive
		"wave":
			sprite.color = Color(0.3, 0.7, 0.9)  # Cyan for wave
		"singularity":
			sprite.color = Color(0.5, 0.0, 0.7)  # Purple for singularity
		_:
			sprite.color = Color(1.0, 1.0, 1.0)  # White for unknown

	# Allow custom color from config
	if config.has("color"):
		sprite.color = config.color
	
	# Apply tier coloring if specified
	if config.has("tier"):
		var tier = int(config.tier)
		var tier_factor = min(tier * 0.2, 0.8)  # Up to 80% gold tint for higher tiers
		var gold_color = Color(1.0, 0.8, 0.0)  # Gold color
		sprite.color = sprite.color.lerp(gold_color, tier_factor)
	
	# Add to projectile
	projectile.add_child(sprite)

# Add collision shape to the projectile
static func add_collision_shape(projectile, config: Dictionary):
	var collision = CollisionShape2D.new()
	var shape_type = config.get("shape_type", "rectangle")
	var shape
	
	# Create the appropriate shape
	match shape_type:
		"circle":
			shape = CircleShape2D.new()
			shape.radius = 10  # Default radius
			
			# Allow custom radius
			if config.has("radius"):
				shape.radius = config.radius
		_:  # Default to rectangle
			shape = RectangleShape2D.new()
			shape.size = Vector2(20, 20)  # Default size
			
			# Allow custom size
			if config.has("size"):
				shape.size = config.size
	
	# Set the shape and add the collision
	collision.shape = shape
	projectile.add_child(collision)
