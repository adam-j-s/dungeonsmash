# projectile_attack_style.gd
class_name ProjectileAttackStyle
extends AttackStyle

var projectile_count = 1
var projectile_spread = 0.0
var gravity_factor = 0.0

func _init_style():
	# Any additional setup specific to projectile attacks
	projectile_count = int(get_param("projectile_count", 1))
	projectile_spread = float(get_param("projectile_spread", 0.0))
	gravity_factor = float(get_param("gravity_factor", 0.0))

func get_style_name() -> String:
	return "ProjectileAttackStyle"

func execute_attack():
	print("ProjectileAttackStyle executing attack")
	
	# Try to get the wielder from the weapon at execution time
	if weapon:
		wielder = weapon.wielder
		print("Got wielder at execution time: ", wielder.name if wielder else "Still None")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference - cannot execute attack")
		return false
	
	# Create and fire projectile(s) based on weapon type
	if weapon.weapon_id == "cluster_bomb":
		create_cluster_bomb()
	elif projectile_count > 1:
		# Create multiple projectiles with spread
		for i in range(projectile_count):
			create_projectile(i)
	else:
		# Create single projectile
		create_projectile()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	on_attack_end()
	
	return true

# Standard projectile creation with optional index for multi-projectile weapons
func create_projectile(index = 0):
	print("Creating projectile via attack style...")
	
	var projectile = CharacterBody2D.new()
	projectile.name = "Projectile_" + str(randi())
	
	# IMPORTANT: First set script, THEN add children and configure
	var script = load("res://scripts/projectile.gd")
	if script:
		projectile.set_script(script)
	else:
		print("ERROR: Could not load projectile script!")
		return null
	
	# Set the wielder and weapon references
	projectile.wielder_ref = wielder
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("wielder_name", wielder.name)
	projectile.set_meta("weapon", weapon)
	projectile.set_meta("weapon_id", weapon.weapon_id)
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(20, 20)  # Define size once
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2  # Automatically centers based on size
	
	# Determine projectile type based on weapon properties and set color
	var projectile_type = determine_projectile_type()
	
	# Set color based on projectile type
	match projectile_type:
		"homing":
			sprite.color = Color(0.2, 0.4, 1.0)  # Blue for homing
		"explosive":
			sprite.color = Color(1.0, 0.6, 0.2)  # Orange for explosive
		"bouncing":
			sprite.color = Color(0.2, 1.0, 0.4)  # Green for bouncing
		"piercing":
			sprite.color = Color(1.0, 0.2, 0.8)  # Pink for piercing
		"wave":
			sprite.color = Color(0.9, 0.9, 0.2)  # Yellow for wave
		"gravity":
			sprite.color = Color(0.8, 0.4, 0.1)  # Brown-orange for gravity
		_:
			sprite.color = Color(1.0, 0.2, 0.2)  # Red for standard
	
	# Set projectile type directly
	projectile.set_meta("projectile_type", projectile_type)
	
	projectile.add_child(sprite)

	# Add collision with matching size
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = sprite_size  # Use the same size variable
	collision.shape = shape
	projectile.add_child(collision)
	
	# Calculate direction and position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Apply spread angle if this is a multi-projectile weapon
	var direction_vector = Vector2(attack_direction, 0)
	if projectile_count > 1 and projectile_spread > 0:
		# Calculate spread angle based on index
		var angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		direction_vector = direction_vector.rotated(angle_rad)
	
	# Position in front of wielder
	projectile.global_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Explicitly set collision masks for the environment and enemy detection
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 1 | 4  # World (1) + Player 2 (4)
		print("Setting collision mask to detect world and Player2")
	else:
		projectile.collision_mask = 1 | 2  # World (1) + Player 1 (2)
		print("Setting collision mask to detect world and Player1")
	
	# Create configuration object with explicit parameters
	var config = {
		"speed": float(get_param("projectile_speed", 400)),
		"direction": direction_vector,
		"lifetime": float(get_param("projectile_lifetime", 1.0)),
		"damage": weapon.calculate_damage(),
		"knockback": float(get_param("knockback_force", 500)),
		"bounce_count": int(get_param("bounce_count", 0)),
		"homing_strength": float(get_param("homing_strength", 0.0)),
		"piercing": int(get_param("piercing", 0)),
		"explosion_radius": float(get_param("explosion_radius", 0)),
		"gravity_factor": float(get_param("gravity_factor", 0.0)),
		"projectile_type": projectile_type,
		"weapon_id": weapon.weapon_id
	}
	
	# Add wave properties if needed
	if projectile_type == "wave":
		config["is_wave"] = true
		config["wave_amplitude"] = float(get_param("wave_amplitude", 50.0))
		config["wave_frequency"] = float(get_param("wave_frequency", 3.0))
	
	# Add players to a group if not already in one (for homing to find targets)
	if wielder.get_groups().find("players") == -1:
		wielder.add_to_group("players")
	
	# Initialize the projectile
	projectile.initialize(config)
	
	# Add to scene AFTER full configuration
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		print("Added projectile at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add projectile to scene - no parent for wielder")
		projectile.queue_free()
		return null
	
	# Find the behavior manager to attach behaviors
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.apply_behaviors_to_projectile(projectile)
	
	# Notify weapon of projectile creation
	if weapon:
		weapon.on_projectile_created(projectile)
		
		# Trigger on_projectile_created for any behaviors on the weapon
		if weapon.has_node("BehaviorManager"):
			var weapon_behavior_manager = weapon.get_node("BehaviorManager")
			if weapon_behavior_manager:
				for behavior in weapon_behavior_manager.behaviors:
					if behavior.has_method("on_projectile_created"):
						behavior.on_projectile_created(projectile)
	
	return projectile
	
