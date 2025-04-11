# Applies fire status effect to hit targets - JSON compatible
class_name FireBehavior
extends BehaviorBase

var fire_damage = 2  # Damage per tick
var fire_duration = 3.0  # Duration in seconds
var fire_tick_rate = 0.5  # Seconds between damage ticks
var fire_color = Color(1.0, 0.6, 0.2)  # Default fire color

func _init_behavior():
	# Get parameters with enhanced JSON compatibility
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var effect_params = params.get("params", {})
		fire_damage = int(effect_params.get("damage", get_param("fire_damage", 2)))
		fire_duration = float(effect_params.get("duration", get_param("fire_duration", 3.0)))
		fire_tick_rate = float(effect_params.get("tick_rate", get_param("fire_tick_rate", 0.5)))
		
		# Parse color if specified
		if "color" in effect_params:
			var color_str = effect_params.get("color", "")
			if color_str != "":
				# Try to parse color string
				fire_color = Color(color_str)
	else:
		# Fallback to simpler parameter extraction
		fire_damage = int(get_param("fire_damage", 2))
		fire_duration = float(get_param("fire_duration", 3.0))
		fire_tick_rate = float(get_param("fire_tick_rate", 0.5))
	
	# Check weapon data for global effect settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for effect-specific settings in weapon data
		if "effects" in weapon_data:
			var effects = weapon_data.get("effects", [])
			for effect in effects:
				if typeof(effect) == TYPE_DICTIONARY and effect.get("type", "") == "fire":
					# Extract parameters from the effect dictionary
					fire_damage = int(effect.get("damage", fire_damage))
					fire_duration = float(effect.get("duration", fire_duration))
					fire_tick_rate = float(effect.get("tick_rate", fire_tick_rate))
					
					# Get color if specified
					if "color" in effect:
						fire_color = Color(effect.get("color", ""))
	
	if DEBUG:
		print("Initialized fire behavior with damage: ", fire_damage, " duration: ", fire_duration)
		print("Fire tick rate: ", fire_tick_rate)

func get_behavior_name() -> String:
	return "FireBehavior"

func on_projectile_created(projectile):
	# Skip if projectile is invalid
	if !is_instance_valid(projectile):
		return
		
	# Add fire visual to projectile
	var fire_particles = create_fire_particles()
	if is_instance_valid(fire_particles):
		projectile.add_child(fire_particles)
	
	# Set fire effect properties on the projectile
	projectile.set_meta("fire_damage", fire_damage)
	projectile.set_meta("fire_duration", fire_duration)
	projectile.set_meta("fire_tick_rate", fire_tick_rate)
	
	# Change projectile color to fiery orange/red
	projectile.modulate = fire_color
	
	if DEBUG:
		print("Applied fire behavior to projectile")

# Apply fire effect when hitting a target
func on_projectile_hit(projectile, target):
	# Validate parameters
	if !is_instance_valid(projectile) or !is_instance_valid(target):
		return
	apply_fire_effect(target)

# Apply fire effect when weapon hits directly
func on_hit(target):
	# Validate parameter
	if !is_instance_valid(target):
		return
	apply_fire_effect(target)

# Main function to apply fire status effect
func apply_fire_effect(target):
	# Only apply to valid targets that can take damage
	if !is_instance_valid(target) or !target.has_method("take_damage"):
		return
	
	# Check if target has a method to apply status effects
	if target.has_method("apply_status_effect"):
		# Pass the effect to the target's handler
		var effect_data = {
			"type": "fire",
			"damage": fire_damage,
			"duration": fire_duration,
			"tick_rate": fire_tick_rate,
			"source": weapon
		}
		target.apply_status_effect(effect_data)
	else:
		# Fallback: Implement fire effect directly
		apply_fire_effect_directly(target)
	
	# Create fire visual on target
	create_fire_effect_on_target(target)
	
	if DEBUG:
		print("Applied fire effect to: ", target.name)

