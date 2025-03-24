# projectile.gd - Handles projectile movement, collision and behavior delegation
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
var weapon_id = ""  # Store the weapon ID for behavior lookup

# Advanced projectile properties
var bounce_count = 0  # How many times it can bounce off walls
var homing_strength = 0.0  # How strongly it tracks targets (0-1)
var gravity_factor = 0.0  # How much gravity affects the projectile
var piercing = 0  # How many enemies it can hit before disappearing
var explosion_radius = 0  # Explosion radius when projectile hits
var vertical_velocity = 0.0  # Used for gravity calculations
var hit_targets = []  # Track which targets have been hit (for piercing)
var is_singularity = false
var singularity_pull_radius = 150.0  # How far the pull reaches
var singularity_pull_strength = 200.0  # How strong the pull is
var singularity_duration = 1.0  # How long it pulls before exploding
var singularity_timer = 0.0  # Tracks the singularity lifetime
var singularity_active = false  # Whether the singularity is currently active
var affected_bodies = []  # Bodies currently being affected by the singularity
var projectile_type = "standard"  # Default type, can be: standard, homing, wave, bouncing, explosive, etc.

# Behavior system integration
var behaviors = []  # List of behavior objects directly attached to the projectile

# Called when the node enters the scene tree for the first time
func _ready():
	# Get wielder reference from metadata if not already set
	if !wielder_ref and has_meta("wielder"):
		wielder_ref = get_meta("wielder")
		print("Retrieved wielder from metadata: ", wielder_ref.name if wielder_ref else "Still Unknown")
	
	# Store initial position for tracking
	initial_position = global_position
	
	# Get weapon ID from metadata
	if has_meta("weapon_id"):
		weapon_id = get_meta("weapon_id")
	elif has_meta("weapon") and get_meta("weapon").has_method("get_weapon_id"):
		weapon_id = get_meta("weapon").get_weapon_id()
	
	# Fallback approach - try to determine wielder based on the projectile's parent
	if !wielder_ref:
		var parent_scene = get_tree().current_scene
		if parent_scene.has_node("Player1") and parent_scene.has_node("Player2"):
			# Get both players
			var p1 = parent_scene.get_node("Player1")
			var p2 = parent_scene.get_node("Player2")
			
			# Determine owner based on position
			var dist_to_p1 = global_position.distance_to(p1.global_position)
			var dist_to_p2 = global_position.distance_to(p2.global_position)
			
			if dist_to_p1 < dist_to_p2:
				wielder_ref = p1
			else:
				wielder_ref = p2
			print("Determined wielder by proximity: ", wielder_ref.name)
	
	print("Final wielder is: ", wielder_ref.name if wielder_ref else "Still Unknown")
	
	# Set up collision masks based on projectile type
	setup_collision_masks()
	
	# Make the projectile actually use physics
	set_physics_process(true)  # Make sure physics is enabled

	# Apply stored config if initialize was called before ready
	if config_params != null:
		apply_config(config_params)
	
	# Make visually distinct for debugging
	modulate = Color(1.5, 1.5, 1.5)  # Brighter
	
	# Try to get behaviors from the behavior manager
	find_behaviors()
	
	if DEBUG:
		print("Projectile created at: ", global_position, " with direction: ", direction)

# Find and attach behaviors from the behavior manager
func find_behaviors():
	if weapon_id.is_empty():
		return
	
	# Try to find global behavior manager
	var behavior_manager = null
	var parent_scene = get_tree().current_scene
	
	if parent_scene.has_node("BehaviorManager"):
		behavior_manager = parent_scene.get_node("BehaviorManager")
	elif wielder_ref and wielder_ref.has_node("Weapon/BehaviorManager"):
		behavior_manager = wielder_ref.get_node("Weapon/BehaviorManager")
	
	if behavior_manager:
		# Let the behavior manager apply behaviors to this projectile
		behavior_manager.apply_behaviors_to_projectile(self)
		
		if DEBUG:
			print("Found behavior manager, behaviors applied to projectile")

