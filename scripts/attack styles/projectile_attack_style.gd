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
	
	# Create and fire a projectile
	create_projectile()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

func create_projectile():
	print("Creating projectile via attack style...")
	
	# Create the projectile with basic node
	var projectile = CharacterBody2D.new()
	projectile.name = "Projectile_" + str(randi())
	
	# IMPORTANT: First set script, THEN add children and configure
	var script = load("res://scripts/projectile.gd")
	if script:
		projectile.set_script(script)
		print("Successfully applied projectile script")
	else:
		print("ERROR: Could not load projectile script!")
		return null
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(20, 20)  # Define size once
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2  # Automatically centers based on size
	sprite.color = Color(1.0, 0.2, 0.2)
	projectile.add_child(sprite)

	# Add collision with matching size
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = sprite_size  # Use the same size variable
	collision.shape = shape
	projectile.add_child(collision)
	
	# Calculate direction and position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	var speed = float(weapon.weapon_data.get("projectile_speed", 400))
	
	# Position in front of wielder
	projectile.global_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Configure collision properties
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 4  # Detect Player 2
	else:
		projectile.collision_mask = 2  # Detect Player 1
	
	# THIS IS CRITICAL: Force set_process to true
	projectile.set_process(true)
	projectile.set_physics_process(true)
	
	# Now create configuration object
	var config = {
		"speed": speed,
		"direction": attack_direction,
		"lifetime": float(weapon.weapon_data.get("projectile_lifetime", 1.0)),
		"damage": weapon.calculate_damage(),
		"knockback": float(weapon.weapon_data.get("knockback_force", 500)),
		"bounce_count": int(weapon.weapon_data.get("bounce_count", 0)),
		"homing_strength": float(weapon.weapon_data.get("homing_strength", 0.0)),
		"gravity_factor": float(weapon.weapon_data.get("gravity_factor", 0.0)),
		"piercing": int(weapon.weapon_data.get("piercing", 0)),
		"explosion_radius": float(weapon.weapon_data.get("explosion_radius", 0))
	}
	
	# Initialize the projectile
	projectile.initialize(config)
	
	# Add to scene AFTER full configuration
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		print("Added projectile to scene at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add projectile to scene - no parent for wielder")
		projectile.queue_free()
		return null
	
	# Notify weapon of projectile creation
	if weapon:
		weapon.on_projectile_created(projectile)
	
	return projectile
