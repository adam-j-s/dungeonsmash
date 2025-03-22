# Projectile attack implementation
class_name ProjectileAttackStyle
extends AttackStyle

func _init_style():
	pass

func get_style_name() -> String:
	return "ProjectileAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing projectile attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Get number of projectiles to fire
		var projectile_count = int(get_param("projectile_count", 1))
		var projectile_spread = float(get_param("projectile_spread", 0))
		
		# Only load script once for efficiency
		var script_res = load("res://scripts/projectile.gd")
		if !script_res:
			print("ERROR: Could not load projectile.gd script!")
			return
			
		# Calculate the starting angle for spread shots
		var spread_start = 0
		if projectile_count > 1 and projectile_spread > 0:
			spread_start = -projectile_spread / 2.0
		
		# Create each projectile
		for i in range(projectile_count):
			# Calculate angle for this projectile in the spread
			var angle = 0.0
			var gravity_modifier = 1.0
			
			if projectile_count > 1 and projectile_spread > 0:
				if weapon.weapon_id == "cluster_bomb":
					# For cluster bombs, create distinct arcs
					if i == 0:
						angle = -30  # Upward angle
						gravity_modifier = 0.8  # Less gravity for higher arc
					elif i == 1:
						angle = 0    # Straight ahead
						gravity_modifier = 1.0  # Normal gravity
					else:
						angle = 30   # Downward angle
						gravity_modifier = 1.2  # More gravity for steeper arc
				else:
					# For non-cluster bombs, use normal spread calculation
					angle = spread_start + (projectile_spread / (projectile_count - 1)) * i
			
			# Apply modified gravity for cluster bombs
			var adjusted_gravity = float(get_param("gravity_factor", 0.0))
			if weapon.weapon_id == "cluster_bomb":
				adjusted_gravity *= gravity_modifier
			
			# Create the projectile
			var projectile = create_projectile(script_res, attack_direction, angle, adjusted_gravity)
			
			# Notify the behavior system about this projectile
			if projectile and weapon:
				weapon.on_projectile_created(projectile)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Helper function to create an individual projectile
func create_projectile(script_res, dir_value, angle_degrees = 0.0, gravity_override = 0.0):
	# Create the projectile with proper error checking
	var projectile = CharacterBody2D.new()
	projectile.name = "Projectile_" + weapon.weapon_id
	
	# Apply script BEFORE adding to scene tree
	projectile.set_script(script_res)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)

	# Add visual
	var visual = ColorRect.new()

	# Get base and tint colors
	var base_color = Color(0.2, 0.2, 0.8)  # Default blue
	if weapon.get_weapon_type() == "sword":
		base_color = Color(0.8, 0.2, 0.2)  # Red for sword projectiles
		
	var tier = int(get_param("tier", 0))
	var tier_factor = min(tier * 0.2, 0.8)
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)

	visual.color = final_color
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	projectile.add_child(visual)

	# Set collision properties
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 4  # Detect Player 2
	else:
		projectile.collision_mask = 2  # Detect Player 1

	# Set up an Area2D for hit detection
	var hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = projectile.collision_mask
	var hitbox_collision = CollisionShape2D.new()
	hitbox_collision.shape = shape.duplicate()
	hitbox.add_child(hitbox_collision)
	projectile.add_child(hitbox)

	# Connect signal for hit detection
	hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))

	# Calculate properties
	var projectile_speed = float(get_param("projectile_speed", 400))
	var projectile_lifetime = float(get_param("projectile_lifetime", 0.8))
	
	# Convert angle to radians and calculate direction vector
	var angle_rad = deg_to_rad(angle_degrees)
	var dir_vector = Vector2(cos(angle_rad), sin(angle_rad)) * dir_value
	if angle_degrees == 0:
		dir_vector = Vector2(dir_value, 0)

	# Store metadata on the projectile
	projectile.set_meta("damage", weapon.calculate_damage())
	projectile.set_meta("knockback", float(get_param("knockback_force", 500)))
	projectile.set_meta("direction", dir_value)
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("effects", get_param("effects", []))
	projectile.set_meta("weapon_id", weapon.weapon_id)
	projectile.set_meta("weapon_name", weapon.get_weapon_name())

	# Position with angle offset if needed
	var spawn_position = wielder.global_position + Vector2(dir_value * 30, 0)
	projectile.global_position = spawn_position
	
	# Use the gravity override if provided
	var gravity_value = gravity_override if gravity_override > 0.0 else float(get_param("gravity_factor", 0.0))
	
	# Initialize BEFORE adding to the scene with advanced properties
	if projectile.has_method("initialize"):
		# Setup basic parameters for all projectiles
		var init_params = {
			"speed": projectile_speed,
			"direction": dir_vector.x,  # For angled shots
			"lifetime": projectile_lifetime,
			"damage": weapon.calculate_damage(),
			"knockback": float(get_param("knockback_force", 500)),
			"effects": get_param("effects", []),
			"bounce_count": int(get_param("bounce_count", 0)),
			"homing_strength": float(get_param("homing_strength", 0.0)),
			"gravity_factor": gravity_value,
			"piercing": int(get_param("piercing", 0)),
			"explosion_radius": float(get_param("explosion_radius", 0))
		}
			
		# Initialize with all parameters
		projectile.initialize(init_params)
	else:
		print("ERROR: Projectile script has no initialize method!")
		return null

	# Now add to scene AFTER initialization
	weapon.get_tree().current_scene.add_child(projectile)
	
	# Force update position once more to ensure it's correct
	projectile.global_position = spawn_position
	
	if DEBUG:
		print("Projectile launched at: " + str(projectile.global_position) + 
			" with direction: " + str(dir_vector) + 
			" and speed: " + str(projectile_speed))

	return projectile  # Return the created projectile