# Special cluster bomb implementation - updated for better cluster behavior
func create_cluster_bomb():
	print("Creating cluster bomb with spread and varied falling rates...")
	
	# Get cluster bomb parameters
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	var count = int(get_param("projectile_count", 3))
	var explosion_radius = float(get_param("explosion_radius", 40))
	var damage = weapon.calculate_damage()
	var knockback = float(get_param("knockback_force", 500))
	
	# Create individual bomblets with varied falling rates
	for i in range(count):
		# Create bomblet
		var bomblet = CharacterBody2D.new()
		bomblet.name = "ClusterBomb_Bomblet_" + str(i)
		
		# Apply script
		var script = load("res://scripts/projectile.gd")
		if script:
			bomblet.set_script(script)
		else:
			print("ERROR: Could not load projectile script!")
			continue
		
		# Set references
		bomblet.wielder_ref = wielder
		bomblet.set_meta("wielder", wielder)
		bomblet.set_meta("wielder_name", wielder.name)
		bomblet.set_meta("weapon", weapon)
		bomblet.set_meta("weapon_id", weapon.weapon_id)
		
		# Add sprite
		var sprite = ColorRect.new()
		var sprite_size = Vector2(16, 16)  # Smaller bomblet size
		sprite.size = sprite_size
		sprite.position = -sprite_size / 2
		
		# Make each bomblet visually distinct
		var hue_offset = i * 0.1  # Spread hues for visual distinction
		sprite.color = Color.from_hsv(0.1 + hue_offset, 0.9, 1.0)  # Varying orange-red colors
		bomblet.add_child(sprite)
		
		# Add collision
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite_size
		collision.shape = shape
		bomblet.add_child(collision)
		
		# Position at spawn location with initial separation
		bomblet.global_position = spawn_position
		
		# Set collision masks
		bomblet.collision_layer = 0
		if wielder.name == "Player1":
			bomblet.collision_mask = 1 | 4  # World (1) + Player 2 (4)
		else:
			bomblet.collision_mask = 1 | 2  # World (1) + Player 1 (2)
		
		# Calculate parameters for falling with varied speeds
		var base_speed = float(get_param("projectile_speed", 300)) * 0.6  # Reduced base speed
		
		# Create wider spread between bomblets
		var spread_factor = 30.0  # Increased spread
		var spread_offset = (i - (count-1)/2.0) * spread_factor
		
		# Direction is mostly forward
		var direction = Vector2(attack_direction, 0)
		
		# Different bombs have different gravity and vertical velocity
		var vert_variation = 40.0 * i  # Add variation to vertical velocity
		var vertical_velocity = -100 - vert_variation  # Much less upward velocity
		
		# Vary gravity by bomblet - middle one falls fastest
		var gravity_values = [0.8, 1.2, 0.6]  # Different gravity for each bomblet
		var gravity_factor = gravity_values[i % gravity_values.size()]
		
		# Varied lifetime for different bomblets
		var lifetime = 2.0 + (i * 0.5)  # Different lifetime for each
		
		# Create bomblet configuration
		var config = {
			"speed": base_speed + (i * 15),  # Varied horizontal speed
			"direction": direction,
			"lifetime": lifetime,
			"damage": damage / count,  # Split damage among bomblets
			"knockback": knockback,
			"gravity_factor": gravity_factor,  # Different gravity per bomblet
			"vertical_velocity": vertical_velocity,  # Much less upward momentum
			"explosion_radius": explosion_radius,
			"projectile_type": "gravity"
		}
		
		# Initialize bomblet with configuration
		bomblet.initialize(config)
		
		# Apply spread offset directly to position for immediate separation
		bomblet.global_position.x += spread_offset
		bomblet.global_position.y -= i * 10  # Slight vertical offset for better visibility
		
		# Add to scene
		wielder.get_parent().add_child(bomblet)
		print("Added bomblet with gravity: ", gravity_factor, " vertical velocity: ", vertical_velocity)
		
		# Find the behavior manager to attach behaviors
		var behavior_manager = find_behavior_manager()
		if behavior_manager:
			behavior_manager.apply_behaviors_to_projectile(bomblet)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	on_attack_end()
	
	return true
	
