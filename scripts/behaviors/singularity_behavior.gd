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
	
	# Create singularity node
	var singularity = Area2D.new()
	singularity.name = "Singularity"
	
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
	
	# Set collision to affect players
	singularity.collision_layer = 0
	singularity.collision_mask = 6  # Both players (2 + 4)
	
	# Add to scene
	weapon.wielder.get_tree().current_scene.add_child(singularity)
	singularity.global_position = position
	
	# Start tracking bodies in area
	var affected_bodies = []
	singularity.body_entered.connect(func(body):
		if body != weapon.wielder and not body in affected_bodies:
			affected_bodies.append(body)
	)
	
	singularity.body_exited.connect(func(body):
		if body in affected_bodies:
			affected_bodies.erase(body)
	)
	
	# Create a timer to destroy after duration
	var timer = Timer.new()
	timer.wait_time = max_singularity_duration
	timer.one_shot = true
	singularity.add_child(timer)
	
	# Handle singularity behavior over time
	var duration = 0.0
	var process_func = func(delta):
		duration += delta
		
		# Pull nearby bodies
		for body in affected_bodies:
			if is_instance_valid(body) and body is CharacterBody2D:
				# Calculate direction to singularity
				var pull_dir = (singularity.global_position - body.global_position).normalized()
				
				# Strength based on distance (inverse square law)
				var distance = singularity.global_position.distance_to(body.global_position)
				var strength = pull_strength
				
				# Avoid division by zero and make close range stronger
				if distance > 10:
					strength = pull_strength / (distance * 0.1)
				else:
					strength = pull_strength * 5
				
				# Apply pull as force
				if "velocity" in body:
					body.velocity += pull_dir * strength * delta * 30
				
				# Also modify position directly
				body.global_position += pull_dir * strength * delta * 0.5
		
		# Grow the visual over time
		visual.scale = Vector2(1, 1) * (1 + duration / max_singularity_duration)
		
		# Increase opacity near end for dramatic effect
		if duration > max_singularity_duration * 0.8:
			visual.color.a = 0.5 + ((duration - (max_singularity_duration * 0.8)) / (max_singularity_duration * 0.2)) * 0.5
	
	# Create process handler
# Create a custom script to handle the process function
	var script = GDScript.new()
	script.source_code = """
	extends Area2D

	var process_func = null
	var duration = 0.0

	func _process(delta):
		if process_func:
			process_func.call(delta)
	"""
	script.reload()
	singularity.set_script(script)
	singularity.process_func = process_func
	singularity.duration = duration
	
	# When timer completes, create explosion
	timer.timeout.connect(func():
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
		explosion.global_position = singularity.global_position
		
		# Create fade effect
		var explosion_tween = explosion_visual.create_tween()
		explosion_tween.tween_property(explosion_visual, "scale", Vector2(1.5, 1.5), 0.3)
		explosion_tween.tween_property(explosion_visual, "modulate:a", 0.0, 0.3)
		
		# Connect to handle hits
		explosion.body_entered.connect(func(body):
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
		)
		
		# Remove explosion after effect completes
		await weapon.wielder.get_tree().create_timer(0.6).timeout
		if explosion and is_instance_valid(explosion):
			explosion.queue_free()
		
		# Remove the singularity
		singularity.queue_free()
	)
	
	timer.start()
