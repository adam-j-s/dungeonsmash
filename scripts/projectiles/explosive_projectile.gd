# explosive_projectile.gd - Projectile that explodes on impact
class_name ExplosiveProjectile
extends ProjectileBase

var explosion_radius = 60.0  # Radius of explosion
var explosion_damage_multiplier = 0.7  # Explosion deals 70% of projectile damage
var explosion_knockback_multiplier = 1.2  # Explosion has stronger knockback
var already_exploded = false  # Flag to prevent multiple explosions

func _ready():
	super._ready()
	
	# Get explosion radius from metadata if available
	if has_meta("explosion_radius"):
		explosion_radius = get_meta("explosion_radius")
	
	# Set visual appearance - orange for explosive projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(1.0, 0.6, 0.2)  # Orange color
	
	# Adjust collision mask - explosive projectiles should hit both world and enemies
	setup_collision_masks()

# Override to handle explosions on collision
func _handle_collision(collision):
	var collider = collision.get_collider()
	
	# Always create an explosion on collision
	create_explosion()
	
	# Check if this is a world object (not a player)
	var is_world = !collider.has_method("take_damage")
	
	if !is_world and collider != wielder_ref:
		# Handle direct hit with enemy
		_handle_hit(collider)
	
	# Destroy the projectile
	destroy()

# Override to create explosion on hit
func _handle_hit(target):
	# Call the parent method for direct hit damage
	super._handle_hit(target)
	
	# Create explosion
	create_explosion()

# Override to create explosion at end of lifetime
func on_lifetime_end():
	create_explosion()
	super.on_lifetime_end()

# Create an explosion at the projectile's position
func create_explosion():
	# Avoid creating multiple explosions
	if already_exploded:
		return
	
	already_exploded = true
	
	if explosion_radius <= 0:
		return
		
	if DEBUG:
		print("Creating explosion with radius: ", explosion_radius)
	
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
	
	# Add to scene
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# Create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(_on_explosion_hit)
	
	# Store damage and other data
	explosion.set_meta("damage", int(damage * explosion_damage_multiplier))
	explosion.set_meta("knockback", knockback * explosion_knockback_multiplier)
	explosion.set_meta("wielder", wielder_ref)
	explosion.set_meta("explosion_radius", explosion_radius)
	explosion.set_meta("hit_targets", hit_targets.duplicate())  # Copy hit targets
	
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
	# Get explosion instance
	var explosion = body.get_parent()
	
	# Get data from explosion
	var explosion_damage = explosion.get_meta("damage")
	var explosion_knockback = explosion.get_meta("knockback") 
	var wielder_ref = explosion.get_meta("wielder")
	var radius = explosion.get_meta("explosion_radius")
	var hit_targets = explosion.get_meta("hit_targets")
	
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
		var hit_dir = (body.global_position - explosion.global_position).normalized()
		
		# Apply falloff based on distance
		var distance = body.global_position.distance_to(explosion.global_position)
		var distance_factor = 1.0 - min(distance / radius, 1.0)
		var adjusted_damage = int(explosion_damage * distance_factor)
		var adjusted_knockback = explosion_knockback * distance_factor
		
		# Apply damage and knockback
		body.take_damage(adjusted_damage, hit_dir, adjusted_knockback)
		
		if DEBUG:
			print("Explosion dealt ", adjusted_damage, " damage to ", body.name)
		
		# Apply hit effects from the weapon if available
		if is_instance_valid(wielder_ref) and wielder_ref.has_node("Weapon"):
			var weapon = wielder_ref.get_node("Weapon")
			if weapon and weapon.has_method("apply_effects"):
				weapon.apply_effects(body, "explosion")
