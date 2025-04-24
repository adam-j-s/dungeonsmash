# singularity_behavior.gd - Fixed version for consistent self-damage handling
class_name SingularityBehavior
extends BehaviorBase

var pull_radius = 150.0  # How far the pull reaches
var pull_strength = 600.0  # How strong the pull is
var max_singularity_duration = 2.0  # How long before explosion
var explosion_radius = 120.0  # Size of final explosion

# Import Collision utility for friendly fire
const CollisionUtils = preload("res://scripts/collision_utils.gd")

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get pull radius parameter
		if "pull_radius" in behavior_params:
			pull_radius = float(behavior_params.pull_radius)
		else:
			pull_radius = float(get_param("pull_radius", 150.0))
		
		# Get pull strength parameter
		if "pull_strength" in behavior_params:
			pull_strength = float(behavior_params.pull_strength)
		else:
			pull_strength = float(get_param("pull_strength", 600.0))
		
		# Get singularity duration parameter
		if "max_singularity_duration" in behavior_params:
			max_singularity_duration = float(behavior_params.max_singularity_duration)
		elif "duration" in behavior_params:
			max_singularity_duration = float(behavior_params.duration)
		else:
			max_singularity_duration = float(get_param("max_singularity_duration", 2.0))
		
		# Get explosion radius parameter
		if "explosion_radius" in behavior_params:
			explosion_radius = float(behavior_params.explosion_radius)
		else:
			explosion_radius = float(get_param("explosion_radius", 120.0))
	else:
		# Fallback to flat parameters
		pull_radius = float(get_param("pull_radius", 150.0))
		pull_strength = float(get_param("pull_strength", 600.0))
		max_singularity_duration = float(get_param("max_singularity_duration", 2.0))
		explosion_radius = float(get_param("explosion_radius", 120.0))
	
	# Check weapon data for specific singularity settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for specific settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a singularity behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "singularity":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get parameters if specified
						if "pull_radius" in behavior_params:
							pull_radius = float(behavior_params.pull_radius)
						if "pull_strength" in behavior_params:
							pull_strength = float(behavior_params.pull_strength)
						if "max_singularity_duration" in behavior_params:
							max_singularity_duration = float(behavior_params.max_singularity_duration)
						if "explosion_radius" in behavior_params:
							explosion_radius = float(behavior_params.explosion_radius)
	
	# Ensure reasonable values
	pull_radius = max(50.0, pull_radius)  # Minimum radius
	pull_strength = max(100.0, pull_strength)  # Minimum strength
	max_singularity_duration = clamp(max_singularity_duration, 0.5, 5.0)  # Reasonable duration range
	explosion_radius = max(30.0, explosion_radius)  # Minimum explosion size
	
	if DEBUG:
		print("SINGULARITY DEBUG: After initialization - radius: ", pull_radius, " strength: ", pull_strength)
		print("SINGULARITY DEBUG: Duration: ", max_singularity_duration, " explosion radius: ", explosion_radius)

func get_behavior_name() -> String:
	return "SingularityBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Set singularity properties on the projectile
	projectile.set_meta("pull_radius", pull_radius)
	projectile.set_meta("pull_strength", pull_strength)
	projectile.set_meta("max_singularity_duration", max_singularity_duration)
	projectile.set_meta("explosion_radius", explosion_radius)
	projectile.set_meta("should_activate_singularity", true)
	projectile.set_meta("singularity_activated", false)  # Flag to track activation state
	
	# If projectile is already a SingularityProjectile, update its properties
	if projectile is SingularityProjectile:
		projectile.pull_radius = pull_radius
		projectile.pull_strength = pull_strength
		projectile.max_singularity_duration = max_singularity_duration
	
	# Change projectile color to purple
	projectile.modulate = Color(0.7, 0.0, 0.9)
	
	if DEBUG:
		print("Applied singularity behavior to projectile")

# Handle physics processing to trigger singularity activation after a delay
func on_projectile_physics_process(projectile, delta):
	# Validate projectile
	if !is_instance_valid(projectile):
		return false
	
	# Skip if projectile is already a SingularityProjectile
	if projectile is SingularityProjectile:
		return false
	
	# Skip if the singularity has already been activated
	if projectile.get_meta("singularity_activated", false):
		return false
	
	# Check if we should create the singularity
	if projectile.timer >= 0.8:  # Activate after 0.8 seconds flight
		# Set flag to prevent multiple activations
		projectile.set_meta("singularity_activated", true)
		
		if DEBUG:
			print("Activating singularity after delay")
			
		create_singularity_at_point(projectile.global_position)
		
		# Remove the original projectile manually to avoid dependency on destroy()
		if is_instance_valid(projectile):
			projectile.queue_free()
		
		# Return true to indicate we've handled physics
		return true
		
	return false  # Let normal physics continue

