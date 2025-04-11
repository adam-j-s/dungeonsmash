# cluster_bomb_behavior.gd - Full bezier trajectory for natural arcs
class_name ClusterBombBehavior
extends BehaviorBase

var bomb_count = 3  # Number of grenades to launch
var explosion_radius = 40.0  # Explosion size for each bomb

func _init_behavior():
	# Get parameters with improved JSON structure handling
	var bomb_param = get_param("bomb_count", "3")
	var radius_param = get_param("explosion_radius", "40.0")
	
	# Parse bomb_count with type handling
	if typeof(bomb_param) == TYPE_DICTIONARY and bomb_param.has("value"):
		# Handle nested dictionary format
		bomb_count = int(bomb_param.value)
	elif typeof(bomb_param) == TYPE_INT:
		# Direct integer
		bomb_count = bomb_param
	elif typeof(bomb_param) == TYPE_STRING:
		# String that needs conversion
		if "=" in bomb_param:
			# Handle legacy param format like "bomb_count=3"
			var parts = bomb_param.split("=")
			if parts.size() > 1:
				bomb_count = int(parts[1].strip_edges())
		else:
			# Simple string value
			bomb_count = int(bomb_param)
	else:
		# Default fallback
		bomb_count = 3
	
	# Parse explosion_radius with type handling
	if typeof(radius_param) == TYPE_DICTIONARY and radius_param.has("value"):
		explosion_radius = float(radius_param.value)
	elif typeof(radius_param) == TYPE_FLOAT:
		explosion_radius = radius_param
	elif typeof(radius_param) == TYPE_STRING:
		if "=" in radius_param:
			var parts = radius_param.split("=")
			if parts.size() > 1:
				explosion_radius = float(parts[1].strip_edges())
		else:
			explosion_radius = float(radius_param)
	else:
		# Default fallback
		explosion_radius = 40.0
	
	# Check for parameters in JSON behaviors array
	if weapon and "weapon_data" in weapon:
		if "behaviors" in weapon.weapon_data and typeof(weapon.weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon.weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY and behavior.has("type") and behavior.type == "cluster":
					if "params" in behavior and typeof(behavior.params) == TYPE_DICTIONARY:
						# Override with specific params from the behavior entry
						if "bomb_count" in behavior.params:
							bomb_count = int(behavior.params.bomb_count)
						if "explosion_radius" in behavior.params:
							explosion_radius = float(behavior.params.explosion_radius)
	
	if DEBUG:
		print("Initialized cluster bomb behavior with ", bomb_count, " bombs and radius: ", explosion_radius)

func get_behavior_name() -> String:
	return "ClusterBombBehavior"

func on_projectile_created(projectile):
	# Skip if already a grenade
	if projectile.has_meta("is_grenade"):
		return
		
	# Get player direction
	var dir_x = 1
	if "direction" in projectile:
		if typeof(projectile.direction) == TYPE_VECTOR2:
			dir_x = sign(projectile.direction.x)
		else:
			dir_x = sign(projectile.direction)
	elif "velocity" in projectile and projectile.velocity.x != 0:
		dir_x = sign(projectile.velocity.x)
	
	# Set launcher properties
	projectile.set_meta("is_grenade_launcher", true)
	projectile.set_meta("grenade_count", bomb_count)
	projectile.set_meta("explosion_radius", explosion_radius)
	projectile.set_meta("direction", dir_x)
	projectile.set_meta("grenades_thrown", false)
	
	# Check for friendly fire and self-damage from JSON flags
	if weapon and "weapon_data" in weapon:
		if "flags" in weapon.weapon_data:
			# Copy flags to projectile metadata
			if "friendly_fire" in weapon.weapon_data.flags:
				projectile.set_meta("friendly_fire", weapon.weapon_data.flags.friendly_fire)
			if "allow_self_damage" in weapon.weapon_data.flags:
				projectile.set_meta("allow_self_damage", weapon.weapon_data.flags.allow_self_damage)
	
	# We need to wait until the launcher is in the scene tree before throwing grenades
	projectile.set_meta("throw_on_next_frame", true)

# Process main projectile
func on_projectile_process(projectile, delta):
	# Check if we need to throw grenades
	if projectile.has_meta("is_grenade_launcher") and projectile.has_meta("throw_on_next_frame") and !projectile.get_meta("grenades_thrown", false):
		# Make sure the projectile is in the scene tree
		if projectile.is_inside_tree():
			var dir_x = projectile.get_meta("direction", 1)
			throw_grenades(projectile, dir_x)
			
			# Destroy the launcher
			projectile.destroy()
			return true
	
	return false

# Apply physics to the projectiles - handle grenade arcs
func on_projectile_physics_process(projectile, delta):
	# Apply physics only to grenades
	if projectile.has_meta("is_grenade") and "velocity" in projectile:
		# Update bezier position - always use bezier for the entire flight
		update_bezier_position(projectile, delta)
		return true
	
	return false

# Update a grenade using bezier interpolation
func update_bezier_position(projectile, delta):
	# Get bezier control points
	var p0 = projectile.get_meta("bezier_start", Vector2.ZERO)
	var p1 = projectile.get_meta("bezier_control1", Vector2.ZERO)
	var p2 = projectile.get_meta("bezier_control2", Vector2.ZERO)
	var p3 = projectile.get_meta("bezier_end", Vector2.ZERO)
	
	# Get current progress and update it
	var progress = projectile.get_meta("bezier_progress", 0.0)
	var duration = projectile.get_meta("bezier_duration", 1.0)
	var speed_factor = projectile.get_meta("speed_factor", 1.5)
	progress += (delta * speed_factor) / duration
	
	# Store old position for collision detection
	var old_pos = projectile.global_position
	
	# Cap progress at 1.0
	progress = min(progress, 1.0)
	
	# Calculate current position using bezier curve
	var current_pos = cubic_bezier(p0, p1, p2, p3, progress)
	
	# Calculate previous position (small step back) for velocity calculation
	var prev_t = max(0.0, progress - 0.01)
	var prev_pos = cubic_bezier(p0, p1, p2, p3, prev_t)
	
	# Calculate velocity from position difference
	var calculated_velocity = (current_pos - prev_pos) / (0.01 * duration / speed_factor)
	
	# Set the velocity for collision detection
	projectile.velocity = calculated_velocity
	
	# Store updated progress
	projectile.set_meta("bezier_progress", progress)
	
	# Set the position directly
	projectile.global_position = current_pos
	projectile.set_meta("prev_position", old_pos)
	
	# Check for collisions manually during Bezier movement
	check_collision_during_bezier(projectile)
	
	# Destroy when reaching end of curve
	if progress >= 1.0:
		create_explosion(projectile)
		projectile.destroy()
	
	return true

# Check for collisions during Bezier curve movement
func check_collision_during_bezier(projectile):
	# Use move_and_collide to detect collisions
	var collision_result = projectile.move_and_collide(Vector2.ZERO)
	
	if collision_result:
		# Process the collision
		var collider = collision_result.get_collider()
		
		# Skip self collision if self damage is not allowed
		if collider == projectile.wielder_ref:
			var allow_self_damage = projectile.get_meta("allow_self_damage", false)
			if !allow_self_damage:
				return
		
		# Skip friendly fire if not allowed
		if "player_number" in collider and "player_number" in projectile.wielder_ref:
			if collider.player_number == projectile.wielder_ref.player_number:
				var friendly_fire = projectile.get_meta("friendly_fire", false)
				if !friendly_fire:
					return
		
		if collider.has_method("take_damage"):
			# Hit an enemy - apply damage directly
			var hit_dir = projectile.velocity.normalized()
			
			# Get damage from projectile
			var damage = projectile.damage
			var knockback = projectile.knockback
			
			# Apply damage to the target
			collider.take_damage(damage, hit_dir, knockback)
			
			if DEBUG:
				print("Grenade hit target directly with damage: ", damage)
		
		# Create explosion
		create_explosion(projectile)
		
		# Destroy the grenade
		projectile.destroy()

# Create an explosion for the grenade
func create_explosion(projectile):
	# Get explosion radius
	var radius = projectile.explosion_radius
	
	if DEBUG:
		print("Creating explosion with radius: ", radius)
	
	# Call ExplosiveProjectile's create_explosion method
	if projectile.has_method("create_explosion"):
		projectile.create_explosion()
	else:
		# Fallback - create a simple explosion effect
		create_simple_explosion(projectile)

# Create a simple explosion effect as fallback
func create_simple_explosion(projectile):
	# Get scene 
	var scene = projectile.get_tree().current_scene
	if !scene:
		return
		
	# Get radius
	var radius = projectile.explosion_radius
	
	# Create explosion area
	var explosion = Area2D.new()
	explosion.name = "Explosion"
	
	# Add collision shape
	var explosion_collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	explosion_collision.shape = shape
	explosion.add_child(explosion_collision)
	
	# Set collision properties
	explosion.collision_layer = 0
	var enemy_mask = 4 if projectile.wielder_ref and projectile.wielder_ref.name == "Player1" else 2
	explosion.collision_mask = enemy_mask
	
	# Copy flags from projectile to explosion
	explosion.set_meta("friendly_fire", projectile.get_meta("friendly_fire", false))
	explosion.set_meta("allow_self_damage", projectile.get_meta("allow_self_damage", false))
	
	# Add visual effect
	var circle = ColorRect.new()
	circle.color = Color(1.0, 0.6, 0.1, 0.7)  # Orange for explosion
	var size = radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	explosion.add_child(circle)
	
	# Add to scene
	scene.add_child(explosion)
	explosion.global_position = projectile.global_position
	
	# Create fade effect
	var tween = circle.create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	
	# Connect to handle hits
	explosion.body_entered.connect(func(body): 
		# Handle friendly fire and self-damage according to JSON flags
		var is_self = body == projectile.wielder_ref
		var is_friendly = false
		
		if "player_number" in body and "player_number" in projectile.wielder_ref:
			is_friendly = body.player_number == projectile.wielder_ref.player_number
		
		# Skip self collision if self damage is not allowed
		if is_self and !explosion.get_meta("allow_self_damage", false):
			return
			
		# Skip friendly fire if not allowed
		if is_friendly and !is_self and !explosion.get_meta("friendly_fire", false):
			return
			
		# Apply damage if the body can take it
		if body.has_method("take_damage"):
			# Calculate direction away from explosion
			var hit_dir = (body.global_position - explosion.global_position).normalized()
			
			# Apply damage and knockback with adjustments for self-damage
			var damage = int(projectile.damage * 0.7)  # Explosion does 70% damage
			var knockback = projectile.knockback * 1.2  # Explosion has 120% knockback
			
			# Reduce damage for self hits
			if is_self:
				damage = int(damage * 0.5)  # 50% damage to self
			
			body.take_damage(damage, hit_dir, knockback)
			
			if DEBUG:
				print("Explosion damaged target with: ", damage)
	)
	
	# Create timer to remove explosion
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	explosion.add_child(timer)
	timer.timeout.connect(func(): explosion.queue_free())
	timer.start()

# Calculate cubic bezier interpolation
func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Standard cubic bezier formula:
	# B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
	
	var u = 1.0 - t
	var tt = t * t
	var uu = u * u
	var uuu = uu * u
	var ttt = tt * t
	
	var result = uuu * p0
	result += 3.0 * uu * t * p1
	result += 3.0 * u * tt * p2
	result += ttt * p3
	
	return result

# Throw all grenades
func throw_grenades(launcher, dir_x):
	# Mark as thrown
	launcher.set_meta("grenades_thrown", true)
	
	# Throw each grenade
	for i in range(bomb_count):
		throw_grenade(launcher, i, dir_x)

# Throw a grenade with a bezier arc
func throw_grenade(launcher, index, dir_x):
	# Safety check - make sure the launcher is valid and in the tree
	if !is_instance_valid(launcher) or !launcher.is_inside_tree():
		return
		
	# Get scene
	var scene = launcher.get_tree().current_scene
	if !scene:
		print("ERROR: No scene found for grenades")
		return
	
	# Colors for visual distinction
	var colors = [
		Color(1.0, 0.5, 0.0),  # Orange - lighter
		Color(0.0, 0.8, 0.0),  # Green - medium
		Color(0.0, 0.4, 1.0)   # Blue - heavier
	]
	
	# Size variations
	var sizes = [16, 24, 32]  # Small, medium, large
	
	# Create the grenade
	var grenade = ExplosiveProjectile.new()
	
	# Basic setup
	grenade.explosion_radius = explosion_radius
	grenade.damage = int(launcher.damage * (0.6 + index * 0.2))  # More damage for heavier grenades
	grenade.knockback = launcher.knockback * (0.7 + index * 0.3)  # More knockback for heavier grenades
	grenade.lifetime = 8.0  # Long lifetime for arcs
	grenade.wielder_ref = launcher.wielder_ref
	
	# Set direction
	grenade.direction = dir_x
	
	# Copy flags from launcher to grenade
	grenade.set_meta("friendly_fire", launcher.get_meta("friendly_fire", false))
	grenade.set_meta("allow_self_damage", launcher.get_meta("allow_self_damage", false))
	
	# Mark as grenade with specific "weight class"
	grenade.set_meta("is_grenade", true)
	grenade.set_meta("grenade_index", index)
	grenade.set_meta("weight_class", ["light", "medium", "heavy"][index % 3])
	
	# Add visual representation
	var sprite = ColorRect.new()
	var size = sizes[index % sizes.size()]
	sprite.size = Vector2(size, size)
	sprite.position = Vector2(-size/2, -size/2)  # Center the sprite
	sprite.color = colors[index % colors.size()]
	grenade.add_child(sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = size / 2
	collision_shape.shape = shape
	grenade.add_child(collision_shape)
	
	# Collision setup - IMPORTANT for damage!
	grenade.collision_layer = 0
	var enemy_mask = 4 if launcher.wielder_ref and launcher.wielder_ref.name == "Player1" else 2
	var world_mask = 1
	grenade.collision_mask = enemy_mask | world_mask
	
	# Position safely - add height so they don't hit the ground
	grenade.global_position = launcher.global_position + Vector2(0, -15)
	
	# Add to scene
	scene.add_child(grenade)
	
	# Setup bezier curves for perfect arcs
	
	# Start position is current position
	var start_pos = grenade.global_position
	
	# Define different arcs for each grenade
	var arc_heights = [180, 120, 80]  # Light, medium, heavy
	var arc_distances = [220, 350, 150]  # Medium, far, short distances
	var arc_durations = [1.2, 1.0, 0.8]  # Balanced speed
	var speed_factors = [1.5, 1.5, 1.5]  # Moderate speed multipliers
	
	# Get parameters for this grenade
	var arc_height = arc_heights[index % arc_heights.size()]
	var arc_distance = arc_distances[index % arc_distances.size()] * dir_x
	var arc_duration = arc_durations[index % arc_durations.size()]
	var speed_factor = speed_factors[index % speed_factors.size()]
	
	# IMPROVED: Create a full arc that ends at ground level
	# We want a natural parabolic arc that goes up, then down all the way to ground level
	
	# Calculate landing spot on the ground
	var ground_y = 100  # A reasonable ground level value
	if launcher.has_meta("ground_level"):
		ground_y = launcher.get_meta("ground_level")
	else:
		# Assume ground is 100 pixels below launcher
		ground_y = launcher.global_position.y + 100
	
	# The end point is at ground level at the calculated horizontal distance
	var end_pos = Vector2(start_pos.x + arc_distance, ground_y)
	
	# Calculate control points for a nice parabolic arc
	
	# First control point determines initial trajectory (high and in direction of travel)
	var control1 = start_pos + Vector2(arc_distance * 0.35, -arc_height)
	
	# Second control point positioned to create a steeper landing angle
	var control2 = Vector2(
		end_pos.x - (50 * dir_x),  # Before the end horizontally
		end_pos.y - 10  # Just slightly above ground - creates a steep landing
	)
	
	# Set bezier metadata
	grenade.set_meta("using_bezier", true)
	grenade.set_meta("bezier_start", start_pos)
	grenade.set_meta("bezier_control1", control1)
	grenade.set_meta("bezier_control2", control2)
	grenade.set_meta("bezier_end", end_pos)
	grenade.set_meta("bezier_progress", 0.0)
	grenade.set_meta("bezier_duration", arc_duration)
	grenade.set_meta("speed_factor", speed_factor)
	grenade.set_meta("prev_position", start_pos)
	
	# Initial velocity calculation for collision detection
	var initial_tangent = 3.0 * (control1 - start_pos)
	grenade.velocity = initial_tangent.normalized() * 400
	
	if DEBUG:
		print("Threw grenade ", index, " with pure bezier trajectory")
		print("  - Start: ", start_pos)
		print("  - End: ", end_pos)
		print("  - Control1: ", control1)
		print("  - Control2: ", control2)
	
	# Apply this behavior for physics
	grenade.add_behavior(self)

# Handle collision with terrain - renamed to avoid conflict
func handle_projectile_collision(projectile, collision_event):
	# If launcher hits something and grenades haven't been thrown, throw them
	if projectile.has_meta("is_grenade_launcher") and !projectile.get_meta("grenades_thrown", false):
		# Get direction from metadata
		var dir_x = projectile.get_meta("direction", 1)
			
		# Try to throw grenades if we can
		if projectile.is_inside_tree():
			throw_grenades(projectile, dir_x)
		
		# Destroy the launcher
		projectile.destroy()
		return true
	
	# For grenades, create an explosion on impact and destroy
	if projectile.has_meta("is_grenade"):
		# Create explosion
		create_explosion(projectile)
		
		# Destroy the grenade
		projectile.destroy()
		return true
		
	return false
