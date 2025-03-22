# Singularity attack implementation
class_name SingularityAttackStyle
extends AttackStyle

func _init_style():
	pass

func get_style_name() -> String:
	return "SingularityAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing singularity attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Create the projectile
		var projectile = CharacterBody2D.new()
		projectile.name = "SingularityBomb"
		
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
		
		# Get singularity parameters from behaviors
		var pull_strength = 800.0
		var pull_radius = 150.0
		
		# Check for singularity parameters in behaviors
		if weapon.weapon_data.has("behaviors"):
			var behaviors = weapon.weapon_data["behaviors"]
			if behaviors is Array:
				for behavior in behaviors:
					if behavior is String and behavior.begins_with("singularity:"):
						var params = behavior.split(":")
						if params.size() > 1:
							var param_parts = params[1].split(";")
							for part in param_parts:
								var kv = part.split("=")
								if kv.size() == 2:
									if kv[0] == "pull_strength":
										pull_strength = float(kv[1])
									elif kv[0] == "pull_radius":
										pull_radius = float(kv[1])
		
		# Store properties
		projectile.set_meta("damage", weapon.calculate_damage())
		projectile.set_meta("knockback", float(get_param("knockback_force", 300)))
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("flight_time", 0.0)
		projectile.set_meta("max_flight_time", 1.5)  # How long before activating
		projectile.set_meta("active", false)  # Not a singularity yet
		projectile.set_meta("explosion_radius", float(get_param("explosion_radius", 120.0)))  # Large explosion
		projectile.set_meta("pull_strength", pull_strength)
		projectile.set_meta("pull_radius", pull_radius)
		
		# Setup starting position
		var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
		projectile.global_position = spawn_position
		
		# Setup gravity arc
		projectile.velocity = Vector2(attack_direction * 500, -200)  # Initial velocity with upward component
		
		# Add to scene
		weapon.get_tree().current_scene.add_child(projectile)
		
		# Start processing
		projectile.set_process(true)
		projectile.set_physics_process(true)
		
		# Connect to process for movement
		var script_text = """
extends CharacterBody2D

var gravity = 980
var max_flight_time = 1.5
var flight_time = 0.0
var active = false
var pull_strength = 800.0
var pull_radius = 150.0
var singularity_duration = 0.0
var max_singularity_duration = 2.0
var affected_bodies = []

func _ready():
	# Get override values from metadata if available
	if has_meta("pull_strength"):
		pull_strength = get_meta("pull_strength")
	if has_meta("pull_radius"):
		pull_radius = get_meta("pull_radius")

func _physics_process(delta):
	if not active:
		# Update flight time
		flight_time += delta
		
		# Apply gravity
		velocity.y += gravity * delta
		
		# Move
		var collision = move_and_collide(velocity * delta)
		
		# Activate if we hit something or time expires
		if collision or flight_time >= max_flight_time:
			activate_singularity()
	else:
		# Update singularity duration
		singularity_duration += delta
		
		# Check for duration
		if singularity_duration >= max_singularity_duration:
			explode()
			return
			
		# Pull effect
		pull_objects(delta)
		
		# Visual effect
		var scale_factor = 1.0 + 0.2 * sin(singularity_duration * 10)
		for child in get_children():
			if child is ColorRect and child.name != 'PullVisual':
				child.scale = Vector2(scale_factor, scale_factor)
				
				# Pulse color
				child.modulate = Color(
					0.5 + 0.5 * sin(singularity_duration * 8),
					0.2,
					0.5 + 0.5 * sin(singularity_duration * 6),
					1.0
				)

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

func add_affected_body(body):
	if body.is_in_group('players') and not body in affected_bodies:
		# Don't pull the wielder
		if has_meta('wielder') and body == get_meta('wielder'):
			return
			
		affected_bodies.append(body)
		print('Added ' + body.name + ' to affected bodies')

func remove_affected_body(body):
	if body in affected_bodies:
		affected_bodies.erase(body)
		print('Removed ' + body.name + ' from affected bodies')

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
			
			# Stronger pull when closer
			var strength = pull_strength
			if dist > 10:
				strength = pull_strength / (dist * 0.1)
			else:
				strength = pull_strength * 5
				
			print('Pulling ' + body.name + ' with strength ' + str(strength) + ' at distance ' + str(dist))
			
			# Apply force
			if 'velocity' in body:
				body.velocity += pull_dir * strength * delta
				
			# Direct position change for reliable effect
			body.global_position += pull_dir * strength * delta * 0.25
			
			# When very close, accelerate toward center
			if dist < 40:
				body.global_position = body.global_position.lerp(global_position, delta * 2)

func explode():
	print('SINGULARITY EXPLODING')
	
	# Get explosion parameters
	var radius = 120
	if has_meta('explosion_radius'):
		radius = float(get_meta('explosion_radius'))
		
	var damage = 15
	if has_meta('damage'):
		damage = get_meta('damage')
		
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
			body.take_damage(int(damage * 1.5), hit_dir, 1000)
			print('Explosion hit ' + body.name)
	)
	
	# Animation
	var tween = circle.create_tween()
	tween.tween_property(circle, 'scale', Vector2(1.5, 1.5), 0.3)
	tween.tween_property(circle, 'modulate:a', 0.0, 0.3)
	
	# Remove after effect
	await get_tree().create_timer(0.6).timeout
	if explosion and is_instance_valid(explosion):
		explosion.queue_free()
	
	# Remove self
	queue_free()
"""

		# Apply the script to the projectile
		var script = GDScript.new()
		script.source_code = script_text
		script.reload()
		projectile.set_script(script)
		
		# Notify the behavior system about this projectile
		if projectile and weapon:
			weapon.on_projectile_created(projectile)
		
	# Apply visual effects
	weapon.apply_effects(null, "visual")

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
		
	# Apply effects
	on_hit(body)