# Set up collision masks based on projectile type
func setup_collision_masks():
	# Default collision mask (world + enemy)
	var world_mask = 1
	var enemy_mask = 4 if wielder_ref and wielder_ref.name == "Player1" else 2
	
	# Different collision rules for different projectile types
	match projectile_type:
		"wave":
			# Wave projectiles only hit enemies, not world
			collision_mask = enemy_mask
			print("Wave projectile - Collision mask set to: ", collision_mask, " (enemy only)")
		"homing":
			# Homing projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Homing projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		"bouncing":
			# Bouncing projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Bouncing projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		"explosive":
			# Explosive projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Explosive projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		"piercing":
			# Piercing projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Piercing projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		"gravity":
			# Gravity projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Gravity projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		"singularity":
			# Singularity projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Singularity projectile - Collision mask set to: ", collision_mask, " (world + enemy)")
		_: # Standard
			# Standard projectiles hit enemies and world
			collision_mask = enemy_mask | world_mask
			print("Standard projectile - Collision mask set to: ", collision_mask, " (world + enemy)")

# Use regular process instead of physics_process for more direct control
func _process(delta):
	# Let behaviors handle processing if they can
	var handled_by_behavior = process_behaviors(delta)
	
	# Only do default processing if no behavior handled it
	if !handled_by_behavior:
		# Process based on projectile type
		if is_singularity && singularity_active:
			process_singularity(delta)
		else:
			process_regular_projectile(delta)

# Delegate processing to behaviors first
func process_behaviors(delta):
	var handled = false
	
	# Find behavior manager for this weapon
	var behavior_manager = null
	var parent_scene = get_tree().current_scene
	
	if parent_scene.has_node("BehaviorManager"):
		behavior_manager = parent_scene.get_node("BehaviorManager")
	elif wielder_ref and wielder_ref.has_node("Weapon/BehaviorManager"):
		behavior_manager = wielder_ref.get_node("Weapon/BehaviorManager")
	
	# Try to use behavior manager first
	if behavior_manager and !weapon_id.is_empty():
		handled = behavior_manager.process_projectile(self, delta)
	
	# If not handled by behavior manager, try directly attached behaviors
	if !handled and behaviors.size() > 0:
		for behavior in behaviors:
			if behavior.has_method("on_projectile_process"):
				if behavior.on_projectile_process(self, delta):
					handled = true
					break
	
	# For homing projectiles, ensure homing is applied if not handled
	if !handled and projectile_type == "homing" and homing_strength > 0:
		process_homing_movement(delta)
		handled = true
	
	# Update lifetime for all projectiles
	timer += delta
	
	# Check lifetime - activate singularity or destroy
	if timer >= lifetime:
		if has_meta("on_lifetime_end"):
			var callback = get_meta("on_lifetime_end")
			if callback is Callable:
				callback.call()  # Call the stored function
		elif is_singularity:
			activate_singularity()
		else:
			destroy()
	
	return handled

# Process singularity behavior
func process_singularity(delta):
	# Handle singularity behavior
	singularity_timer += delta
	
	# Pull nearby objects
	pull_objects(delta)
	
	# Visual effects (pulsing)
	var scale_factor = 1.0 + 0.2 * sin(singularity_timer * 10)
	modulate = Color(0.5 + 0.5 * sin(singularity_timer * 8), 
					0.2, 
					0.5 + 0.5 * sin(singularity_timer * 6),
					1.0)
	
	# Scale any visual children for pulse effect
	for child in get_children():
		if child is ColorRect:
			child.scale = Vector2(scale_factor, scale_factor)
	
	# Check if singularity duration is over
	if singularity_timer >= singularity_duration:
		print("SINGULARITY EXPLODING!")
		# Explode with a big radius
		destroy()
		return

# Process standard projectile behavior
func process_regular_projectile(delta):
	# Visual indicator - pulse color to show function is running
	modulate = Color(1.0 + sin(timer * 10) * 0.5, 1.0, 1.0)
	
	# Process movement based on projectile type
	match projectile_type:
		"wave":
			process_wave_movement(delta)
		"homing":
			process_homing_movement(delta)
		"bouncing":
			process_standard_movement(delta)
		"explosive":
			process_standard_movement(delta)
		"piercing":
			process_standard_movement(delta)
		"gravity":
			process_gravity_movement(delta)
		"singularity":
			if !singularity_active:
				process_standard_movement(delta)
		_: # Standard
			process_standard_movement(delta)

