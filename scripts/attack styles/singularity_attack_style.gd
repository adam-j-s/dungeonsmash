# Apply the singularity script to the projectile

# singularity_attack_style.gd - Creates a gravity bomb that pulls enemies in before exploding
class_name SingularityAttackStyle
extends AttackStyle

var pull_strength = 800.0
var pull_radius = 150.0
var flight_time = 1.5
var singularity_duration = 2.0
var explosion_multiplier = 1.5  # Explosion deals more damage than direct hit

func _init_style():
	# Initialize singularity-specific properties
	pull_strength = float(get_param("pull_strength", 800.0))
	pull_radius = float(get_param("pull_radius", 150.0))
	flight_time = float(get_param("flight_time", 1.5))
	singularity_duration = float(get_param("singularity_duration", 2.0))
	
	if DEBUG:
		print("Singularity style initialized with pull radius: ", pull_radius, 
			  ", pull strength: ", pull_strength)

func get_style_name() -> String:
	return "SingularityAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing singularity attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder:
		print("Missing wielder reference - cannot execute attack")
		return false
	
	# Get direction based on sprite direction
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Create the projectile
	var projectile = CharacterBody2D.new()
	projectile.name = "SingularityBomb"
	
	# Set references
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("wielder_name", wielder.name)
	projectile.set_meta("weapon", weapon)
	projectile.set_meta("weapon_id", weapon.weapon_id)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15  # Larger radius for easier hits
	collision.shape = shape
	projectile.add_child(collision)
	
	# Add visual
	var visual = ColorRect.new()
	visual.color = Color(0.5, 0.0, 0.7)  # Purple for singularity
	visual.size = Vector2(30, 30)
	visual.position = Vector2(-15, -15)
	projectile.add_child(visual)
	
	# Set collision properties
	projectile.collision_layer = 0
	projectile.collision_mask = 1  # Collide with environment
	
	# Add hitbox for player collision
	var hitbox = Area2D.new()
	hitbox.name = "SingularityHitbox"
	hitbox.collision_layer = 0
	if wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
		
	var hitbox_collision = CollisionShape2D.new()
	hitbox_collision.shape = shape.duplicate()
	hitbox.add_child(hitbox_collision)
	projectile.add_child(hitbox)
	
	# Connect hit detection
	hitbox.body_entered.connect(_on_singularity_hit.bind(projectile))
	
	# Store properties
	projectile.set_meta("damage", weapon.calculate_damage())
	projectile.set_meta("knockback", float(get_param("knockback_force", 300)))
	projectile.set_meta("direction", attack_direction)
	projectile.set_meta("flight_time", 0.0)
	projectile.set_meta("max_flight_time", flight_time)
	projectile.set_meta("active", false)  # Not a singularity yet
	projectile.set_meta("explosion_radius", float(get_param("explosion_radius", 120.0)))
	projectile.set_meta("pull_strength", pull_strength)
	projectile.set_meta("pull_radius", pull_radius)
	projectile.set_meta("max_singularity_duration", singularity_duration)
	projectile.set_meta("explosion_multiplier", explosion_multiplier)
	
	# Setup starting position
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	projectile.global_position = spawn_position
	
	# Setup gravity arc
	projectile.velocity = Vector2(attack_direction * 500, -200)  # Initial velocity with upward component
	
	# Create configuration for the projectile initialization
	var config = {
		"speed": float(get_param("projectile_speed", 300)),
		"direction": attack_direction,
		"lifetime": flight_time,
		"damage": weapon.calculate_damage(),
		"knockback": float(get_param("knockback_force", 300)),
		"is_singularity": true,
		"singularity_radius": pull_radius,
		"singularity_strength": pull_strength,
		"singularity_duration": singularity_duration,
		"explosion_radius": float(get_param("explosion_radius", 120.0)),
		"gravity_factor": 0.5,  # Affected by gravity
		"vertical_velocity": -200,  # Initial upward velocity for arc
		"weapon_id": weapon.weapon_id,
		"projectile_type": "singularity"
	}
	
	# Add to scene
	wielder.get_tree().current_scene.add_child(projectile)
	
	# First apply general configuration using initialize (which uses projectile.gd's logic)
	if projectile.has_method("initialize"):
		projectile.initialize(config)
	
	# Apply the script to the projectile
	apply_singularity_script(projectile)
	
	# Notify the behavior system about this projectile
	if weapon:
		weapon.on_projectile_created(projectile)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# Callback for singularity projectile hits
