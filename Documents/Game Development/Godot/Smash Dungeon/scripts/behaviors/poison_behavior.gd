# Poison Behavior - Applies damage over time - JSON compatible
class_name PoisonBehavior
extends BehaviorBase

var poison_damage = 1  # Damage per tick
var poison_duration = 5.0  # Duration in seconds
var poison_tick_rate = 0.5  # Seconds between damage ticks
var poison_color = Color(0.4, 0.8, 0.4)  # Default poison green color
var knockback_strength = 50.0  # Small knockback on damage ticks

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var effect_params = params.get("params", {})
		
		# Get poison parameters
		if "damage" in effect_params:
			poison_damage = int(effect_params.damage)
		else:
			poison_damage = int(get_param("poison_damage", 1))
			
		if "duration" in effect_params:
			poison_duration = float(effect_params.duration)
		else:
			poison_duration = float(get_param("poison_duration", 5.0))
			
		if "tick_rate" in effect_params:
			poison_tick_rate = float(effect_params.tick_rate)
		else:
			poison_tick_rate = float(get_param("poison_tick_rate", 0.5))
			
		# Get color if specified
		if "color" in effect_params:
			var color_str = effect_params.get("color", "")
			if color_str != "":
				# Try to parse color string
				poison_color = Color(color_str)
				
		# Get knockback strength if specified
		if "knockback" in effect_params:
			knockback_strength = float(effect_params.knockback)
	else:
		# Fallback to direct parameter extraction
		poison_damage = int(get_param("poison_damage", 1))
		poison_duration = float(get_param("poison_duration", 5.0))
		poison_tick_rate = float(get_param("poison_tick_rate", 0.5))
	
	# Check weapon data for effect settings in JSON structure
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for effect-specific settings in weapon data
		if "effects" in weapon_data:
			var effects = weapon_data.get("effects", [])
			for effect in effects:
				# Handle both string and dictionary formats
				if typeof(effect) == TYPE_STRING and effect == "poison":
					# Simple presence, use defaults
					pass
				elif typeof(effect) == TYPE_DICTIONARY and effect.get("type", "") == "poison":
					# Extract parameters from the effect dictionary
					poison_damage = int(effect.get("damage", poison_damage))
					poison_duration = float(effect.get("duration", poison_duration))
					poison_tick_rate = float(effect.get("tick_rate", poison_tick_rate))
					
					# Get color if specified
					if "color" in effect:
						poison_color = Color(effect.get("color", ""))
	
	# Ensure reasonable values
	poison_damage = max(1, poison_damage)  # Minimum of 1 damage
	poison_duration = clamp(poison_duration, 1.0, 10.0)  # Reasonable duration range
	poison_tick_rate = clamp(poison_tick_rate, 0.1, 1.0)  # Reasonable tick rate range
	
	if DEBUG:
		print("Initialized poison behavior with damage: ", poison_damage, " duration: ", poison_duration)
		print("Poison tick rate: ", poison_tick_rate)

func get_behavior_name() -> String:
	return "PoisonBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
		
	# Add poison visual to projectile
	var poison_particles = create_poison_particles()
	if is_instance_valid(poison_particles):
		projectile.add_child(poison_particles)
	
	# Set poison effect properties
	projectile.set_meta("poison_damage", poison_damage)
	projectile.set_meta("poison_duration", poison_duration)
	projectile.set_meta("poison_tick_rate", poison_tick_rate)
	
	# Change projectile color to toxic green
	projectile.modulate = poison_color
	
	if DEBUG:
		print("Applied poison behavior to projectile")

# Apply poison effect when hitting a target
func on_projectile_hit(projectile, target):
	# Validate parameters
	if !is_instance_valid(projectile) or !is_instance_valid(target):
		return
	apply_poison_effect(target)

# Apply poison effect when weapon hits directly
func on_hit(target):
	# Validate parameter
	if !is_instance_valid(target):
		return
	apply_poison_effect(target)