# Function to split the main cluster bomb into individual bomblets
func split_cluster_bomb(main_bomb):
	print("Splitting cluster bomb into bomblets!")
	
	# Get parameters from the main bomb
	var count = main_bomb.get_meta("cluster_count", 3)
	var spread = main_bomb.get_meta("cluster_spread", 20)
	var damage = main_bomb.get_meta("cluster_damage", 10)
	var knockback = main_bomb.get_meta("cluster_knockback", 500)
	var explosion_radius = main_bomb.get_meta("cluster_explosion_radius", 40)
	
	# Get the position and velocity of the main bomb at split time
	var pos = main_bomb.global_position
	var vel = main_bomb.velocity
	
	# Get scene to add bomblets to
	var parent_scene = main_bomb.get_parent()
	if !parent_scene:
		print("ERROR: Cannot split cluster bomb - no parent scene")
		main_bomb.queue_free()
		return
	
	# Create individual bomblets with distinct arcs
	for i in range(count):
		var bomblet = CharacterBody2D.new()
		bomblet.name = "ClusterBomb_Bomblet_" + str(i)
		
		# Set script
		var script = load("res://scripts/projectile.gd")
		if script:
			bomblet.set_script(script)
		else:
			print("ERROR: Could not load projectile script!")
			continue
		
		# Set the wielder reference (same as main bomb)
		bomblet.wielder_ref = main_bomb.wielder_ref
		bomblet.set_meta("wielder", main_bomb.wielder_ref)
		bomblet.set_meta("weapon_id", main_bomb.get_meta("weapon_id", ""))
		
		# Add sprite
		var sprite = ColorRect.new()
		var sprite_size = Vector2(16, 16)  # Smaller than main bomb
		sprite.size = sprite_size
		sprite.position = -sprite_size / 2
		
		# Make each bomblet visually distinct
		var hue_offset = i * 0.1  # Spread hues for visual distinction
		sprite.color = Color.from_hsv(0.1 + hue_offset, 0.9, 1.0)  # Varying orange-red colors
		
		bomblet.add_child(sprite)
		
		# Add collision
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite_size
		collision.shape = shape
		bomblet.add_child(collision)
		
		# Position at main bomb's location
		bomblet.global_position = pos
		
		# Set collision masks - same as original
		bomblet.collision_layer = main_bomb.collision_layer
		bomblet.collision_mask = main_bomb.collision_mask
		
		# Calculate spread angle
		var angle_offset = spread * (i - (count-1)/2.0) / ((count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		
		# Base horizontal direction - maintain parent's x direction
		var base_dir = sign(vel.x)
		
		# For distinct arcs, vary the vertical component more than horizontal
		var vert_velocity = 0
		match i:
			0: # Center bomblet - falls straight down
				vert_velocity = 100
			1: # Left bomblet - arc to left and down
				vert_velocity = 50
				angle_offset = -30  # Wider angle spread
			2: # Right bomblet - arc to right and down
				vert_velocity = 50
				angle_offset = 30   # Wider angle spread
		
		# Calculate new velocity vector based on angle and vertical component
		var direction = Vector2(base_dir, 0).rotated(deg_to_rad(angle_offset))
		
		# Create bomblet configuration
		var config = {
			"speed": abs(vel.x),  # Maintain horizontal speed
			"direction": direction,
			"lifetime": 1.0,  # Short lifetime for bomblets
			"damage": damage / count,  # Split damage among bomblets
			"knockback": knockback,
			"gravity_factor": 0.7,  # Higher gravity for faster arcing
			"explosion_radius": explosion_radius,
			"vertical_velocity": vert_velocity,  # Use calculated vertical velocity
			"projectile_type": "explosive"
		}
		
		# Initialize bomblet
		bomblet.initialize(config)
		
		# Add to scene
		parent_scene.add_child(bomblet)
		print("Added cluster bomblet at: ", bomblet.global_position, " with velocity: ", bomblet.velocity)
		
		# Find the behavior manager to attach behaviors
		var behavior_manager = find_behavior_manager()
		if behavior_manager:
			behavior_manager.apply_behaviors_to_projectile(bomblet)
	
	# Remove the main bomb
	main_bomb.queue_free()

# Helper function to determine projectile type based on weapon properties
func determine_projectile_type():
	if get_param("homing_strength", 0.0) > 0:
		return "homing"
	elif get_param("explosion_radius", 0) > 0:
		return "explosive"
	elif get_param("bounce_count", 0) > 0:
		return "bouncing"
	elif get_param("piercing", 0) > 0:
		return "piercing"
	elif get_param("is_wave", false) or get_param("wave_amplitude", 0.0) > 0:
		return "wave"
	elif get_param("gravity_factor", 0.0) > 0:
		return "gravity"
	else:
		return "standard"

# Find a behavior manager to use
func find_behavior_manager():
	# First check if weapon has one
	if weapon and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	var scene = wielder.get_tree().current_scene
	if scene.has_node("BehaviorManager"):
		return scene.get_node("BehaviorManager")
	
	return null

# Helper function to get params either from weapon or using a default
func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value
