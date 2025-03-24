# improved_projectile_attack_style.gd - Creates projectiles using the ProjectileFactory
class_name ImprovedProjectileAttackStyle
extends AttackStyle

var projectile_count = 1
var projectile_spread = 0.0
var gravity_factor = 0.0

func _init_style():
	# Initialize projectile-specific properties
	projectile_count = int(get_param("projectile_count", 1))
	projectile_spread = float(get_param("projectile_spread", 0.0))
	gravity_factor = float(get_param("gravity_factor", 0.0))

func get_style_name() -> String:
	return "ImprovedProjectileAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing improved projectile attack with weapon: ", weapon.get_weapon_name())
	
	# Try to get the wielder from the weapon at execution time
	if weapon:
		wielder = weapon.wielder
	
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

# Create a single projectile (or one of multiple if using spread)
func create_projectile(index = 0):
	if DEBUG:
		print("Creating projectile via improved attack style...")
	
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
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
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
		"weapon_id": weapon.weapon_id,
		"weapon": weapon
	}
	
	# Add wave properties if needed
	if get_param("is_wave", false) or get_param("wave_amplitude", 0.0) > 0:
		config["is_wave"] = true
		config["wave_amplitude"] = float(get_param("wave_amplitude", 50.0))
		config["wave_frequency"] = float(get_param("wave_frequency", 3.0))
	
	# Add singularity properties if needed
	if get_param("is_singularity", false):
		config["is_singularity"] = true
		config["pull_radius"] = float(get_param("pull_radius", 150.0))
		config["pull_strength"] = float(get_param("pull_strength", 600.0))
	
	# Use ProjectileFactory to create the correct projectile type
	var projectile = ProjectileFactory.create_projectile(config, wielder)
	
	# Set position
	projectile.global_position = spawn_position
	
	# Add to scene
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		if DEBUG:
			print("Added projectile at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add projectile to scene - no parent for wielder")
		projectile.queue_free()
		return null
	
	# Notify weapon of projectile creation
	if weapon:
		weapon.on_projectile_created(projectile)
	
	return projectile

# Create a cluster bomb with multiple bomblets
func create_cluster_bomb():
	if DEBUG:
		print("Creating cluster bomb with spread and varied falling rates...")
	
	# Get cluster bomb parameters
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	var count = int(get_param("projectile_count", 3))
	var explosion_radius = float(get_param("explosion_radius", 40))
	var damage = weapon.calculate_damage()
	
	# Create individual bomblets with varied falling rates
	for i in range(count):
		# Calculate parameters for falling with varied speeds
		var base_speed = float(get_param("projectile_speed", 300)) * 0.6  # Reduced base speed
		
		# Create wider spread between bomblets
		var spread_factor = 30.0  # Increased spread
		var spread_offset = (i - (count-1)/2.0) * spread_factor
		
		# Direction is mostly forward
		var direction = Vector2(attack_direction, 0)
		
		# Different bombs have different gravity and vertical velocity
		var vert_variation = 40.0 * i  # Add variation to vertical velocity
		var vertical_velocity = -100 - vert_variation  # Less upward velocity
		
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
			"knockback": float(get_param("knockback_force", 500)),
			"gravity_factor": gravity_factor,  # Different gravity per bomblet
			"vertical_velocity": vertical_velocity,
			"explosion_radius": explosion_radius,
			"projectile_type": "explosive",
			"weapon_id": weapon.weapon_id,
			"weapon": weapon,
			"color": Color.from_hsv(0.1 + i * 0.1, 0.9, 1.0)  # Varied color for each bomblet
		}
		
		# Create bomblet using factory
		var bomblet = ProjectileFactory.create_projectile(config, wielder)
		
		# Position at spawn location with spread
		bomblet.global_position = spawn_position + Vector2(spread_offset, -i * 10)
		
		# Add to scene
		wielder.get_parent().add_child(bomblet)
		
		if DEBUG:
			print("Added bomblet with gravity: ", gravity_factor, " vertical velocity: ", vertical_velocity)
	
	# Notify when attack ends
	on_attack_end()
	
	return true