# Fallback method if target doesn't handle status effects
func apply_fire_effect_directly(target):
	# Check if already burning - just refresh duration
	if target.has_meta("fire_effect_active") and target.get_meta("fire_effect_active"):
		target.set_meta("fire_effect_timer", 0.0)
		return
	
	# Set fire effect as active
	target.set_meta("fire_effect_active", true)
	target.set_meta("fire_effect_timer", 0.0)
	target.set_meta("fire_damage", fire_damage)
	target.set_meta("fire_tick_timer", 0.0)
	
	# Create timer for damage ticks
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update at 10 times per second
	timer.autostart = true
	target.add_child(timer)
	
	# Store a reference to the callable for cleanup
	var timer_callable = func():
		# Skip if target is already defeated or invalid
		if !is_instance_valid(target) or ("is_defeated" in target and target.is_defeated):
			if is_instance_valid(timer):
				timer.queue_free()
			return
			
		# Update timers
		var effect_timer = target.get_meta("fire_effect_timer", 0.0) + 0.1
		var tick_timer = target.get_meta("fire_tick_timer", 0.0) + 0.1
		
		# Check if effect has expired
		if effect_timer >= fire_duration:
			target.set_meta("fire_effect_active", false)
			
			# Remove fire visuals
			for child in target.get_children():
				if is_instance_valid(child) and child.name == "FireEffect":
					child.queue_free()
			
			# Clean up timer
			if is_instance_valid(timer):
				timer.queue_free()
			return
			
		# Apply damage on tick interval
		if tick_timer >= fire_tick_rate:
			# Reset tick timer
			tick_timer = 0.0
			
			# Apply fire damage if target is valid
			if is_instance_valid(target) and target.has_method("take_damage"):
				# Fire damage pushes slightly upward
				var up_dir = Vector2(0, -1)
				target.take_damage(fire_damage, up_dir, 100)  # Small knockback
		
		# Update stored timers
		if is_instance_valid(target):
			target.set_meta("fire_effect_timer", effect_timer)
			target.set_meta("fire_tick_timer", tick_timer)
	
	# Store the callable in meta for later cleanup
	timer.set_meta("fire_callable", timer_callable)
	
	# Connect the timeout signal
	timer.timeout.connect(timer_callable)

# Create fire particles for projectile
func create_fire_particles():
	var particles = CPUParticles2D.new()
	particles.name = "FireParticles"
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = Vector2(0, -1)
	particles.spread = 90
	particles.gravity = Vector2(0, -20)  # Fire rises
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 50
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	
	# Fire colors gradient
	var gradient = Gradient.new()
	gradient.colors = [Color(1, 0.9, 0.1), Color(1, 0.3, 0.1)]
	particles.color_ramp = gradient
	
	particles.emitting = true
	
	return particles

# Create fire effect on target
func create_fire_effect_on_target(target):
	# Validate target
	if !is_instance_valid(target):
		return
		
	# Check if fire effect already exists
	for child in target.get_children():
		if is_instance_valid(child) and child.name == "FireEffect":
			return  # Already has fire effect
	
	# Create fire effect container
	var effect = Node2D.new()
	effect.name = "FireEffect"
	
	# Create fire particles
	var particles = create_fire_particles()
	particles.lifetime = 0.7
	particles.amount = 30
	effect.add_child(particles)
	
	# Add to target
	target.add_child(effect)
	
	# Create cleanup timer with safe signal handling
	var timer = Timer.new()
	timer.wait_time = fire_duration
	timer.one_shot = true
	
	# Create a callable for cleanup
	var cleanup_callable = func():
		if is_instance_valid(effect):
			effect.queue_free()
	
	# Store the callable for later disconnection
	timer.set_meta("cleanup_callable", cleanup_callable)
	
	# Connect and start the timer
	timer.timeout.connect(cleanup_callable)
	effect.add_child(timer)
	timer.start()
