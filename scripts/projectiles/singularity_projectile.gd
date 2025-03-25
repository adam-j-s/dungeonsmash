# singularity_projectile.gd - Projectile that creates a gravity well
class_name SingularityProjectile
extends ProjectileBase

var singularity_active = false  # Whether the singularity is active
var singularity_duration = 0.0  # How long the singularity has been active
var max_singularity_duration = 2.0  # Maximum duration before explosion
var pull_radius = 150.0  # How far the pull reaches
var pull_strength = 600.0  # How strong the pull is
var affected_bodies = []  # Bodies currently being affected by the singularity

func _ready():
	super._ready()
	
	# Get singularity parameters from metadata if available
	if has_meta("pull_radius"):
		pull_radius = get_meta("pull_radius")
	if has_meta("pull_strength"):
		pull_strength = get_meta("pull_strength") 
	if has_meta("max_singularity_duration"):
		max_singularity_duration = get_meta("max_singularity_duration")
	
	# Set visual appearance - purple for singularity projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.5, 0.0, 0.7)  # Purple color
	
	# Adjust collision mask - singularity projectiles should hit both world and enemies
	setup_collision_masks()

# Override to handle singularity vs regular movement
func _process(delta):
	if singularity_active:
		# Process singularity behavior
		process_singularity(delta)
	else:
		# Let the parent handle regular movement
		super._process(delta)

# Override collision to activate singularity
func _handle_collision(collision):
	var collider = collision.get_collider()
	
	# If we hit something and we're not active yet, activate singularity
	if !singularity_active:
		activate_singularity()
	
	# Additionally handle hit with enemy
	if !collider.has_method("take_damage") == false and collider != wielder_ref:
		_handle_hit(collider)

# Override hit to activate singularity
func _handle_hit(target):
	# Call parent for direct hit damage
	super._handle_hit(target)
	
	# Activate singularity if not already active
	if !singularity_active:
		activate_singularity()

# Override lifetime end to activate singularity
func on_lifetime_end():
	# Activate singularity if not already active
	if !singularity_active:
		activate_singularity()
	else:
		# If already active, explode
		explode()

# Activate the singularity
func activate_singularity():
	if singularity_active:
		return  # Don't activate twice
	
	singularity_active = true
	singularity_duration = 0.0
	
	if DEBUG:
		print("SINGULARITY ACTIVATED at position: ", global_position)
	
	# Stop all movement
	speed = 0
	velocity = Vector2.ZERO
	
	# Create the pull area
	var pull_area = Area2D.new()
	pull_area.name = "SingularityPull"
	
	# Add collision shape for pull range
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pull_radius
	collision.shape = shape
	pull_area.add_child(collision)
	
	# Set collision to affect players
	pull_area.collision_layer = 0
	pull_area.collision_mask = 6  # Both players (2 + 4)
	
	# Connect body detection signals
	pull_area.body_entered.connect(_on_pull_area_body_entered)
	pull_area.body_exited.connect(_on_pull_area_body_exited)
	
	# Add visual ring effect
	var ring = ColorRect.new()
	ring.color = Color(0.7, 0.0, 1.0, 0.3)  # Purple with transparency
	var size = pull_radius * 2
	ring.size = Vector2(size, size)
	ring.position = Vector2(-size/2, -size/2)  # Center it
	
	# Modify the existing projectile appearance
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.7, 0.0, 0.9)  # Brighter purple
			child.size = Vector2(30, 30)  # Make it bigger
			child.position = Vector2(-15, -15)  # Recenter
	
	# Add the new visual elements
	add_child(pull_area)
	add_child(ring)
	
	# Check immediately for bodies in range
	var bodies = get_tree().get_nodes_in_group("players")
	for body in bodies:
		if body != wielder_ref and body is CharacterBody2D:
			var distance = global_position.distance_to(body.global_position)
			if distance <= pull_radius:
				if not body in affected_bodies:
					affected_bodies.append(body)
					if DEBUG:
						print("Added body to affected list: ", body.name)

