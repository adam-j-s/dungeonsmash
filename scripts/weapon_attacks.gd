# weapon_attacks.gd - Handles all weapon attack styles
extends Node

# References
var weapon = null  # Reference to parent weapon
var wielder = null  # Direct reference to wielder for convenience

const DEBUG = false  # Set to true only when debugging

# Execute the appropriate attack based on style
func execute_attack(attack_style: String):
	match attack_style:
		"melee":
			print("Using melee attack")
			perform_melee_attack()
		"projectile":
			print("Using projectile attack")
			perform_projectile_attack()
		"wave":
			print("Using wave attack")
			perform_wave_attack()
		"pull":
			print("Using pull attack")
			perform_pull_attack()
		"push":
			print("Using push attack")
			perform_push_attack()
		"area":
			print("Using area attack")
			perform_area_attack()
		"singularity":  # Add this new attack style
			print("Using singularity attack")
			perform_singularity_attack()
		_:
			# Default fallback attack
			print("Using default melee attack")
			perform_melee_attack()

# Melee attack style
func perform_melee_attack():
	# Create hitbox for melee damage
	create_hitbox()
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Projectile attack style - Updated to handle multiple projectiles and advanced properties
func perform_projectile_attack():
	# Projectile attack
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Get number of projectiles to fire
		var projectile_count = int(weapon.weapon_data.get("projectile_count", "1"))
		var projectile_spread = float(weapon.weapon_data.get("projectile_spread", "0"))
		
		# Only load script once for efficiency
		var script_res = load("res://scripts/projectile.gd")
		if !script_res:
			print("ERROR: Could not load projectile.gd script!")
			return
			
		# Calculate the starting angle for spread shots
		var spread_start = 0
		if projectile_count > 1 and projectile_spread > 0:
			spread_start = -projectile_spread / 2.0
		
		# Create each projectile
		for i in range(projectile_count):
			# Calculate angle for this projectile in the spread
			var angle = 0.0
			var gravity_modifier = 1.0
			
			if projectile_count > 1 and projectile_spread > 0:
				if weapon.weapon_id == "cluster_bomb":
					# For cluster bombs, create distinct arcs
					if i == 0:
						angle = -30  # Upward angle
						gravity_modifier = 0.8  # Less gravity for higher arc
					elif i == 1:
						angle = 0    # Straight ahead
						gravity_modifier = 1.0  # Normal gravity
					else:
						angle = 30   # Downward angle
						gravity_modifier = 1.2  # More gravity for steeper arc
				else:
					# For non-cluster bombs, use normal spread calculation
					angle = spread_start + (projectile_spread / (projectile_count - 1)) * i
			
			# Apply modified gravity for cluster bombs
			var adjusted_gravity = float(weapon.weapon_data.get("gravity_factor", 0.0))
			if weapon.weapon_id == "cluster_bomb":
				adjusted_gravity *= gravity_modifier
			
			# Create the projectile
			var projectile = create_projectile(script_res, attack_direction, angle, adjusted_gravity)
			
			# Notify the behavior system about this projectile
			if projectile and weapon:
				weapon.on_projectile_created(projectile)
		
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Helper function to create an individual projectile
func create_projectile(script_res, attack_direction, angle_degrees = 0.0, gravity_override = 0.0):
	# Create the projectile with proper error checking
	var projectile = CharacterBody2D.new()
	projectile.name = "Projectile_" + weapon.weapon_id
	
	# Apply script BEFORE adding to scene tree
	projectile.set_script(script_res)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)

	# Add visual
	var visual = ColorRect.new()

	# Get base and tint colors
	var base_color = Color(0.2, 0.2, 0.8)  # Default blue
	if weapon.get_weapon_type() == "sword":
		base_color = Color(0.8, 0.2, 0.2)  # Red for sword projectiles
		
	var tier = int(weapon.weapon_data.get("tier", 0))
	var tier_factor = min(tier * 0.2, 0.8)
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)

	visual.color = final_color
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	projectile.add_child(visual)

	# Set collision properties
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 4  # Detect Player 2
	else:
		projectile.collision_mask = 2  # Detect Player 1

	# Set up an Area2D for hit detection
	var hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = projectile.collision_mask
	var hitbox_collision = CollisionShape2D.new()
	hitbox_collision.shape = shape.duplicate()
	hitbox.add_child(hitbox_collision)
	projectile.add_child(hitbox)

	# Connect signal for hit detection
	hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))

	# Calculate properties
	var projectile_speed = float(weapon.weapon_data.get("projectile_speed", 400))
	var projectile_lifetime = float(weapon.weapon_data.get("projectile_lifetime", 0.8))
	
	# Convert angle to radians and calculate direction vector
	var angle_rad = deg_to_rad(angle_degrees)
	var dir_vector = Vector2(cos(angle_rad), sin(angle_rad)) * attack_direction
	if angle_degrees == 0:
		dir_vector = Vector2(attack_direction, 0)

	# Store metadata on the projectile
	projectile.set_meta("damage", weapon.calculate_damage())
	projectile.set_meta("knockback", float(weapon.weapon_data.get("knockback_force", 500)))
	projectile.set_meta("direction", attack_direction)
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("effects", weapon.weapon_data.get("effects", []))
	projectile.set_meta("weapon_id", weapon.weapon_id)
	projectile.set_meta("weapon_name", weapon.get_weapon_name())

	# Position with angle offset if needed
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	projectile.global_position = spawn_position
	
	# Use the gravity override if provided
	var gravity_value = gravity_override if gravity_override > 0.0 else float(weapon.weapon_data.get("gravity_factor", 0.0))
	
	# Initialize BEFORE adding to the scene with advanced properties
	if projectile.has_method("initialize"):
		# Setup basic parameters for all projectiles
		var init_params = {
			"speed": projectile_speed,
			"direction": dir_vector.x,  # For angled shots
			"lifetime": projectile_lifetime,
			"damage": weapon.calculate_damage(),
			"knockback": float(weapon.weapon_data.get("knockback_force", 500)),
			"effects": weapon.weapon_data.get("effects", []),
			"bounce_count": int(weapon.weapon_data.get("bounce_count", 0)),
			"homing_strength": float(weapon.weapon_data.get("homing_strength", 0.0)),
			"gravity_factor": gravity_value,
			"piercing": int(weapon.weapon_data.get("piercing", 0)),
			"explosion_radius": float(weapon.weapon_data.get("explosion_radius", 0))
		}
			
		# Initialize with all parameters
		projectile.initialize(init_params)
	else:
		print("ERROR: Projectile script has no initialize method!")
		return null

	# Now add to scene AFTER initialization
	weapon.get_tree().current_scene.add_child(projectile)

	# Force update position once more to ensure it's correct
	projectile.global_position = spawn_position

	if DEBUG:
		print("Projectile launched at: " + str(projectile.global_position) + 
			" with direction: " + str(dir_vector) + 
			" and speed: " + str(projectile_speed))

	return projectile  # Return the created projectile

	# Singularity attack - creates a projectile that turns into a gravitational singularity