func _on_singularity_hit(body, projectile):
	# Skip if it hit the wielder
	var wielder_ref = projectile.get_meta("wielder")
	if body == wielder_ref:
		return
	
	print("Singularity projectile hit: ", body.name)
	
	# Direct hit damage
	if body.has_method("take_damage"):
		var damage = projectile.get_meta("damage")
		var knockback = projectile.get_meta("knockback")
		var direction = projectile.get_meta("direction")
		
		# Apply damage
		var knockback_dir = Vector2(direction, -0.2).normalized()
		body.take_damage(damage, knockback_dir, knockback)
	
	# Immediately activate singularity
	if projectile.has_method("activate_singularity"):
		projectile.activate_singularity()
	
	# Apply hit effects
	if weapon:
		weapon.apply_effects(body, "hit")
	
	# Notify behaviors about hit
	notify_behaviors_on_hit(body)

# Notify behaviors about attack execution
func notify_behaviors_on_attack():
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_attack_executed(get_style_name())

# Notify behaviors about hit
func notify_behaviors_on_hit(target):
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_hit(target)

# Find a behavior manager to use
func find_behavior_manager():
	# First check if weapon has one
	if weapon and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	var scene = wielder.get_tree().current_scene
	if scene.has_node("BehaviorManager"):
		return scene.get_node("BehaviorManager")
	
	return null
	
