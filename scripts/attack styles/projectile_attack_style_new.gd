# projectile_attack_style.gd - Simplified projectile attack
extends Resource

var weapon = null
var wielder = null

func initialize(weapon_ref):
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
	print("Projectile style initialized")

func get_style_name():
	return "SimpleProjectileStyle"

func execute_attack():
	print("Executing simple projectile attack")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference")
		return
	
	# Create a simple projectile
	var projectile = CharacterBody2D.new()
	projectile.name = "SimpleProjectile"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)
	
	# Add visual
	var visual = ColorRect.new()
	visual.color = Color(0.2, 0.5, 0.8)
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	projectile.add_child(visual)
	
	# Setup collision
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 4
	else:
		projectile.collision_mask = 2
	
	# Get direction
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Store data
	projectile.set_meta("direction", attack_direction)
	projectile.set_meta("speed", 400)
	projectile.set_meta("damage", weapon.calculate_damage())
	projectile.set_meta("knockback", float(weapon.weapon_data.get("knockback_force", 500)))
	projectile.set_meta("wielder", wielder)
	
	# Connect hit detection
	var hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = projectile.collision_mask
	
	var hitbox_collision = CollisionShape2D.new()
	hitbox_collision.shape = shape.duplicate()
	hitbox.add_child(hitbox_collision)
	projectile.add_child(hitbox)
	
	# Connect signal
	hitbox.body_entered.connect(_on_hit.bind(projectile))
	
	# Position
	projectile.global_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Set initial velocity
	projectile.velocity = Vector2(attack_direction * 400, 0)
	
	# Add to scene
	wielder.get_tree().current_scene.add_child(projectile)
	
	# Attach a script that actually works
	projectile.set_script(create_projectile_script())
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

func create_projectile_script():
	# Create the script definition
	var script = GDScript.new()
	
	# The script code
	var code = """
extends CharacterBody2D

# How long the projectile lives
var lifetime = 0.0
var max_lifetime = 2.0

func _physics_process(delta):
	# Update lifetime
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	
	# The velocity is already set, just move
	var collision = move_and_collide(velocity * delta)
	if collision:
		# Hit something in the environment
		queue_free()
"""
	
	# Set the script source
	script.source_code = code
	script.reload()
	
	return script

func _on_hit(body, projectile):
	# Don't hit the wielder
	var wielder_ref = projectile.get_meta("wielder")
	if body == wielder_ref:
		return
		
	print("Projectile hit: ", body.name)
	if body.has_method("take_damage"):
		var direction = projectile.get_meta("direction")
		var dmg = projectile.get_meta("damage")
		var kdir = Vector2(direction, -0.2).normalized()
		var kforce = projectile.get_meta("knockback")
		body.take_damage(dmg, kdir, kforce)
		
		# Apply hit effects
		if weapon:
			weapon.apply_effects(body, "hit")
	
	# Destroy projectile
	projectile.queue_free()