func perform_singularity_attack():
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
		
		# Store properties
		projectile.set_meta("damage", weapon.calculate_damage())
		projectile.set_meta("knockback", float(weapon.weapon_data.get("knockback_force", 300)))
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("flight_time", 0.0)
		projectile.set_meta("max_flight_time", 1.5)  # How long before activating
		projectile.set_meta("active", false)  # Not a singularity yet
		projectile.set_meta("explosion_radius", 120.0)  # Large explosion
		
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

	# Wave attack - projectile that moves in a wave pattern
func perform_wave_attack():
		if wielder:
			# Get direction based on sprite direction
			var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			
			# Similar to projectile attack but with wave properties
			var projectile = CharacterBody2D.new()
			projectile.name = "WaveProjectile_" + weapon.weapon_id
			
			# First, try to load the wave projectile script
			var script_res = load("res://scripts/projectile.gd")  # We'll use the same base script
			if !script_res:
				print("ERROR: Could not load projectile script!")
				return
				
			# Apply script BEFORE adding to scene tree
			projectile.set_script(script_res)
			
			# Add collision shape
			var collision = CollisionShape2D.new()
			var shape = CircleShape2D.new()
			shape.radius = 10
			collision.shape = shape
			projectile.add_child(collision)
			
			# Add visual
			var visual = ColorRect.new()
			var base_color = Color(0.3, 0.7, 0.9)  # Cyan-blue for wave
			var tier = int(weapon.weapon_data.get("tier", 0))
			var tier_factor = min(tier * 0.2, 0.8)
			var gold_color = Color(1.0, 0.8, 0.0)
			var final_color = base_color.lerp(gold_color, tier_factor)
			
			visual.color = final_color
			visual.size = Vector2(20, 20)
			visual.position = Vector2(-10, -10)
			projectile.add_child(visual)
			
			# Set collision properties
			projectile.collision_layer = 0
			if wielder.name == "Player1":
				projectile.collision_mask = 4
			else:
				projectile.collision_mask = 2
				
			# Set up hit detection
			var hitbox = Area2D.new()
			hitbox.collision_layer = 0
			hitbox.collision_mask = projectile.collision_mask
			var hitbox_collision = CollisionShape2D.new()
			hitbox_collision.shape = shape.duplicate()
			hitbox.add_child(hitbox_collision)
			projectile.add_child(hitbox)
			
			# Connect signal
			hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))
			
			# Calculate properties
			var projectile_speed = float(weapon.weapon_data.get("projectile_speed", 350))
			var projectile_lifetime = float(weapon.weapon_data.get("projectile_lifetime", 1.2))
			
			# Store metadata
			projectile.set_meta("damage", weapon.calculate_damage())
			projectile.set_meta("knockback", float(weapon.weapon_data.get("knockback_force", 400)))
			projectile.set_meta("direction", attack_direction)
			projectile.set_meta("wielder", wielder)
			projectile.set_meta("weapon_name", weapon.get_weapon_name())
			projectile.set_meta("is_wave", true)  # Mark as wave projectile
			projectile.set_meta("wave_amplitude", 50.0)  # How high the wave goes
			projectile.set_meta("wave_frequency", 3.0)  # How many waves per second
			
			# Position in front of player
			var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
			projectile.global_position = spawn_position
			
			# Initialize before adding to scene
			if projectile.has_method("initialize"):
				projectile.initialize({
					"speed": projectile_speed,
					"direction": attack_direction,
					"lifetime": projectile_lifetime,
					"damage": weapon.calculate_damage(),
					"knockback": float(weapon.weapon_data.get("knockback_force", 400)),
					"is_wave": true,
					"wave_amplitude": 50.0,
					"wave_frequency": 3.0,
					"bounce_count": int(weapon.weapon_data.get("bounce_count", 0)),
					"homing_strength": float(weapon.weapon_data.get("homing_strength", 0.0)),
					"explosion_radius": float(weapon.weapon_data.get("explosion_radius", 0)),
					"piercing": int(weapon.weapon_data.get("piercing", 0))
				})
			else:
				print("ERROR: Projectile script has no initialize method!")
				return
				
			# Add to scene
			weapon.get_tree().current_scene.add_child(projectile)
			
			# Force position update
			projectile.global_position = spawn_position
			
			# Notify the behavior system about this projectile
			if projectile and weapon:
				weapon.on_projectile_created(projectile)
		
		# Apply visual effects
		weapon.apply_effects(null, "visual")