# Process standard linear movement
func process_standard_movement(delta):
	# Create movement vector based on direction type
	var movement
	
	if typeof(direction) == TYPE_VECTOR2:
		# Direction is already a Vector2
		movement = direction * speed * delta
	else:
		# Direction is a number (left/right)
		movement = Vector2(direction * speed * delta, 0)
	
	# Apply movement
	global_position += movement
	
	# Update velocity for physics
	if typeof(direction) == TYPE_VECTOR2:
		velocity = direction * speed
	else:
		velocity = Vector2(direction * speed, 0)
		
# Process gravity-affected movement
func process_gravity_movement(delta):
	# Apply gravity
	vertical_velocity += 980 * gravity_factor * delta
	
	# Calculate movement based on direction type
	var movement
	if typeof(direction) == TYPE_VECTOR2:
		# Direction is already a Vector2 - use its x component for horizontal movement
		movement = Vector2(direction.x * speed * delta, vertical_velocity * delta)
	else:
		# Direction is a scalar (like -1 or 1)
		movement = Vector2(direction * speed * delta, vertical_velocity * delta)
	
	# Apply movement
	global_position += movement
	
	# Update velocity for physics
	if typeof(direction) == TYPE_VECTOR2:
		velocity = Vector2(direction.x * speed, vertical_velocity)
	else:
		velocity = Vector2(direction * speed, vertical_velocity)

# Process wave movement
func process_wave_movement(delta):
	# Get wave parameters
	var wave_amplitude = get_meta("wave_amplitude", 50.0)
	var wave_frequency = get_meta("wave_frequency", 3.0)
	
	# Update X position normally
	global_position.x += direction * speed * delta
	
	# Y position follows a sine wave
	global_position.y = get_meta("start_y", initial_position.y) + sin(timer * wave_frequency) * wave_amplitude
	
	# Update velocity for physics
	velocity.x = direction * speed
	velocity.y = cos(timer * wave_frequency) * wave_amplitude * wave_frequency

# Process homing movement with limited turn rate
func process_homing_movement(delta):
	# Find the enemy
	var enemy = find_closest_target()
	
	if enemy:
		# Log that we found an enemy to verify targeting is working
		print("Homing toward target: " + enemy.name)
		
		# Get direction to enemy - direct vector
		var to_enemy = (enemy.global_position - global_position).normalized()
		
		# Calculate stronger homing effect - use higher multiplier for more aggressive tracking
		# Increase the multiplier (5.0) for even stronger homing
		var homing_multiplier = 5.0 * homing_strength
		
		# Update velocity with stronger tracking
		velocity = velocity.lerp(to_enemy * speed, delta * homing_multiplier)
		
		# Apply movement directly - more immediate response
		global_position += velocity * delta
		
		# Visual feedback (optional)
		modulate = Color(0.5 + 0.5 * sin(timer * 5), 0.5, 1.0)
	else:
		# No enemy found, move in a straight line
		process_standard_movement(delta)

# Improved function to find targets
func find_closest_target():
	# Determine enemy based on wielder
	var enemy_name = "Player2"
	if wielder_ref and wielder_ref.name == "Player1":
		enemy_name = "Player2" 
	else:
		enemy_name = "Player1"
	
	# Find by name (most reliable method)
	var root = get_tree().get_root()
	if root.has_node(enemy_name):
		return root.get_node(enemy_name)
	
	# Alternative approach - find via group
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player != wielder_ref:
			return player
	
	# Final fallback - scan all CharacterBody2D nodes
	var bodies = get_tree().get_nodes_in_group("CharacterBody2D")
	for body in bodies:
		if body != wielder_ref and (body.name == "Player1" or body.name == "Player2"):
			return body
	
	return null

# Physics process for collision handling
func _physics_process(delta):
	# Let behaviors handle physics if they can
	var handled_by_behavior = process_behaviors_physics(delta)
	
	# Only do default physics if no behavior handled it
	if !handled_by_behavior:
		# Check for collisions
		var collision_result = move_and_collide(Vector2.ZERO, true)
		
		# Handle potential collisions based on projectile type
		if collision_result:
			handle_collision(collision_result)
		
		# Actually move the projectile with collision handling
		collision_result = move_and_collide(velocity * delta)
		
		# Handle actual collisions
		if collision_result:
			handle_collision(collision_result)

