# projectile_attack_style.gd
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	print("Projectile style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")

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
		return
	
	# Create and fire projectile(s) based on weapon type
	if weapon.weapon_id == "cluster_bomb":
		create_cluster_bomb()
	else:
		create_projectile()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Standard projectile creation
# In projectile_attack_style.gd - modify the create_projectile function

func create_projectile():
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
		
	# Set the wielder reference
	projectile.wielder_ref = wielder
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("wielder_name", wielder.name)
	projectile.set_meta("weapon", weapon)
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(20, 20)  # Define size once
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2  # Automatically centers based on size
	
	# Color based on weapon type for better visual feedback
	if weapon.weapon_data.get("homing_strength", 0.0) > 0:
		sprite.color = Color(0.2, 0.4, 1.0)  # Blue for homing
		# Set projectile type directly
		projectile.set_meta("projectile_type", "homing")
	elif weapon.weapon_data.get("explosion_radius", 0) > 0:
		sprite.color = Color(1.0, 0.6, 0.2)  # Orange for explosive
		# Set projectile type directly
		projectile.set_meta("projectile_type", "explosive")
	elif weapon.weapon_data.get("bounce_count", 0) > 0:
		sprite.color = Color(0.2, 1.0, 0.4)  # Green for bouncing
		# Set projectile type directly
		projectile.set_meta("projectile_type", "bouncing")
	elif weapon.weapon_data.get("piercing", 0) > 0:
		sprite.color = Color(1.0, 0.2, 0.8)  # Pink for piercing
		# Set projectile type directly
		projectile.set_meta("projectile_type", "piercing")
	else:
		sprite.color = Color(1.0, 0.2, 0.2)  # Red for standard
	
	projectile.add_child(sprite)

	# Add collision with matching size
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = sprite_size  # Use the same size variable
	collision.shape = shape
	projectile.add_child(collision)
	
	# Calculate direction and position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
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
		"speed": float(weapon.weapon_data.get("projectile_speed", 400)),
		"direction": attack_direction,
		"lifetime": float(weapon.weapon_data.get("projectile_lifetime", 1.0)),
		"damage": weapon.calculate_damage(),
		"knockback": float(weapon.weapon_data.get("knockback_force", 500)),
		"bounce_count": int(weapon.weapon_data.get("bounce_count", 0)),
		"homing_strength": float(weapon.weapon_data.get("homing_strength", 0.0)),
		"piercing": int(weapon.weapon_data.get("piercing", 0)),
		"explosion_radius": float(weapon.weapon_data.get("explosion_radius", 0)),
		"gravity_factor": float(weapon.weapon_data.get("gravity_factor", 0.0)),
		"projectile_type": projectile.get_meta("projectile_type", "standard")
	}
	
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
	
	# Notify weapon of projectile creation
	if weapon:
		weapon.on_projectile_created(projectile)
	
	return projectile

# Special cluster bomb implementation
func create_cluster_bomb():
	print("Creating cluster bomb...")
	
	# Create the main cluster bomb first (which will split later)
	var main_bomb = CharacterBody2D.new()
	main_bomb.name = "ClusterBomb_Main"
	
	# IMPORTANT: First set script, THEN add children and configure
	var script = load("res://scripts/projectile.gd")
	if script:
		main_bomb.set_script(script)
	else:
		print("ERROR: Could not load projectile script!")
		return null
	
	# Set the wielder reference
	main_bomb.wielder_ref = wielder
	main_bomb.set_meta("wielder", wielder)
	main_bomb.set_meta("wielder_name", wielder.name)
	main_bomb.set_meta("weapon", weapon)
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(24, 24)  # Slightly larger than standard projectiles
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2
	sprite.color = Color(1.0, 0.5, 0.0)  # Orange for explosive
	main_bomb.add_child(sprite)
	
	# Add collision with matching size
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = sprite_size
	collision.shape = shape
	main_bomb.add_child(collision)
	
	# Calculate direction and position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Position in front of wielder
	main_bomb.global_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Get cluster bomb parameters
	var projectile_count = int(weapon.weapon_data.get("projectile_count", 3))
	var explosion_radius = float(weapon.weapon_data.get("explosion_radius", 40))
	var split_time = float(weapon.weapon_data.get("projectile_lifetime", 1.0)) * 0.5  # Split halfway through lifetime
	
	# Create configuration for main bomb
	var config = {
		"speed": float(weapon.weapon_data.get("projectile_speed", 300)),
		"direction": attack_direction,
		"lifetime": split_time,  # Half the normal lifetime before splitting
		"damage": 0,  # No damage from main bomb (only clusters do damage)
		"knockback": 0,  # No knockback from main bomb
		"gravity_factor": 0.5,  # Affected by gravity
		"vertical_velocity": -350,  # Initial upward velocity for arc
		"is_cluster_bomb": true,
		"cluster_count": projectile_count,
		"cluster_spread": float(weapon.weapon_data.get("projectile_spread", 20)),
		"cluster_damage": weapon.calculate_damage(),
		"cluster_knockback": float(weapon.weapon_data.get("knockback_force", 500)),
		"cluster_explosion_radius": explosion_radius
	}
	
	# Initialize the main bomb
	main_bomb.initialize(config)
	
	# Add custom function to split into clusters when lifetime ends
	main_bomb.set_meta("on_lifetime_end", func():
		split_cluster_bomb(main_bomb)
	)
	
	# Add to scene
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(main_bomb)
		print("Added cluster bomb at: ", main_bomb.global_position)
	else:
		print("ERROR: Cannot add cluster bomb to scene - no parent for wielder")
		main_bomb.queue_free()
		return null
	
	# Notify weapon of projectile creation
	if weapon:
		weapon.on_projectile_created(main_bomb)
	
	return main_bomb

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
	
	# Create individual bomblets
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
		
		# Add sprite
		var sprite = ColorRect.new()
		var sprite_size = Vector2(16, 16)  # Smaller than main bomb
		sprite.size = sprite_size
		sprite.position = -sprite_size / 2
		sprite.color = Color(1.0, 0.3, 0.0)  # Slightly redder orange
		bomblet.add_child(sprite)
		
		# Add collision
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite_size
		collision.shape = shape
		bomblet.add_child(collision)
		
		# Position at main bomb's location
		bomblet.global_position = pos
		
		# Calculate spread angle
		var angle_offset = spread * (i - (count-1)/2.0) / ((count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		
		# Calculate new velocity with spread
		# Start with main bomb's velocity and add spread
		var new_vel = vel.rotated(angle_rad)
		
		# Each bomblet has slightly different vertical velocity for distinct arcs
		var vert_offset = 0
		if i == 0:  # Middle bomblet
			vert_offset = 0
		elif i == 1:  # Left bomblet
			vert_offset = -50
		else:  # Right bomblet
			vert_offset = 50
		
		new_vel.y += vert_offset
		
		# Create bomblet configuration
		var config = {
			"speed": new_vel.length(),
			"direction": new_vel.normalized(),  # Use vector direction
			"lifetime": 1.0,  # Short lifetime for bomblets
			"damage": damage / count,  # Split damage among bomblets
			"knockback": knockback,
			"gravity_factor": 0.7,  # Higher gravity for faster arcing
			"explosion_radius": explosion_radius,
			"initial_velocity": new_vel  # Use precalculated velocity
		}
		
		# Initialize bomblet
		bomblet.initialize(config)
		
		# Add to scene
		parent_scene.add_child(bomblet)
		print("Added cluster bomblet at: ", bomblet.global_position, " with velocity: ", new_vel)
	
	# Remove the main bomb
	main_bomb.queue_free()