# Pull attack - pulls enemies toward the player
func perform_pull_attack():
		if wielder:
			# Creates a hitbox that pulls enemies toward the player
			var pull_hitbox = Area2D.new()
			pull_hitbox.name = "PullHitbox"
			
			# Add a larger collision shape
			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = weapon.weapon_data.get("attack_range", Vector2(60, 40))  # Wider pull area
			collision.shape = shape
			pull_hitbox.add_child(collision)
			
			# Position in front of player
			var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			pull_hitbox.position.x = attack_direction * (shape.size.x / 2)
			
			# Set collision properties
			pull_hitbox.collision_layer = 0
			if wielder.name == "Player1":
				pull_hitbox.collision_mask = 4
			else:
				pull_hitbox.collision_mask = 2
				
			# Connect special pull signal
			pull_hitbox.body_entered.connect(_on_pull_hit)
			
			# Add visual effect for the pull (a brief line indicating the pull)
			var pull_visual = Line2D.new()
			pull_visual.width = 5
			pull_visual.default_color = Color(0.8, 0.2, 0.8, 0.7)  # Purple for pull
			pull_visual.add_point(Vector2.ZERO)
			pull_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
			pull_hitbox.add_child(pull_visual)
			
			# Add to wielder
			if wielder:
				wielder.add_child(pull_hitbox)
				
				# Remove after short duration
				await weapon.get_tree().create_timer(0.3).timeout
				if pull_hitbox and is_instance_valid(pull_hitbox):
					pull_hitbox.queue_free()
		
		# Apply visual effects
		weapon.apply_effects(null, "visual")
		
		# Notify when attack ends
		if weapon:
			weapon.on_attack_end()