# Process singularity behavior
func process_singularity(delta):
	# Update singularity lifetime
	singularity_duration += delta
	
	# Check if singularity duration is over
	if singularity_duration >= max_singularity_duration:
		if DEBUG:
			print("SINGULARITY EXPLODING!")
		explode()
		return
	
	# Pull nearby objects
	pull_objects(delta)
	
	# Visual effects (pulsing)
	var scale_factor = 1.0 + 0.2 * sin(singularity_duration * 10)
	modulate = Color(0.5 + 0.5 * sin(singularity_duration * 8), 
				0.2, 
				0.5 + 0.5 * sin(singularity_duration * 6),
				1.0)
	
	# Scale any visual children for pulse effect
	for child in get_children():
		if child is ColorRect:
			child.scale = Vector2(scale_factor, scale_factor)

# Track objects in pull range
func _on_pull_area_body_entered(body):
	# Don't affect the wielder
	if body == wielder_ref:
		return
		
	# Only care about physics bodies we can pull
	if body is CharacterBody2D and not body in affected_bodies:
		affected_bodies.append(body)
		if DEBUG:
			print("Body entered pull area: ", body.name)

func _on_pull_area_body_exited(body):
	if body in affected_bodies:
		affected_bodies.erase(body)
		if DEBUG:
			print("Body exited pull area: ", body.name)

# Pull objects toward the singularity
func pull_objects(delta):
	# If no bodies in range, try to search for bodies that might have entered range
	if affected_bodies.size() == 0:
		var bodies = get_tree().get_nodes_in_group("players")
		for body in bodies:
			if body != wielder_ref and body is CharacterBody2D:
				var distance = global_position.distance_to(body.global_position)
				if distance <= pull_radius:
					affected_bodies.append(body)
	
	# Apply pull force to affected bodies
	for body in affected_bodies:
		if is_instance_valid(body):
			# Calculate direction to singularity
			var pull_dir = (global_position - body.global_position).normalized()
			
			# Pull strength based on distance (inverse square law for more realistic gravity)
			var distance = global_position.distance_to(body.global_position)
			var strength = pull_strength
			
			# Avoid division by zero and make pull stronger at close range
			if distance > 10:
				strength = pull_strength / (distance * 0.1)
			else:
				strength = pull_strength * 5  # Very strong at close range
			
			# Apply pull in multiple ways for more reliable effect
			if "velocity" in body:
				# Add to velocity (accumulate force)
				body.velocity += pull_dir * strength * delta * 30
			
			# Always apply direct position change too
			body.global_position += pull_dir * strength * delta * 0.5
			
			# For particularly strong pulls, teleport slightly closer
			if distance < pull_radius * 0.3:
				body.global_position = body.global_position.lerp(global_position, delta * 2)

# Create explosion at the end of singularity lifetime
func explode():
	# Create explosion effect
	var explosion_radius = 120.0
	if has_meta("explosion_radius"):
		explosion_radius = float(get_meta("explosion_radius"))
	
	# Create explosion area
	var explosion = Area2D.new()
	explosion.name = "SingularityExplosion"
	
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
	circle.color = Color(1.0, 0.2, 0.9, 0.7)  # Purplish explosion
	var size = explosion_radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	explosion.add_child(circle)
	
	# Add particles for more impact
	var particles = CPUParticles2D.new()
	particles.amount = 100
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	particles.spread = 180
	particles.initial_velocity_min = 200
	particles.initial_velocity_max = 400
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.2, 0.9)
	explosion.add_child(particles)
	
	# Add to scene
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# Create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(_on_explosion_hit)
	
	# Store damage and other data
	explosion.set_meta("damage", damage * 1.5)  # Explosion does 150% damage
	explosion.set_meta("knockback", knockback * 2.0)  # Double knockback
	explosion.set_meta("wielder", wielder_ref)
	explosion.set_meta("explosion_radius", explosion_radius)
	explosion.set_meta("hit_targets", hit_targets.duplicate())
	
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
	
	# Destroy the singularity
	queue_free()

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
		print("Singularity explosion hit: ", body.name)
	
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
			print("Singularity explosion dealt ", adjusted_damage, " damage to ", body.name)
		
		# Apply hit effects from the weapon if available
		if is_instance_valid(wielder_ref) and wielder_ref.has_node("Weapon"):
			var weapon = wielder_ref.get_node("Weapon")
			if weapon and weapon.has_method("apply_effects"):
				weapon.apply_effects(body, "explosion")