# Handle hits to trigger singularity creation on impact
func on_projectile_hit(projectile, target):
	# Validate projectile and target
	if !is_instance_valid(projectile) or !is_instance_valid(target):
		return
	
	# If it's already a SingularityProjectile, let it handle the effect
	if projectile is SingularityProjectile:
		return
	
	# Skip if the singularity has already been activated
	if projectile.get_meta("singularity_activated", false):
		return
	
	# Set flag to prevent multiple activations
	projectile.set_meta("singularity_activated", true)
	
	# Prevent normal destruction of projectile when it hits
	projectile.set_meta("cancel_destruction", true)
	
	if DEBUG:
		print("Activating singularity on impact")
		
	create_singularity_at_point(projectile.global_position)
	
	# Remove the projectile manually after creating the singularity
	if is_instance_valid(projectile):
		projectile.queue_free()

# Override to handle collisions with walls and terrain
# This will trigger singularity creation even when hitting walls
func on_projectile_collision(projectile, collision):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Skip if already activated
	if projectile.get_meta("singularity_activated", false):
		return
	
	# Set flag to prevent multiple activations
	projectile.set_meta("singularity_activated", true)
	
	# Prevent destruction
	projectile.set_meta("cancel_destruction", true)
	
	if DEBUG:
		print("Activating singularity on collision with surface")
		
	create_singularity_at_point(projectile.global_position)
	
	# Remove projectile
	if is_instance_valid(projectile):
		projectile.queue_free()

# Get allow_self_damage flag from weapon in a consistent way
func get_allow_self_damage():
	# Default to true for singularity effects
	var allow_self_damage = true
	
	if is_instance_valid(weapon):
		# Check for metadata first (highest priority)
		if weapon.has_meta("allow_self_damage"):
			allow_self_damage = weapon.get_meta("allow_self_damage")
		# Then check weapon data structure from JSON
		elif "weapon_data" in weapon:
			if "flags" in weapon.weapon_data:
				allow_self_damage = weapon.weapon_data.flags.get("allow_self_damage", true)
			# Fallback to flat structure if no flags dictionary
			else:
				allow_self_damage = weapon.weapon_data.get("allow_self_damage", true)
	
	if DEBUG:
		print("SINGULARITY: get_allow_self_damage() = ", allow_self_damage)
		
	return allow_self_damage

# Create a singularity effect at a specific point
func create_singularity_at_point(position):
	# Skip if no weapon to reference
	if !is_instance_valid(weapon) or !is_instance_valid(weapon.wielder):
		if DEBUG:
			print("Cannot create singularity - missing weapon or wielder reference")
		return
	
	if DEBUG:
		print("Creating singularity at position: ", position, "and with pull_strength", pull_strength)
	
	# Create singularity node using our custom SingularityNode class
	var singularity = SingularityNode.new()
	singularity.name = "Singularity"
	
	# Get allow_self_damage flag from weapon using our consistent method
	var allow_self_damage = get_allow_self_damage()
	
	# Configure singularity properties
	singularity.pull_radius = pull_radius
	singularity.pull_strength = pull_strength
	singularity.max_duration = max_singularity_duration
	singularity.explosion_radius = explosion_radius
	singularity.wielder_ref = weapon.wielder
	singularity.weapon_ref = weapon
	singularity.allow_self_pull = allow_self_damage
	singularity.allow_self_damage = allow_self_damage  # Also store for explosion
	
	if DEBUG:
		print("SINGULARITY NODE: Created with pull_radius: ", singularity.pull_radius, 
			  " pull_strength: ", singularity.pull_strength,
			  " allow_self_pull: ", singularity.allow_self_pull,
			  " allow_self_damage: ", singularity.allow_self_damage)
	
	# Add visual
	var visual = ColorRect.new()
	visual.color = Color(0.7, 0.0, 0.9, 0.5)  # Purple semi-transparent
	var size = pull_radius * 0.4  # Make visual more noticeable
	visual.size = Vector2(size, size)
	visual.position = Vector2(-size/2, -size/2)  # Center
	singularity.add_child(visual)
	
	# Add a border to make it more visible
	var border = ColorRect.new()
	border.color = Color(0.9, 0.3, 1.0, 0.8)  # Brighter purple border
	border.size = Vector2(size + 4, size + 4)
	border.position = Vector2(-(size + 4)/2, -(size + 4)/2)  # Center
	singularity.add_child(border)
	
	# Make sure the border is behind the main visual
	border.z_index = -1
	
	# Add collision for pull area
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pull_radius
	collision.shape = shape
	singularity.add_child(collision)
	
	# Set collision properties
	singularity.collision_layer = 0
	singularity.collision_mask = 6  # Both players (2 + 4)
	
	# Add to scene FIRST - this is critical for tween to work
	if is_instance_valid(weapon.wielder) and is_instance_valid(weapon.wielder.get_tree()) and is_instance_valid(weapon.wielder.get_tree().current_scene):
		weapon.wielder.get_tree().current_scene.add_child(singularity)
		singularity.global_position = position
	else:
		if DEBUG:
			print("Error: Could not add singularity to scene - missing scene reference")
		singularity.queue_free()
		return
	
	# Add particles for more visual impact
	var particles = CPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 1.0
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = pull_radius * 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.7, 0.0, 0.9)
	singularity.add_child(particles)
	
	# Now create the pulsing effect AFTER adding to scene
	if is_instance_valid(visual):
		var tween = visual.create_tween()
		if tween:  # Check if tween was created successfully
			tween.set_loops()
			tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.5)
			tween.tween_property(visual, "scale", Vector2(0.8, 0.8), 0.5)
	
	# Connect to singularity ended signal with proper error handling
	var explosion_callable = func():
		# Create explosion
		create_explosion_at_point(singularity.global_position, allow_self_damage)
		
		# Clean up and remove singularity
		if is_instance_valid(singularity):
			singularity.cleanup()
			singularity.queue_free()
	
	# Connect the signal with stored callable
	if singularity.has_signal("singularity_ended"):
		singularity.singularity_ended.connect(explosion_callable)
		
		# Store the callable for later disconnection if needed
		singularity.set_meta("explosion_callable", explosion_callable)
	
	if DEBUG:
		print("Singularity created with pull radius: ", pull_radius, " pull strength: ", pull_strength)