func _on_pull_hit(body):
		if body == wielder:
			return  # Don't pull yourself
			
		if DEBUG:
			print("Pull hit: ", body.name)
		else:
			print("Pull hit: ", body.name)
		
		# Check if the body can take damage
		if body.has_method("take_damage"):
			# Calculate pull direction (toward player)
			var pull_dir = (wielder.global_position - body.global_position).normalized()
			
			# Calculate damage
			var effective_damage = weapon.calculate_damage()
			
			# Apply damage with standard knockback (this will be minimal)
			body.take_damage(effective_damage, pull_dir, 50)
			
			# Direct position manipulation for pulling
			if body is CharacterBody2D:
				# Calculate pull distance based on weapon knockback
				var pull_strength = float(weapon.weapon_data.get("knockback_force", 300.0))
				var pull_distance = pull_dir * pull_strength * 0.5  # Adjust multiplier as needed
				
				# Apply direct position change
				body.global_position += pull_distance
				
				# Optionally also set velocity for smoother motion
				if body.has_method("set_velocity"):
					body.set_velocity(pull_dir * pull_strength)
				elif "velocity" in body:
					body.velocity = pull_dir * pull_strength
			
			# Debug info
			if DEBUG:
				print(wielder.name + " pulls " + body.name + " with " + weapon.get_weapon_name())
			else:
				print(wielder.name + " pulls " + body.name + " with " + weapon.get_weapon_name())
			
			# Apply effects
			weapon.apply_effects(body, "hit")

	# Push attack - pushes enemies away from the player
func perform_push_attack():
		if wielder:
			# Similar to pull but with opposite effect
			var push_hitbox = Area2D.new()
			push_hitbox.name = "PushHitbox"
			
			# Add collision shape
			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = weapon.weapon_data.get("attack_range", Vector2(60, 40))
			collision.shape = shape
			push_hitbox.add_child(collision)
			
			# Position in front of player
			var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			push_hitbox.position.x = attack_direction * (shape.size.x / 2)
			
			# Set collision properties
			push_hitbox.collision_layer = 0
			if wielder.name == "Player1":
				push_hitbox.collision_mask = 4
			else:
				push_hitbox.collision_mask = 2
				
			# Connect special push signal
			push_hitbox.body_entered.connect(_on_push_hit)
			
			# Add visual effect
			var push_visual = Line2D.new()
			push_visual.width = 5
			push_visual.default_color = Color(0.2, 0.8, 0.2, 0.7)  # Green for push
			push_visual.add_point(Vector2.ZERO)
			push_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
			push_hitbox.add_child(push_visual)
			
			# Add to wielder
			if wielder:
				wielder.add_child(push_hitbox)
				
				# Remove after short duration
				await weapon.get_tree().create_timer(0.3).timeout
				if push_hitbox and is_instance_valid(push_hitbox):
					push_hitbox.queue_free()
		
		# Apply visual effects
		weapon.apply_effects(null, "visual")
		
		# Notify when attack ends
		if weapon:
			weapon.on_attack_end()

