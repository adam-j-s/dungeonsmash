# Applies freeze/slow status to hit targets
class_name FreezeBehavior
extends BehaviorBase

var freeze_slow_factor = 0.5  # Movement speed multiplier (0.5 = 50% slower)
var freeze_duration = 2.0  # Duration in seconds

func _init_behavior():
	# Get parameters
	freeze_slow_factor = float(get_param("freeze_slow_factor", 0.5))
	freeze_duration = float(get_param("freeze_duration", 2.0))
	
	if DEBUG:
		print("Initialized freeze behavior with slow factor: ", freeze_slow_factor, " duration: ", freeze_duration)

func get_behavior_name() -> String:
	return "FreezeBehavior"

func on_projectile_created(projectile):
	# Add ice visual to projectile
	var ice_particles = create_ice_particles()
	projectile.add_child(ice_particles)
	
	# Set freeze effect properties
	projectile.set_meta("freeze_slow_factor", freeze_slow_factor)
	projectile.set_meta("freeze_duration", freeze_duration)
	
# Change projectile color to icy blue
	projectile.modulate = Color(0.5, 0.8, 1.0)
	
	if DEBUG:
		print("Applied freeze behavior to projectile")

# Apply freeze effect when hitting a target
func on_projectile_hit(projectile, target):
	apply_freeze_effect(target)

# Apply freeze effect when weapon hits directly
func on_hit(target):
	apply_freeze_effect(target)

# Main function to apply freeze status effect
func apply_freeze_effect(target):
	# Only apply to valid targets that can take damage
	if !target or !target.has_method("take_damage"):
		return
	
	# Check if target has a method to apply status effects
	if target.has_method("apply_status_effect"):
		# Pass the effect to the target's handler
		var effect_data = {
			"type": "freeze",
			"slow_factor": freeze_slow_factor,
			"duration": freeze_duration,
			"source": weapon
		}
		target.apply_status_effect(effect_data)
	else:
		# Fallback: Implement freeze effect directly
		apply_freeze_effect_directly(target)
	
	# Create ice visual on target
	create_freeze_effect_on_target(target)
	
	if DEBUG:
		print("Applied freeze effect to: ", target.name)

# Fallback method if target doesn't handle status effects
func apply_freeze_effect_directly(target):
	# Check if already frozen
	if target.has_meta("freeze_effect_active") and target.get_meta("freeze_effect_active"):
		# Just refresh duration
		target.set_meta("freeze_effect_timer", 0.0)
		return
	
	# Store original speed
	var original_speed = 300.0  # Default fallback
	if "SPEED" in target:
		original_speed = target.SPEED
		target.set_meta("original_speed", original_speed)
	
	# Apply slow effect
	if "SPEED" in target:
		target.SPEED = original_speed * freeze_slow_factor
	
	# Set freeze effect as active
	target.set_meta("freeze_effect_active", true)
	target.set_meta("freeze_effect_timer", 0.0)
	
	# Create timer to track and remove effect
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update at 10 times per second
	timer.autostart = true
	target.add_child(timer)
	
	# Connect timer timeout function
	timer.timeout.connect(func():
		# Update timer
		var effect_timer = target.get_meta("freeze_effect_timer") + 0.1
		
		# Check if effect has expired
		if effect_timer >= freeze_duration:
			# Restore original speed
			if "SPEED" in target and target.has_meta("original_speed"):
				target.SPEED = target.get_meta("original_speed")
			
			# Remove effect state
			target.set_meta("freeze_effect_active", false)
			timer.queue_free()
			
			# Remove freeze visuals
			for child in target.get_children():
				if child.name == "FreezeEffect":
					child.queue_free()
			
			return
		
		# Update stored timer
		target.set_meta("freeze_effect_timer", effect_timer)
	)

# Create ice particles for projectile
func create_ice_particles():
	var particles = CPUParticles2D.new()
	particles.name = "IceParticles"
	particles.amount = 15
	particles.lifetime = 0.6
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = Vector2(0, 1)  # Falling ice
	particles.spread = 30
	particles.gravity = Vector2(0, 40)
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 40
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	
	# Ice colors
	var gradient = Gradient.new()
	gradient.colors = [Color(0.7, 0.9, 1.0), Color(0.5, 0.8, 1.0)]
	particles.color_ramp = gradient
	
	particles.emitting = true
	
	return particles

# Create freeze effect on target
func create_freeze_effect_on_target(target):
	# Check if freeze effect already exists
	for child in target.get_children():
		if child.name == "FreezeEffect":
			return  # Already has freeze effect
	
	# Create freeze effect container
	var effect = Node2D.new()
	effect.name = "FreezeEffect"
	
	# Create ice particles
	var particles = create_ice_particles()
	particles.lifetime = 0.8
	particles.amount = 20
	effect.add_child(particles)
	
	# Create frost overlay
	var frost = ColorRect.new()
	frost.color = Color(0.7, 0.9, 1.0, 0.3)  # Light blue semi-transparent
	frost.size = Vector2(40, 40)
	frost.position = Vector2(-20, -20)  # Center on target
	effect.add_child(frost)
	
	# Add to target
	target.add_child(effect)
	
	# Modify target color
	if target.has_method("set_modulate"):
		target.set_modulate(Color(0.7, 0.8, 1.0))
	else:
		target.modulate = Color(0.7, 0.8, 1.0)
	
	# Create cleanup timer
	var timer = Timer.new()
	timer.wait_time = freeze_duration
	timer.one_shot = true
	timer.timeout.connect(func():
		if effect and is_instance_valid(effect):
			effect.queue_free()
		
		# Restore target color
		if target and is_instance_valid(target):
			if target.has_method("set_modulate"):
				target.set_modulate(Color(1, 1, 1))
			else:
				target.modulate = Color(1, 1, 1)
	)
	effect.add_child(timer)
	timer.start()