# Delegate physics processing to behaviors first
func process_behaviors_physics(delta):
	var handled = false
	
	# Find behavior manager for this weapon
	var behavior_manager = null
	var parent_scene = get_tree().current_scene
	
	if parent_scene.has_node("BehaviorManager"):
		behavior_manager = parent_scene.get_node("BehaviorManager")
	elif wielder_ref and wielder_ref.has_node("Weapon/BehaviorManager"):
		behavior_manager = wielder_ref.get_node("Weapon/BehaviorManager")
	
	# Try to use behavior manager first
	if behavior_manager and !weapon_id.is_empty():
		handled = behavior_manager.process_projectile_physics(self, delta)
	
	# If not handled by behavior manager, try directly attached behaviors
	if !handled and behaviors.size() > 0:
		for behavior in behaviors:
			if behavior.has_method("on_projectile_physics_process"):
				if behavior.on_projectile_physics_process(self, delta):
					handled = true
					break
	
	return handled

# Handle collisions based on projectile type
func handle_collision(collision_result):
	var collider = collision_result.get_collider()
	print("Collision detected with: ", collider.name)
	
	# Check if this is a world object (not a player)
	var is_world = !collider.has_method("take_damage")
	
	# Different collision behavior based on projectile type
	if is_world:
		# World collision
		match projectile_type:
			"wave":
				# Wave projectiles should never hit world objects
				# (but if they do somehow, just continue)
				pass
			"bouncing":
				# Bouncing projectiles bounce off world objects
				if bounce_count > 0:
					bounce_off_surface(collision_result.get_normal())
				else:
					destroy()
			"explosive":
				# Explosive projectiles explode on world contact
				create_explosion()
				destroy()
			"homing":
				# Homing projectiles are destroyed on world contact
				destroy()
			"piercing":
				# Piercing projectiles are destroyed on world contact
				destroy()
			"gravity":
				# Gravity projectiles are destroyed on world contact
				if explosion_radius > 0:
					create_explosion()
				destroy()
			"singularity":
				# Singularity projectiles activate on world contact
				if !singularity_active:
					activate_singularity()
				else:
					# Already active singularities should not collide with world
					pass
			_: # Standard
				# Standard projectiles are destroyed on world contact
				destroy()
	elif collider != wielder_ref:
		# Enemy collision
		handle_enemy_hit(collider)

# Handle hitting an enemy
func handle_enemy_hit(enemy):
	print("Hit enemy: ", enemy.name)
	
	# Notify behaviors about hit
	notify_behaviors_on_hit(enemy)
	
	# Calculate hit direction
	var hit_dir = Vector2.ZERO
	if typeof(direction) == TYPE_VECTOR2:
		hit_dir = direction.normalized()
	else:
		hit_dir = Vector2(direction, -0.2).normalized()
	
	# Apply damage
	enemy.take_damage(damage, hit_dir, knockback)
	print("Applied ", damage, " damage to ", enemy.name)
	
	# Apply effects
	if is_instance_valid(wielder_ref) and wielder_ref.has_node("Weapon"):
		var weapon_node = wielder_ref.get_node("Weapon")
		if weapon_node and weapon_node.has_method("apply_effects"):
			weapon_node.apply_effects(enemy, "hit")
	
	# Track hit for piercing
	hit_targets.append(enemy)
	
	# Handle aftermath based on projectile type
	match projectile_type:
		"piercing":
			# Reduce piercing counter
			piercing -= 1
			# Destroy if no more piercing
			if piercing <= 0:
				destroy()
		"explosive":
			# Create explosion and destroy
			create_explosion()
			destroy()
		"singularity":
			# Activate singularity on enemy hit
			if !singularity_active:
				activate_singularity()
		_: # Standard, homing, wave, etc.
			# Standard behavior - destroy on hit
			destroy()

# Notify behaviors that projectile hit an enemy
func notify_behaviors_on_hit(target):
	# Find behavior manager for this weapon
	var behavior_manager = null
	var parent_scene = get_tree().current_scene
	
	if parent_scene.has_node("BehaviorManager"):
		behavior_manager = parent_scene.get_node("BehaviorManager")
	elif wielder_ref and wielder_ref.has_node("Weapon/BehaviorManager"):
		behavior_manager = wielder_ref.get_node("Weapon/BehaviorManager")
	
	# Try to use behavior manager first
	if behavior_manager and !weapon_id.is_empty():
		behavior_manager.on_projectile_hit(self, target)
	
	# Also notify directly attached behaviors
	for behavior in behaviors:
		if behavior.has_method("on_projectile_hit"):
			behavior.on_projectile_hit(self, target)