func _on_push_hit(body):
		if body == wielder:
			return  # Don't push yourself
			
		if DEBUG:
			print("Push hit: ", body.name)
		else:
			print("Push hit: ", body.name)
		
		# Check if the body can take damage
		if body.has_method("take_damage"):
			# Calculate push direction (away from player)
			var push_dir = (body.global_position - wielder.global_position).normalized()
			
			# Calculate damage
			var effective_damage = weapon.calculate_damage()
			
			# Apply damage and extra strong knockback
			body.take_damage(effective_damage, push_dir, float(weapon.weapon_data.get("knockback_force", 300.0)) * 1.5)
			
			# Debug info
			if DEBUG:
				print(wielder.name + " pushes " + body.name + " with " + weapon.get_weapon_name())
			else:
				print(wielder.name + " pushes " + body.name + " with " + weapon.get_weapon_name())
				
			# Apply effects
			weapon.apply_effects(body, "hit")

	# Area attack - damages enemies in a larger area
func perform_area_attack():
		if wielder:
			# Create a circular hitbox for area damage
			var area_hitbox = Area2D.new()
			area_hitbox.name = "AreaHitbox"
			
			# Add circular collision shape
			var collision = CollisionShape2D.new()
			var shape = CircleShape2D.new()
			var attack_range = weapon.weapon_data.get("attack_range", Vector2(50, 50))
			if attack_range is Vector2:
				shape.radius = attack_range.x / 2  # Use X as radius
			else:
				shape.radius = 25  # Default fallback
			collision.shape = shape
			area_hitbox.add_child(collision)
			
			# Position around player
			area_hitbox.position = Vector2.ZERO  # Centered on player
			
			# Set collision properties
			area_hitbox.collision_layer = 0
			if wielder.name == "Player1":
				area_hitbox.collision_mask = 4
			else:
				area_hitbox.collision_mask = 2
				
			# Connect hit signal
			area_hitbox.body_entered.connect(_on_area_hit)
			
			# Add visual effect (circle expanding outward)
			var circle = ColorRect.new()
			circle.color = Color(0.9, 0.3, 0.1, 0.5)  # Orange for area attack
			var size = shape.radius * 2
			circle.size = Vector2(size, size)
			circle.position = Vector2(-size/2, -size/2)  # Center the rect
			circle.scale = Vector2(0.1, 0.1)  # Start small
			area_hitbox.add_child(circle)
			
			# Add to wielder FIRST
			if wielder:
				wielder.add_child(area_hitbox)
				
				# NOW create the tween after adding to scene
				var tween = circle.create_tween()
				tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
				
				# Remove after short duration
				await weapon.get_tree().create_timer(0.3).timeout
				if area_hitbox and is_instance_valid(area_hitbox):
					area_hitbox.queue_free()
		
		# Apply visual effects
		weapon.apply_effects(null, "visual")
		
		# Notify when attack ends
		if weapon:
			weapon.on_attack_end()

func _on_area_hit(body):
		if body == wielder:
			return  # Don't hit yourself
			
		if DEBUG:
			print("Area hit: ", body.name)
		else:
			print("Area hit: ", body.name)
		
		# Check if the body can take damage
		if body.has_method("take_damage"):
			# Calculate direction (away from player)
			var hit_dir = (body.global_position - wielder.global_position).normalized()
			
			# Calculate damage with a small area damage bonus
			var effective_damage = int(weapon.calculate_damage() * 1.2)
			
			# Apply damage and knockback
			body.take_damage(effective_damage, hit_dir, float(weapon.weapon_data.get("knockback_force", 300.0)))
			
			# Debug info
			if DEBUG:
				print(wielder.name + " hits " + body.name + " with area attack from " + weapon.get_weapon_name())
			else:
				print(wielder.name + " hits " + body.name + " with area attack from " + weapon.get_weapon_name())
			
			# Apply effects
			weapon.apply_effects(body, "hit")
			
	# Handle projectile hits - Updated to handle piercing and explosions
