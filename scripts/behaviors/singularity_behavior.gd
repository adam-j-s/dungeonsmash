# Creates a gravity well that pulls enemies in
class_name SingularityBehavior
extends BehaviorBase

var pull_radius = 150.0  # How far the pull reaches
var pull_strength = 600.0  # How strong the pull is
var max_singularity_duration = 2.0  # How long before explosion
var explosion_radius = 120.0  # Size of final explosion

func _init_behavior():
	# Get parameters
	pull_radius = float(get_param("pull_radius", 150.0))
	pull_strength = float(get_param("pull_strength", 600.0))
	max_singularity_duration = float(get_param("max_singularity_duration", 2.0))
	explosion_radius = float(get_param("explosion_radius", 120.0))
	
	if DEBUG:
		print("Initialized singularity behavior with pull radius: ", pull_radius, 
			  " strength: ", pull_strength, " duration: ", max_singularity_duration)

func get_behavior_name() -> String:
	return "SingularityBehavior"

func on_projectile_created(projectile):
	# Set singularity properties on the projectile
	projectile.set_meta("pull_radius", pull_radius)
	projectile.set_meta("pull_strength", pull_strength)
	projectile.set_meta("max_singularity_duration", max_singularity_duration)
	projectile.set_meta("explosion_radius", explosion_radius)
	
	# If projectile is already a SingularityProjectile, update its properties
	if projectile is SingularityProjectile:
		projectile.pull_radius = pull_radius
		projectile.pull_strength = pull_strength
		projectile.max_singularity_duration = max_singularity_duration
	
	# Change projectile color to purple
	projectile.modulate = Color(0.7, 0.0, 0.9)
	
	if DEBUG:
		print("Applied singularity behavior to projectile")

# This behavior only needs to set properties on creation,
# the SingularityProjectile handles the actual effect itself

# If needed, could implement direct handling for standard projectiles:
func on_projectile_hit(projectile, target):
	# If it's already a SingularityProjectile, let it handle the effect
	if projectile is SingularityProjectile:
		return
		
	# Otherwise, create a singularity effect at the hit point
	create_singularity_at_point(projectile.global_position)

# Create a singularity effect at a specific point
func create_singularity_at_point(position):
	# Skip if no weapon to reference
	if !weapon or !weapon.wielder:
		return
	
	# Create singularity node using our custom SingularityNode class
	var singularity = SingularityNode.new()
	singularity.name = "Singularity"
	
	# Configure singularity properties
	singularity.pull_radius = pull_radius
	singularity.pull_strength = pull_strength
	singularity.max_duration = max_singularity_duration
	singularity.explosion_radius = explosion_radius
	singularity.wielder_ref = weapon.wielder
	singularity.weapon_ref = weapon
	
	# Add visual
	var visual = ColorRect.new()
	visual.color = Color(0.7, 0.0, 0.9, 0.5)  # Purple semi-transparent
	var size = 30
	visual.size = Vector2(size, size)
	visual.position = Vector2(-size/2, -size/2)  # Center
	singularity.add_child(visual)
	
	# Create pulsing effect
	var tween = visual.create_tween().set_loops()
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(visual, "scale", Vector2(0.8, 0.8), 0.5)
	
	# Add collision for pull area
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pull_radius
	collision.shape = shape
	singularity.add_child(collision)
	
	# Set collision properties
	singularity.collision_layer = 0
	singularity.collision_mask = 6  # Both players (2 + 4)
	
	# Add to scene
	weapon.wielder.get_tree().current_scene.add_child(singularity)
	singularity.global_position = position
	
	# Connect to singularity ended signal
	var explosion_callable = func():
		# Create explosion
		create_explosion_at_point(singularity.global_position)
		
		# Clean up and remove singularity
		singularity.cleanup()
		singularity.queue_free()
	
	# Connect the signal with stored callable
	singularity.singularity_ended.connect(explosion_callable)
	
	# Store the callable for later disconnection if needed
	singularity.set_meta("explosion_callable", explosion_callable)

# Create an explosion at a specific point
func create_explosion_at_point(explosion_position):
	# Create explosion effect
	var explosion = Area2D.new()
	explosion.name = "SingularityExplosion"
	
	# Add explosion collision
	var explosion_collision = CollisionShape2D.new()
	var explosion_shape = CircleShape2D.new()
	explosion_shape.radius = explosion_radius
	explosion_collision.shape = explosion_shape
	explosion.add_child(explosion_collision)
	
	# Set collision to detect players
	explosion.collision_layer = 0
	if weapon.wielder.name == "Player1":
		explosion.collision_mask = 4  # Detect Player 2
	else:
		explosion.collision_mask = 2  # Detect Player 1
		
	# Add visual
	var explosion_visual = ColorRect.new()
	explosion_visual.color = Color(1.0, 0.2, 0.9, 0.7)  # Bright purple
	var explosion_size = explosion_radius * 2
	explosion_visual.size = Vector2(explosion_size, explosion_size)
	explosion_visual.position = Vector2(-explosion_size/2, -explosion_size/2)
	explosion.add_child(explosion_visual)
	
	# Add to scene
	weapon.wielder.get_tree().current_scene.add_child(explosion)
	explosion.global_position = explosion_position
	
	# Create fade effect
	var explosion_tween = explosion_visual.create_tween()
	explosion_tween.tween_property(explosion_visual, "scale", Vector2(1.5, 1.5), 0.3)
	explosion_tween.tween_property(explosion_visual, "modulate:a", 0.0, 0.3)
	
	# Create and store hit callable
	var hit_callable = func(body):
		# Skip hitting the wielder
		if body == weapon.wielder:
			return
			
		# Calculate damage (based on weapon's damage)
		var explosion_damage = weapon.calculate_damage() * 1.5  # 150% damage
		
		# Apply damage and knockback
		if body.has_method("take_damage"):
			# Calculate direction away from explosion
			var hit_dir = (body.global_position - explosion.global_position).normalized()
			
			# Apply falloff based on distance
			var distance = body.global_position.distance_to(explosion.global_position)
			var distance_factor = 1.0 - min(distance / explosion_radius, 1.0)
			var adjusted_damage = int(explosion_damage * distance_factor)
			var knockback = pull_strength * 2 * distance_factor  # Strong knockback
			
			body.take_damage(adjusted_damage, hit_dir, knockback)
	
	# Store the callable in metadata
	explosion.set_meta("hit_callable", hit_callable)
	
	# Connect to handle hits using the stored callable
	explosion.body_entered.connect(hit_callable)
	
	# Create cleanup function for the explosion
	var cleanup_func = func():
		if explosion and is_instance_valid(explosion):
			# Disconnect signal before freeing
			if explosion.has_meta("hit_callable"):
				var callable = explosion.get_meta("hit_callable")
				if explosion.is_connected("body_entered", callable):
					explosion.disconnect("body_entered", callable)
			explosion.queue_free()
	
	# Wait and then clean up
	await weapon.wielder.get_tree().create_timer(0.6).timeout
	cleanup_func.call()