# Bounce off a surface
func bounce_off_surface(normal):
	# Calculate bounce
	velocity = velocity.bounce(normal) * 0.8  # Dampening factor
	
	# Decrement bounce counter
	bounce_count -= 1
	print("Bounced! Remaining: ", bounce_count)
	
	# Prevent sticking to surfaces
	global_position += normal * 5

# Create an explosion effect
func create_explosion():
	if explosion_radius <= 0:
		return
		
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
	
	# Create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(_on_explosion_hit)
	
	# Store damage and other data
	explosion.set_meta("damage", damage)
	explosion.set_meta("knockback", knockback)
	explosion.set_meta("wielder", wielder_ref)
	
	# Create a timer to remove explosion after effect completes
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	explosion.add_child(timer)
	timer.timeout.connect(func():
		if explosion and is_instance_valid(explosion):
			explosion.queue_free()
	)
	timer.start()

# Handle explosion hits
func _on_explosion_hit(body):
	# Ignore the explosion hitting its owner
	if body == wielder_ref:
		return
	
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
		
		print("Explosion dealt " + str(explosion_damage) + " damage to " + body.name)

# Clean projectile destruction with effects
func destroy():
	# Notify behaviors about destruction
	var behavior_manager = null
	var parent_scene = get_tree().current_scene
	
	if parent_scene.has_node("BehaviorManager"):
		behavior_manager = parent_scene.get_node("BehaviorManager")
	elif wielder_ref and wielder_ref.has_node("Weapon/BehaviorManager"):
		behavior_manager = wielder_ref.get_node("Weapon/BehaviorManager")
	
	# Try to use behavior manager first
	if behavior_manager and !weapon_id.is_empty():
		behavior_manager.on_projectile_destroyed(self)
	
	# Also notify directly attached behaviors
	for behavior in behaviors:
		if behavior.has_method("on_projectile_destroyed"):
			behavior.on_projectile_destroyed(self)
	
	# Create explosion if radius > 0 and not already exploding
	if explosion_radius > 0 and !singularity_active:
		create_explosion()
	
	# Queue free after all effects are done
	queue_free()

# Initialize the projectile with configuration
func initialize(config):
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
	
	# Set initial vertical velocity if provided
	if "vertical_velocity" in config:
		vertical_velocity = float(config["vertical_velocity"])
	
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
	
	# Store weapon ID if provided
	if "weapon_id" in config:
		weapon_id = config["weapon_id"]
		set_meta("weapon_id", weapon_id)
	
	# Determine projectile type based on properties
	determine_projectile_type()
	
	# Override projectile type if directly specified
	if "projectile_type" in config:
		projectile_type = config["projectile_type"]
	
	# Add wave properties support
	if config.get("is_wave", false):
		projectile_type = "wave"
		set_meta("is_wave", true)
		set_meta("start_y", global_position.y)
		set_meta("wave_amplitude", float(config.get("wave_amplitude", 50.0)))
		set_meta("wave_frequency", float(config.get("wave_frequency", 3.0)))
	
	# Check if this is a singularity bomb
	is_singularity = config.get("is_singularity", false)
	if is_singularity:
		projectile_type = "singularity"
		singularity_pull_radius = float(config.get("singularity_radius", 150.0))
		singularity_pull_strength = float(config.get("singularity_strength", 200.0))
		singularity_duration = float(config.get("singularity_duration", 1.0))
	
	# Update collision masks based on projectile type
	setup_collision_masks()
	
	# Set initial velocity
	velocity = Vector2(direction * speed, 0) if typeof(direction) != TYPE_VECTOR2 else direction * speed
	
	print("Projectile initialized as type: ", projectile_type, 
		" - Speed: ", speed, 
		", Direction: ", direction, 
		", Bounce: ", bounce_count,
		", Homing: ", homing_strength,
		", Gravity: ", gravity_factor)

# Determine projectile type based on properties
func determine_projectile_type():
	if homing_strength > 0:
		projectile_type = "homing"
	elif bounce_count > 0:
		projectile_type = "bouncing"
	elif explosion_radius > 0:
		projectile_type = "explosive"
	elif piercing > 0:
		projectile_type = "piercing"
	elif gravity_factor > 0:
		projectile_type = "gravity"
	else:
		projectile_type = "standard"