# Main function to apply poison status effect
func apply_poison_effect(target):
	# Only apply to valid targets that can take damage
	if !is_instance_valid(target) or !target.has_method("take_damage"):
		return
	
	# Check if target has a method to apply status effects
	if target.has_method("apply_status_effect"):
		# Pass the effect to the target's handler
		var effect_data = {
			"type": "poison",
			"damage": poison_damage,
			"duration": poison_duration,
			"tick_rate": poison_tick_rate,
			"source": weapon,
			"knockback": knockback_strength
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
	# Validate target
	if !is_instance_valid(target):
		return
		
	# Check if already poisoned - just refresh duration
	if target.has_meta("poison_effect_active") and target.get_meta("poison_effect_active"):
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
	
	# Create a callable for the timer
	var timer_callable = func():
		# Skip if target is invalid or already defeated
		if !is_instance_valid(target) or ("is_defeated" in target and target.is_defeated):
			if is_instance_valid(timer):
				timer.queue_free()
			return
			
		# Update timers
		var effect_timer = target.get_meta("poison_effect_timer", 0.0) + 0.1
		var tick_timer = target.get_meta("poison_tick_timer", 0.0) + 0.1
		
		# Check if effect has expired
		if effect_timer >= poison_duration:
			if is_instance_valid(target):
				target.set_meta("poison_effect_active", false)
				
				# Remove poison visuals
				for child in target.get_children():
					if is_instance_valid(child) and child.name == "PoisonEffect":
						child.queue_free()
			
			# Clean up timer
			if is_instance_valid(timer):
				timer.queue_free()
			return
			
		# Apply damage on tick interval
		if tick_timer >= poison_tick_rate:
			# Reset tick timer
			tick_timer = 0.0
			
			# Apply poison damage if target is valid
			if is_instance_valid(target) and target.has_method("take_damage"):
				# Use a random slight direction vector for poison
				var random_dir = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)).normalized()
				target.take_damage(poison_damage, random_dir, knockback_strength)
				
				# Create damage pulse visual
				create_damage_pulse(target)
		
		# Update stored timers if target is valid
		if is_instance_valid(target):
			target.set_meta("poison_effect_timer", effect_timer)
			target.set_meta("poison_tick_timer", tick_timer)
	
	# Store the callable for cleanup
	timer.set_meta("poison_callable", timer_callable)
	
	# Connect the timeout signal
	timer.timeout.connect(timer_callable)

# Create a visual pulse when damage is applied
func create_damage_pulse(target):
	# Validate target
	if !is_instance_valid(target):
		return
		
	# Create pulse effect
	var pulse = ColorRect.new()
	pulse.color = Color(poison_color.r, poison_color.g, poison_color.b, 0.3)  # Semi-transparent
	pulse.size = Vector2(30, 30)
	pulse.position = Vector2(-15, -15)  # Center
	target.add_child(pulse)
	
	# Create pulsing effect
	var tween = pulse.create_tween()
	tween.tween_property(pulse, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(pulse, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.1)
	
	# Remove after effect completes
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	pulse.add_child(timer)
	
	# Create a cleanup callable
	var cleanup_callable = func():
		if is_instance_valid(pulse):
			pulse.queue_free()
	
	# Connect and start timer
	timer.timeout.connect(cleanup_callable)
	timer.start()

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
	
	# Poison colors - use the configured color
	var gradient = Gradient.new()
	gradient.colors = [
		Color(poison_color.r, poison_color.g, poison_color.b, 1.0),
		Color(poison_color.r * 0.5, poison_color.g * 0.5, poison_color.b * 0.5, 1.0)
	]
	particles.color_ramp = gradient
	
	particles.emitting = true
	
	return particles

# Create poison effect on target
func create_poison_effect_on_target(target):
	# Validate target
	if !is_instance_valid(target):
		return
		
	# Check if poison effect already exists
	for child in target.get_children():
		if is_instance_valid(child) and child.name == "PoisonEffect":
			return  # Already has poison effect
	
	# Create poison effect container
	var effect = Node2D.new()
	effect.name = "PoisonEffect"
	
	# Create poison particles
	var particles = create_poison_particles()
	if is_instance_valid(particles):
		particles.lifetime = 0.8
		particles.amount = 20
		effect.add_child(particles)
	
	# Add to target
	target.add_child(effect)
	
	# Modify target color safely
	if is_instance_valid(target):
		# Tint the target with the poison color
		var tint_color = Color(
			(1.0 + poison_color.r) * 0.5,
			(1.0 + poison_color.g) * 0.5,
			(1.0 + poison_color.b) * 0.5
		)
		
		if target.has_method("set_modulate"):
			target.set_modulate(tint_color)
		else:
			target.modulate = tint_color
	
	# Create cleanup timer with safe signal handling
	var timer = Timer.new()
	timer.wait_time = poison_duration
	timer.one_shot = true
	
	# Create cleanup callable
	var cleanup_callable = func():
		# Clean up effect
		if is_instance_valid(effect):
			effect.queue_free()
		
		# Restore target color
		if is_instance_valid(target):
			if target.has_method("set_modulate"):
				target.set_modulate(Color(1, 1, 1))
			else:
				target.modulate = Color(1, 1, 1)
	
	# Store callable for cleanup
	timer.set_meta("cleanup_callable", cleanup_callable)
	
	# Connect and start timer
	timer.timeout.connect(cleanup_callable)
	effect.add_child(timer)
	timer.start()