# Create an explosion at a specific point - now takes allow_self_damage parameter
func create_explosion_at_point(explosion_position, allow_self_damage):
	# Create explosion effect
	var explosion = Area2D.new()
	explosion.name = "SingularityExplosion"
	
	# Add explosion collision
	var explosion_collision = CollisionShape2D.new()
	var explosion_shape = CircleShape2D.new()
	explosion_shape.radius = explosion_radius
	explosion_collision.shape = explosion_shape
	explosion.add_child(explosion_collision)
	
	# Setup collision masks - directly set for consistency
	explosion.collision_layer = 0
	explosion.collision_mask = 6  # Both player layers (binary 110)
	
	# Set metadata for explosion settings - use the passed allow_self_damage value
	explosion.set_meta("allow_self_damage", allow_self_damage)
	
	# Set friendly fire flag
	var friendly_fire = false
	if is_instance_valid(weapon):
		if weapon.has_meta("friendly_fire"):
			friendly_fire = weapon.get_meta("friendly_fire")
		elif "weapon_data" in weapon and "flags" in weapon.weapon_data:
			friendly_fire = weapon.weapon_data.flags.get("friendly_fire", false)
	
	explosion.set_meta("friendly_fire", friendly_fire)
	
	# Add visual
	var explosion_visual = ColorRect.new()
	explosion_visual.color = Color(1.0, 0.2, 0.9, 0.7)  # Bright purple
	var explosion_size = explosion_radius * 2
	explosion_visual.size = Vector2(explosion_size, explosion_size)
	explosion_visual.position = Vector2(-explosion_size/2, -explosion_size/2)
	explosion.add_child(explosion_visual)
	
	# Add to scene first before creating tween
	if is_instance_valid(weapon) and is_instance_valid(weapon.wielder) and is_instance_valid(weapon.wielder.get_tree()) and is_instance_valid(weapon.wielder.get_tree().current_scene):
		weapon.wielder.get_tree().current_scene.add_child(explosion)
		explosion.global_position = explosion_position
		
		# Now create fade effect with null checking
		if is_instance_valid(explosion_visual):
			var explosion_tween = explosion_visual.create_tween()
			if explosion_tween:
				explosion_tween.tween_property(explosion_visual, "scale", Vector2(1.5, 1.5), 0.3)
				explosion_tween.tween_property(explosion_visual, "modulate:a", 0.0, 0.3)
	
	# Create and store hit callable
	var hit_callable = func(body):
		if !is_instance_valid(body) or !is_instance_valid(weapon) or !is_instance_valid(weapon.wielder):
			return
		
		# Check for self-damage
		var is_self = body == weapon.wielder
		if is_self:
			# Skip if self-damage is not allowed - use actual value from metadata
			var allow_self_damage_meta = explosion.get_meta("allow_self_damage", false)
			if !allow_self_damage_meta:
				return
		
		# Check for friendly fire (only for non-self targets)
		var is_friendly = false
		if !is_self and "player_number" in weapon.wielder and "player_number" in body:
			is_friendly = body.player_number == weapon.wielder.player_number
		
		# Skip friendly hits if friendly fire is disabled
		if is_friendly and !explosion.get_meta("friendly_fire", false):
			return
			
		# Calculate damage (based on weapon's damage)
		var explosion_damage = weapon.calculate_damage() * 1.5  # 150% damage
		
		# Apply reduced damage for self-damage
		if is_self:
			explosion_damage = int(explosion_damage * 0.5)  # 50% damage to self
		
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
	
	# Connect to handle hits
	explosion.body_entered.connect(hit_callable)
	
	# Create cleanup function for the explosion
	var cleanup_func = func():
		if is_instance_valid(explosion):
			# Disconnect signal before freeing
			if explosion.has_meta("hit_callable"):
				var callable = explosion.get_meta("hit_callable")
				if explosion.is_connected("body_entered", callable):
					explosion.disconnect("body_entered", callable)
			explosion.queue_free()
	
	# Wait and then clean up
	if is_instance_valid(weapon) and is_instance_valid(weapon.wielder) and is_instance_valid(weapon.wielder.get_tree()):
		await weapon.wielder.get_tree().create_timer(1.0).timeout
		cleanup_func.call()
