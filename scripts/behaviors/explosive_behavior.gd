# explosive_behavior.gd - Makes projectiles explode on impact
class_name ExplosiveBehavior
extends Behavior

var explosion_radius = 0
var explosion_damage_multiplier = 0.7  # Explosion deals 70% of projectile damage
var explosion_knockback_multiplier = 1.2  # Explosion has stronger knockback

func _init_behavior():
	# Any additional setup specific to explosive behavior
	pass

func get_behavior_name() -> String:
	return "ExplosiveBehavior"

func on_projectile_created(projectile):
	# Get explosion radius from parameters
	explosion_radius = float(get_param("explosion_radius", 60.0))
	
	# Set properties on the projectile
	projectile.explosion_radius = explosion_radius
	projectile.set_meta("explosion_radius", explosion_radius)
	projectile.projectile_type = "explosive"
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["explosion_radius"] = explosion_radius
		config["projectile_type"] = "explosive"
		projectile.apply_config(config)
	
	# Add this behavior directly to the projectile for callbacks
	if projectile.has_method("add_behavior"):
		projectile.add_behavior(self)
	
	if DEBUG:
		print("Applied explosive behavior to projectile with radius: ", explosion_radius)

# Process function - explosives use standard movement
func on_projectile_process(projectile, delta):
	# Let the projectile handle normal movement
	return false

# Physics process - explosives use standard physics
func on_projectile_physics_process(projectile, delta):
	# Let the projectile handle standard physics
	return false

# Called when projectile hits something
func on_projectile_hit(projectile, target):
	if DEBUG:
		print("Explosive projectile hit target: ", target.name)
	
	# Create explosion on hit
	create_explosion(projectile)

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	if DEBUG:
		print("Explosive projectile destroyed")
	
	# Create explosion if not already created
	if !projectile.get_meta("explosion_created", false):
		create_explosion(projectile)

# Create an explosion at the projectile's position
func create_explosion(projectile):
	# Avoid creating multiple explosions
	if projectile.get_meta("explosion_created", false):
		return
	
	projectile.set_meta("explosion_created", true)
	
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
	if projectile.wielder_ref and projectile.wielder_ref.name == "Player1":
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
	projectile.get_tree().current_scene.add_child(explosion)
	explosion.global_position = projectile.global_position
	
	# Create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(func(body):
		_on_explosion_hit(body, projectile, explosion)
	)
	
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
func _on_explosion_hit(body, projectile, explosion):
	# Ignore the explosion hitting its owner
	if body == projectile.wielder_ref:
		return
	
	if DEBUG:
		print("Explosion hit: ", body.name)
	
	# Skip if already hit by the original projectile
	if projectile.has_method("has_hit_target") and projectile.has_hit_target(body):
		return
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction away from explosion center
		var hit_dir = (body.global_position - explosion.global_position).normalized()
		
		# Get damage from projectile
		var explosion_damage = int(projectile.damage * explosion_damage_multiplier)
		var explosion_knockback = projectile.knockback * explosion_knockback_multiplier
		
		# Apply falloff based on distance
		var distance = body.global_position.distance_to(explosion.global_position)
		var distance_factor = 1.0 - min(distance / explosion_radius, 1.0)
		explosion_damage = int(explosion_damage * distance_factor)
		explosion_knockback = explosion_knockback * distance_factor
		
		# Apply damage and knockback
		body.take_damage(explosion_damage, hit_dir, explosion_knockback)
		
		# Track this hit if the projectile supports it
		if projectile.has_method("add_hit_target"):
			projectile.add_hit_target(body)
		
		if DEBUG:
			print("Explosion dealt ", explosion_damage, " damage to ", body.name)
		
		# Apply hit effects from the weapon if available
		if is_instance_valid(projectile.wielder_ref) and projectile.wielder_ref.has_node("Weapon"):
			var weapon = projectile.wielder_ref.get_node("Weapon")
			if weapon and weapon.has_method("apply_effects"):
				weapon.apply_effects(body, "explosion")
