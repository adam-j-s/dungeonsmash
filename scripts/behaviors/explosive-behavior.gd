# improved_explosive_behavior.gd - Makes projectiles explode on impact
class_name ImprovedExplosiveBehavior
extends BehaviorBase

var explosion_radius = 60.0  # Radius of explosion
var explosion_damage_multiplier = 0.7  # Explosion deals 70% of projectile damage
var explosion_knockback_multiplier = 1.2  # Explosion has stronger knockback

func _init_behavior():
	# Get explosion parameters
	explosion_radius = float(get_param("explosion_radius", 60.0))
	explosion_damage_multiplier = float(get_param("explosion_damage_multiplier", 0.7))
	explosion_knockback_multiplier = float(get_param("explosion_knockback_multiplier", 1.2))

func get_behavior_name() -> String:
	return "ExplosiveBehavior"

func on_projectile_created(projectile):
	# Set explosion properties on the projectile
	projectile.set_meta("explosion_radius", explosion_radius)
	projectile.set_meta("explosion_damage_multiplier", explosion_damage_multiplier)
	projectile.set_meta("explosion_knockback_multiplier", explosion_knockback_multiplier)
	
	# If projectile is already an ExplosiveProjectile, update its properties
	if projectile is ExplosiveProjectile:
		projectile.explosion_radius = explosion_radius
		projectile.explosion_damage_multiplier = explosion_damage_multiplier
		projectile.explosion_knockback_multiplier = explosion_knockback_multiplier
	
	if DEBUG:
		print("Applied explosive behavior to projectile with radius: ", explosion_radius)

# Called when projectile hits something
func on_projectile_hit(projectile, target):
	# If this is an ExplosiveProjectile, let it handle its own explosion
	if projectile is ExplosiveProjectile:
		return  # Let projectile handle it
	
	# Create explosion
	create_explosion(projectile)

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	# If this is an ExplosiveProjectile, let it handle its own explosion
	if projectile is ExplosiveProjectile:
		return  # Let projectile handle it
	
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
	explosion.body_entered.connect(func(body): _on_explosion_hit(body, projectile, explosion))
	
	# Store damage and other data
	explosion.set_meta("damage", projectile.damage * explosion_damage_multiplier if "damage" in projectile else 10)
	explosion.set_meta("knockback", projectile.knockback * explosion_knockback_multiplier if "knockback" in projectile else 500)
	explosion.set_meta("wielder", projectile.wielder_ref)
	explosion.set_meta("explosion_radius", explosion_radius)
	explosion.set_meta("hit_targets", projectile.hit_targets.duplicate() if "hit_targets" in projectile else [])
	
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