func apply_singularity_script(projectile):
	var script = GDScript.new()
	
	# Create a modern version of the script without await
	# The key fix is using a raw string (r""" """) which preserves formatting better
	var script_text = r"""
extends CharacterBody2D

var gravity = 980
var flight_time = 0.0
var active = false
var pull_strength = 800.0
var pull_radius = 150.0
var singularity_duration = 0.0
var max_singularity_duration = 2.0
var explosion_multiplier = 1.5
var affected_bodies = []

func _ready():
	# Get override values from metadata
	if has_meta("pull_strength"):
		pull_strength = get_meta("pull_strength")
	if has_meta("pull_radius"):
		pull_radius = get_meta("pull_radius")
	if has_meta("max_singularity_duration"):
		max_singularity_duration = get_meta("max_singularity_duration")
	if has_meta("explosion_multiplier"):
		explosion_multiplier = get_meta("explosion_multiplier")
	
	# Add to physics group
	add_to_group("physics_process")

func _physics_process(delta):
	if not active:
		# Update flight time
		flight_time += delta
		
		# Apply gravity
		velocity.y += gravity * delta
		
		# Move with collision detection
		var collision = move_and_collide(velocity * delta)
		
		# Activate if we hit something or time expires
		if collision or flight_time >= get_meta("max_flight_time", 1.5):
			activate_singularity()
	else:
		# Update singularity duration
		singularity_duration += delta
		
		# Check for duration expiration
		if singularity_duration >= max_singularity_duration:
			explode()
			return
			
		# Pull effect
		pull_objects(delta)
		
		# Visual pulsing effect
		apply_visual_effects(delta)

# Apply pulsing visual effects while active
func apply_visual_effects(delta):
	var scale_factor = 1.0 + 0.2 * sin(singularity_duration * 10)
	for child in get_children():
		if child is ColorRect and child.name != 'PullVisual':
			# Scale pulsing
			child.scale = Vector2(scale_factor, scale_factor)
			
			# Color pulsing - shifting purples
			child.modulate = Color(
				0.5 + 0.5 * sin(singularity_duration * 8),
				0.2,
				0.5 + 0.5 * sin(singularity_duration * 6),
				1.0
			)

# Activate the singularity pull
func activate_singularity():
	# Only activate once
	if active:
		return
		
	active = true
	print('SINGULARITY ACTIVATED at position ' + str(global_position))
	
	# Stop movement
	velocity = Vector2.ZERO
	
	# Visual effect - pulse ring
	var ring = ColorRect.new()
	ring.name = 'PullVisual'
	ring.color = Color(0.7, 0.0, 1.0, 0.3)
	var ring_size = pull_radius * 2
	ring.size = Vector2(ring_size, ring_size)
	ring.position = Vector2(-ring_size/2, -ring_size/2)
	add_child(ring)
	
	# Create pulsing animation
	var ring_tween = ring.create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(1.1, 1.1), 0.5)
	ring_tween.tween_property(ring, "scale", Vector2(0.9, 0.9), 0.5)
	ring_tween.set_loops()
	
	# Setup area for detecting bodies to pull
	var pull_area = Area2D.new()
	pull_area.name = 'PullArea'
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pull_radius
	collision.shape = shape
	pull_area.add_child(collision)
	
	# Set collision to detect players
	pull_area.collision_layer = 0
	pull_area.collision_mask = 6  # Both players
	
	# Connect signals
	pull_area.body_entered.connect(func(body): add_affected_body(body))
	pull_area.body_exited.connect(func(body): remove_affected_body(body))
	
	# Add to scene
	add_child(pull_area)
	
	# Immediately check for bodies in range
	for body in get_tree().get_nodes_in_group('players'):
		var dist = global_position.distance_to(body.global_position)
		if dist <= pull_radius:
			add_affected_body(body)
	
	# Enhance particle effects
	for particle in get_children():
		if particle is CPUParticles2D:
			particle.amount = 40
			particle.lifetime = 1.2
			particle.orbit_velocity_min = 4.0
			particle.orbit_velocity_max = 8.0

# Track bodies affected by the singularity
func add_affected_body(body):
	if body.is_in_group('players') and not body in affected_bodies:
		# Don't pull the wielder
		if has_meta('wielder') and body == get_meta('wielder'):
			return
			
		affected_bodies.append(body)
		print('Added ' + body.name + ' to affected bodies')

# Remove body from affected list
func remove_affected_body(body):
	if body in affected_bodies:
		affected_bodies.erase(body)
		print('Removed ' + body.name + ' from affected bodies')
		
		# Remove trail if it exists
		var trail = body.get_node_or_null("PullTrail_" + body.name)
		if trail:
			trail.queue_free()

# Pull objects toward the singularity
func pull_objects(delta):
	# Keep checking for new bodies
	if randf() < 0.1:  # Occasionally refresh the list
		for body in get_tree().get_nodes_in_group('players'):
			if not body in affected_bodies:
				var dist = global_position.distance_to(body.global_position)
				if dist <= pull_radius:
					add_affected_body(body)
	
	for body in affected_bodies:
		if is_instance_valid(body):
			# Direction to singularity
			var pull_dir = global_position - body.global_position
			var dist = pull_dir.length()
			pull_dir = pull_dir.normalized()
			
			# Stronger pull when closer (inverse square law)
			var strength = pull_strength
			if dist > 10:
				strength = pull_strength / (dist * 0.1)
			else:
				strength = pull_strength * 5
			
			# Apply force
			if 'velocity' in body:
				body.velocity += pull_dir * strength * delta
				
			# Direct position change for reliable effect
			body.global_position += pull_dir * strength * delta * 0.25
			
			# When very close, accelerate toward center
			if dist < 40:
				body.global_position = body.global_position.lerp(global_position, delta * 2)

# Create the explosion
func explode():
	print('SINGULARITY EXPLODING')
	
	# Get explosion parameters
	var radius = 120
	if has_meta('explosion_radius'):
		radius = float(get_meta('explosion_radius'))
		
	var damage = 15
	if has_meta('damage'):
		damage = int(get_meta('damage') * explosion_multiplier)
		
	var wielder_ref = null
	if has_meta('wielder'):
		wielder_ref = get_meta('wielder')
	
	# Create explosion node
	var explosion = Area2D.new()
	explosion.name = 'Explosion'
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	explosion.add_child(collision)
	
	# Set collision properties
	explosion.collision_layer = 0
	explosion.collision_mask = 6  # Both players
	
	# Add visual
	var circle = ColorRect.new()
	circle.color = Color(1.0, 0.5, 0.0, 0.7)  # Orange explosion
	var size = radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)
	explosion.add_child(circle)
	
	# Add particles for more impact
	var particles = CPUParticles2D.new()
	particles.amount = 100
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	particles.spread = 180
	particles.initial_velocity_min = 200
	particles.initial_velocity_max = 400
	particles.scale_amount = 3
	particles.color = Color(1.0, 0.6, 0.1)
	explosion.add_child(particles)
	
	# Store data for hit handling
	explosion.set_meta('damage', damage)
	explosion.set_meta('wielder', wielder_ref)
	
	# Add to scene
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# Connect hit detection
	explosion.body_entered.connect(func(body):
		# Skip wielder
		if body == wielder_ref:
			return
			
		# Apply damage
		if body.has_method('take_damage'):
			var hit_dir = (body.global_position - global_position).normalized()
			body.take_damage(damage, hit_dir, 1000)
			print('Explosion hit ' + body.name)
	)
	
	# Animation
	var tween = circle.create_tween()
	tween.tween_property(circle, 'scale', Vector2(1.5, 1.5), 0.3)
	tween.tween_property(circle, 'modulate:a', 0.0, 0.3)
	
	# Create timer to remove after effect
	var timer = Timer.new()
	timer.wait_time = 0.6
	timer.one_shot = true
	explosion.add_child(timer)
	timer.timeout.connect(func():
		if explosion and is_instance_valid(explosion):
			explosion.queue_free()
	)
	timer.start()
	
	# Remove self
	queue_free()
"""
	
	script.source_code = script_text
	script.reload()
	projectile.set_script(script)