# Activate the singularity
func activate_singularity():
	print("SINGULARITY ACTIVATED at position: " + str(global_position))
	singularity_active = true
	singularity_timer = 0.0
	
	# Stop all movement
	speed = 0
	velocity = Vector2.ZERO
	
	# Create the pull area
	var pull_area = Area2D.new()
	pull_area.name = "SingularityPull"
	
	# Add collision shape for pull range
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = singularity_pull_radius
	collision.shape = shape
	pull_area.add_child(collision)
	
	# Set collision to affect players
	pull_area.collision_layer = 0
	pull_area.collision_mask = 6  # Both players (2 + 4)
	
	# Connect body detection signals
	pull_area.body_entered.connect(_on_pull_area_body_entered)
	pull_area.body_exited.connect(_on_pull_area_body_exited)
	
	# Add visual ring effect
	var ring = ColorRect.new()
	ring.color = Color(0.7, 0.0, 1.0, 0.3)  # Purple with transparency
	var size = singularity_pull_radius * 2
	ring.size = Vector2(size, size)
	ring.position = Vector2(-size/2, -size/2)  # Center it
	
	# Make the singularity last longer and stronger
	singularity_duration = 2.0  # Double the duration
	singularity_pull_strength = 600.0  # Triple the strength
	
	# Modify the existing projectile color to be purple
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.5, 0.0, 0.7)  # Purple color
			child.size = Vector2(30, 30)  # Make it bigger
			child.position = Vector2(-15, -15)  # Recenter
	
	# Add the new visual elements
	add_child(pull_area)
	add_child(ring)
	
# Check immediately for bodies in range
	var bodies = get_tree().get_nodes_in_group("players")
	for body in bodies:
		if body != wielder_ref and body is CharacterBody2D:
			var distance = global_position.distance_to(body.global_position)
			if distance <= singularity_pull_radius:
				if not body in affected_bodies:
					affected_bodies.append(body)
					print("Added body to affected list: " + body.name)

# Track objects in pull range
func _on_pull_area_body_entered(body):
	# Don't affect the wielder
	if body == wielder_ref:
		return
		
	# Only care about physics bodies we can pull
	if body is CharacterBody2D and not body in affected_bodies:
		affected_bodies.append(body)

func _on_pull_area_body_exited(body):
	if body in affected_bodies:
		affected_bodies.erase(body)

# Pull objects toward the singularity
func pull_objects(delta):
	# If no bodies in range, try to search for bodies that might have entered range
	if affected_bodies.size() == 0:
		var bodies = get_tree().get_nodes_in_group("players")
		for body in bodies:
			if body != wielder_ref and body is CharacterBody2D:
				var distance = global_position.distance_to(body.global_position)
				if distance <= singularity_pull_radius:
					affected_bodies.append(body)
	
	# Apply pull force to affected bodies
	for body in affected_bodies:
		if is_instance_valid(body):
			# Calculate direction to singularity
			var pull_dir = (global_position - body.global_position).normalized()
			
			# Pull strength based on distance (inverse square law for more realistic gravity)
			var distance = global_position.distance_to(body.global_position)
			var strength = singularity_pull_strength
			
			# Avoid division by zero and make pull stronger at close range
			if distance > 10:
				strength = singularity_pull_strength / (distance * 0.1)
			else:
				strength = singularity_pull_strength * 5  # Very strong at close range
			
			# Apply pull in multiple ways for more reliable effect
			if "velocity" in body:
				# Add to velocity (accumulate force)
				body.velocity += pull_dir * strength * delta * 30
			
			# Always apply direct position change too
			body.global_position += pull_dir * strength * delta * 0.5
			
			# For particularly strong pulls, teleport slightly closer
			if distance < singularity_pull_radius * 0.3:
				body.global_position = body.global_position.lerp(global_position, delta * 2)

# Utility method to check if a target has already been hit
func has_hit_target(target):
	return target in hit_targets

# Utility method to track hit targets for piercing
func add_hit_target(target):
	if !target in hit_targets:
		hit_targets.append(target)

# Method to add a behavior directly to this projectile
func add_behavior(behavior):
	if !behavior in behaviors:
		behaviors.append(behavior)
		return true
	return false