func _on_projectile_hit(body, projectile):
		# Get stored values from the projectile
		var wielder_ref = projectile.get_meta("wielder")
		
		# Don't hit yourself
		if body == wielder_ref:
			return

		# Skip if already in hit targets list (for piercing)
		if projectile.has_method("has_hit_target") and projectile.has_hit_target(body):
			return
			
		if DEBUG:
			print("Projectile hit: ", body.name)
		else:
			print("Projectile hit: ", body.name)
		
		# Check if the body can take damage
		if body.has_method("take_damage"):
			# Get more stored values from the projectile
			var damage = projectile.get_meta("damage")
			var knockback_force = projectile.get_meta("knockback")
			var direction = projectile.get_meta("direction")
			var weapon_name = projectile.get_meta("weapon_name")
			
			# Calculate knockback direction
			var knockback_dir = Vector2(direction, -0.2).normalized()
			
			# Apply damage and knockback
			body.take_damage(damage, knockback_dir, knockback_force)
			
			# Debug info
			if wielder_ref:
				if DEBUG:
					print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " projectile")
				else:
					print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " projectile")
			
			# Apply effects on hit
			weapon.apply_effects(body, "hit")
			
			# Check if this is a piercing projectile
			var piercing = 0
			if projectile.has_meta("piercing"):
				piercing = projectile.get_meta("piercing")
			elif "piercing" in projectile:
				piercing = int(projectile.piercing)
			
			if piercing > 0:
				# Mark target as hit
				if projectile.has_method("add_hit_target"):
					projectile.add_hit_target(body)
				
				# Only destroy if explosion is set
				var explosion_radius = 0
				if projectile.has_meta("explosion_radius"):
					explosion_radius = float(projectile.get_meta("explosion_radius"))
				elif "explosion_radius" in projectile:
					explosion_radius = float(projectile.explosion_radius)
					
				if explosion_radius > 0:
					if projectile.has_method("destroy"):
						projectile.destroy()
					else:
						projectile.queue_free()
			else:
				# Non-piercing projectile, destroy on hit
				if projectile.has_method("destroy"):
					projectile.destroy()
				else:
					projectile.queue_free()
					
	# Create a hitbox for the attack (for melee weapons)
func create_hitbox():
		var hitbox = Area2D.new()
		hitbox.name = "WeaponHitbox"
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = weapon.weapon_data.get("attack_range", Vector2(50, 30))
		collision.shape = shape
		hitbox.add_child(collision)
		
		# Position the hitbox in front of the wielder
		if wielder and wielder.has_node("Sprite2D"):
			var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		hitbox.collision_layer = 0
		if wielder and wielder.name == "Player1":
			hitbox.collision_mask = 4  # Detect Player 2
		else:
			hitbox.collision_mask = 2  # Detect Player 1
		
		# Connect signal to detect hits
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
		# Add to wielder
		if wielder:
			wielder.add_child(hitbox)
			
			# Remove after short duration
			await weapon.get_tree().create_timer(0.2).timeout
			if hitbox and is_instance_valid(hitbox):
				hitbox.queue_free()
				
		# Notify when attack ends
		if weapon:
			weapon.on_attack_end()

	# Handle collision with the hitbox (for melee attacks)
func _on_hitbox_body_entered(body):
		if body == wielder:
			return  # Don't hit yourself
			
		if DEBUG:
			print("Weapon hit: ", body.name)
		else:
			print("Weapon hit: ", body.name)
		
		# Check if the body can take damage
		if body.has_method("take_damage"):
			# Calculate knockback direction
			var attack_direction = 1
			if wielder and wielder.has_node("Sprite2D"):
				attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
			var knockback_dir = Vector2(attack_direction, -0.3).normalized()
			
			# Calculate damage with stats
			var effective_damage = weapon.calculate_damage()
			
			# Apply damage and knockback
			body.take_damage(effective_damage, knockback_dir, float(weapon.weapon_data.get("knockback_force", 500.0)))
			
			# Debug info
			if DEBUG:
				print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
			else:
				print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
			
			# Apply hit effects
			weapon.apply_effects(body, "hit")