# Handle projectile hits - Updated to handle piercing and explosions
func _on_projectile_hit(body, projectile):
	# Get stored values from the projectile
	var wielder_ref = projectile.get_meta("wielder")
	
	# Don't hit yourself
	if body == wielder_ref:
		return

	# Skip if already in hit targets list (for piercing)
	if projectile.has_method("has_hit_target") and projectile.has_hit_target(body):
		return
		
	if DEBUG:
		print("Projectile hit: ", body.name)
	else:
		print("Projectile hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Get more stored values from the projectile
		var damage = projectile.get_meta("damage")
		var knockback_force = projectile.get_meta("knockback")
		var direction = projectile.get_meta("direction")
		var weapon_name = projectile.get_meta("weapon_name")
		
		# Calculate knockback direction
		var knockback_dir = Vector2(direction, -0.2).normalized()
		
		# Apply damage and knockback
		body.take_damage(damage, knockback_dir, knockback_force)
		
		# Debug info
		if wielder_ref:
			if DEBUG:
				print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " projectile")
			else:
				print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " projectile")
		
		# Apply effects on hit
		on_hit(body)
		
		# Check if this is a piercing projectile
		var piercing = 0
		if projectile.has_meta("piercing"):
			piercing = projectile.get_meta("piercing")
		elif "piercing" in projectile:
			piercing = int(projectile.piercing)
		
		if piercing > 0:
			# Mark target as hit
			if projectile.has_method("add_hit_target"):
				projectile.add_hit_target(body)
			
			# Only destroy if explosion is set
			var explosion_radius = 0
			if projectile.has_meta("explosion_radius"):
				explosion_radius = float(projectile.get_meta("explosion_radius"))
			elif "explosion_radius" in projectile:
				explosion_radius = float(projectile.explosion_radius)
				
			if explosion_radius > 0:
				if projectile.has_method("destroy"):
					projectile.destroy()
				else:
					projectile.queue_free()
		else:
			# Non-piercing projectile, destroy on hit
			if projectile.has_method("destroy"):
				projectile.destroy()
			else:
				projectile.queue_free()
