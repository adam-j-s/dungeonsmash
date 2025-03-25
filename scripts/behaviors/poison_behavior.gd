# Applies poison damage over time
class_name PoisonBehavior
extends BehaviorBase

var poison_damage = 1  # Damage per tick
var poison_duration = 5.0  # Duration in seconds
var poison_tick_rate = 0.5  # Seconds between damage ticks

func _init_behavior():
	# Get parameters
	poison_damage = int(get_param("poison_damage", 1))
	poison_duration = float(get_param("poison_duration", 5.0))
	poison_tick_rate = float(get_param("poison_tick_rate", 0.5))
	
	if DEBUG:
		print("Initialized poison behavior with damage: ", poison_damage, " duration: ", poison_duration)

func get_behavior_name() -> String:
	return "PoisonBehavior"

func on_projectile_created(projectile):
	# Add poison visual to projectile
	var poison_particles = create_poison_particles()
	projectile.add_child(poison_particles)
	
	# Set poison effect properties
	projectile.set_meta("poison_damage", poison_damage)
	projectile.set_meta("poison_duration", poison_duration)
	
	# Change projectile color to toxic green
	projectile.modulate = Color(0.4, 0.8, 0.4)
	
	if DEBUG:
		print("Applied poison behavior to projectile")

# Apply poison effect when hitting a target
func on_projectile_hit(projectile, target):
	apply_poison_effect(target)

# Apply poison effect when weapon hits directly
func on_hit(target):
	apply_poison_effect(target)

# Main function to apply poison status effect
func apply_poison_effect(target):
	# Only apply to valid targets that can take damage
	if !target or !target.has_method("take_damage"):
		return
	
	# Check if target has a method to apply status effects
	if target.has_method("apply_status_effect"):
		# Pass the effect to the target's handler
		var effect_data = {
			"type": "poison",
			"damage": poison_damage,
			"duration": poison_duration,
			"tick_rate": poison_tick_rate,
			"source": weapon
		}
		target.apply_status_effect(effect_data)
	else:
		# Fallback: Implement poison effect directly
		apply_poison_effect_directly(target)
	
	# Create poison visual on target
	create_poison_effect_on_target(target)
	
	if DEBUG:
		print("Applied poison effect to: ", target.name)

# Fallback method if target doesn't handle status effects
func apply_poison_effect_directly(target):
	# Check if already poisoned
	if target.has_meta("poison_effect_active") and target.get_meta("poison_effect_active"):
		# Just refresh duration
		target.set_meta("poison_effect_timer", 0.0)
		return
	
	# Set poison effect as active
	target.set_meta("poison_effect_active", true)
	target.set_meta("poison_effect_timer", 0.0)
	target.set_meta("poison_damage", poison_damage)
	target.set_meta("poison_tick_timer", 0.0)
	
	# Create timer for damage ticks
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update at 10 times per second
	timer.autostart = true
	target.add_child(timer)
	
	# Connect timer timeout function
	timer.timeout.connect(func():
		# Skip if target is already defeated
		if "is_defeated" in target and target.is_defeated:
			timer.queue_free()
			return
			
		# Update timers
		var effect_timer = target.get_meta("poison_effect_timer") + 0.1
		var tick_timer = target.get_meta("poison_tick_timer") + 0.1
		
		# Check if effect has expired
		if effect_timer >= poison_duration:
			target.set_meta("poison_effect_active", false)
			timer.queue_free()
			
			# Remove poison visuals
			for child in target.get_children():
				if child.name == "PoisonEffect":
					child.queue_free()
			return
			
		# Apply damage on tick interval
		if tick_timer >= poison_tick_rate:
			# Reset tick timer
			tick_timer = 0.0
			
			# Apply poison damage
			if target.has_method("take_damage"):
				# Use a random slight direction vector for poison
				var random_dir = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)).normalized()
				target.take_damage(poison_damage, random_dir, 50)  # Small random knockback
		
		# Update stored timers
		target.set_meta("poison_effect_timer", effect_timer)
		target.set_meta("poison_tick_timer", tick_timer)
	)

# Create poison particles for projectile
func create_poison_particles():
	var particles = CPUParticles2D.new()
	particles.name = "PoisonParticles"
	particles.amount = 15
	particles.lifetime = 0.7
	particles.explosiveness = 0.1
	particles.randomness = 0.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 10)
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 40
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	
	# Poison colors
	var gradient = Gradient.new()
	gradient.colors = [Color(0.4, 0.8, 0.4), Color(0.2, 0.6, 0.2)]
	particles.color_ramp = gradient
	
	particles.emitting = true
	
	return particles

# Create poison effect on target
func create_poison_effect_on_target(target):
	# Check if poison effect already exists
	for child in target.get_children():
		if child.name == "PoisonEffect":
			return  # Already has poison effect
	
	# Create poison effect container
	var effect = Node2D.new()
	effect.name = "PoisonEffect"
	
	# Create poison particles
	var particles = create_poison_particles()
	particles.lifetime = 0.8
	particles.amount = 20
	effect.add_child(particles)
	
	# Add to target
	target.add_child(effect)
	
	# Modify target color
	if target.has_method("set_modulate"):
		target.set_modulate(Color(0.8, 1.0, 0.8))
	else:
		target.modulate = Color(0.8, 1.0, 0.8)
	
	# Create cleanup timer
	var timer = Timer.new()
	timer.wait_time = poison_duration
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

