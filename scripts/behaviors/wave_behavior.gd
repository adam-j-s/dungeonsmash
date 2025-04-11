# Wave Behavior - Makes projectiles move in a wave pattern - JSON compatible
class_name WaveBehavior
extends BehaviorBase

var wave_amplitude = 50.0  # Height of the wave
var wave_frequency = 3.0  # Frequency of the wave
var vertical_offset = 0.0  # Offset from center line
var original_y = 0.0  # Initial Y position
var reverse_direction = false  # Whether to reverse the wave direction

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get amplitude parameter
		if "wave_amplitude" in behavior_params:
			wave_amplitude = float(behavior_params.wave_amplitude)
		elif "amplitude" in behavior_params:
			wave_amplitude = float(behavior_params.amplitude)
		else:
			wave_amplitude = float(get_param("wave_amplitude", 50.0))
		
		# Get frequency parameter
		if "wave_frequency" in behavior_params:
			wave_frequency = float(behavior_params.wave_frequency)
		elif "frequency" in behavior_params:
			wave_frequency = float(behavior_params.frequency)
		else:
			wave_frequency = float(get_param("wave_frequency", 3.0))
			
		# Get optional vertical offset
		if "vertical_offset" in behavior_params:
			vertical_offset = float(behavior_params.vertical_offset)
		else:
			vertical_offset = float(get_param("vertical_offset", 0.0))
			
		# Get optional direction reversal
		if "reverse_direction" in behavior_params:
			reverse_direction = bool(behavior_params.reverse_direction)
		else:
			reverse_direction = bool(get_param("reverse_direction", false))
	else:
		# Fallback to flat parameters
		wave_amplitude = float(get_param("wave_amplitude", 50.0))
		wave_frequency = float(get_param("wave_frequency", 3.0))
		vertical_offset = float(get_param("vertical_offset", 0.0))
		reverse_direction = bool(get_param("reverse_direction", false))
	
	# Check weapon data for specific wave settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for wave settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a wave behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "wave":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get parameters if specified
						if "wave_amplitude" in behavior_params:
							wave_amplitude = float(behavior_params.wave_amplitude)
						if "wave_frequency" in behavior_params:
							wave_frequency = float(behavior_params.wave_frequency)
	
	# Ensure reasonable values
	wave_amplitude = max(5.0, wave_amplitude)  # Minimum amplitude
	wave_frequency = max(0.5, wave_frequency)  # Minimum frequency
	
	if DEBUG:
		print("Initialized wave behavior with amplitude: ", wave_amplitude, " frequency: ", wave_frequency)
		if vertical_offset != 0.0:
			print("Wave vertical offset: ", vertical_offset)
		if reverse_direction:
			print("Wave direction: reversed")

func get_behavior_name() -> String:
	return "WaveBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Set wave properties on the projectile
	projectile.set_meta("wave_amplitude", wave_amplitude)
	projectile.set_meta("wave_frequency", wave_frequency)
	projectile.set_meta("wave_elapsed_time", 0.0)
	projectile.set_meta("wave_vertical_offset", vertical_offset)
	projectile.set_meta("wave_reverse_direction", reverse_direction)
	
	# Store starting Y position - CRITICAL for wave pattern
	original_y = projectile.global_position.y + vertical_offset
	projectile.set_meta("original_y", original_y)
	
	# Make projectile cyan/blue for visual identification
	projectile.modulate = Color(0.3, 0.7, 0.9)
	
	# Add optional trail effect
	create_wave_trail(projectile)
	
	if DEBUG:
		print("Applied wave behavior to projectile with starting y: ", original_y)

# Create a simple trail effect for wave projectiles
func create_wave_trail(projectile):
	# Create a CPUParticles2D for the trail
	var particles = CPUParticles2D.new()
	particles.name = "WaveTrail"
	particles.amount = 10
	particles.lifetime = 0.3
	particles.local_coords = false  # Use global coordinates
	particles.emitting = true
	particles.one_shot = false
	
	# Set particle properties
	particles.direction = Vector2(0, 0)
	particles.spread = 10
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 0
	particles.initial_velocity_max = 0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	
	# Make particles fade out
	var gradient = Gradient.new()
	gradient.colors = [Color(0.3, 0.7, 0.9, 0.5), Color(0.3, 0.7, 0.9, 0.0)]
	particles.color_ramp = gradient
	
	# Add to projectile
	projectile.add_child(particles)

# Handle wave movement - completely override normal physics calculation
func on_projectile_physics_process(projectile, delta):
	# Validate projectile
	if !is_instance_valid(projectile):
		return false
	
	# Get cached wave parameters
	var amplitude = projectile.get_meta("wave_amplitude", wave_amplitude)
	var frequency = projectile.get_meta("wave_frequency", wave_frequency)
	var is_reversed = projectile.get_meta("wave_reverse_direction", reverse_direction)
	
	# Update elapsed time
	var elapsed = projectile.get_meta("wave_elapsed_time", 0.0) + delta
	projectile.set_meta("wave_elapsed_time", elapsed)
	
	# Get original y position
	var orig_y = 0.0
	if projectile.has_meta("original_y"):
		orig_y = projectile.get_meta("original_y")
	else:
		# If missing, store current position as original
		orig_y = projectile.global_position.y
		projectile.set_meta("original_y", orig_y)
	
	# Calculate forward movement based on direction and speed
	var move_delta = Vector2.ZERO
	if typeof(projectile.direction) == TYPE_VECTOR2:
		move_delta = projectile.direction * projectile.speed * delta
	else:
		move_delta = Vector2(projectile.direction * projectile.speed * delta, 0)
	
	# Apply forward movement
	projectile.global_position += move_delta
	
	# Calculate wave offset using sine function
	var direction_multiplier = -1.0 if is_reversed else 1.0
	var wave_offset = sin(elapsed * frequency) * amplitude * direction_multiplier
	
	# Apply wave offset by directly setting Y position
	projectile.global_position.y = orig_y + wave_offset
	
	# Set velocity for other systems that might need it
	if typeof(projectile.direction) == TYPE_VECTOR2:
		projectile.velocity = projectile.direction * projectile.speed
	else:
		projectile.velocity = Vector2(projectile.direction * projectile.speed, 0)
	
	# Calculate Y component of velocity for physics interactions
	var y_velocity = cos(elapsed * frequency) * amplitude * frequency * direction_multiplier
	projectile.velocity.y = y_velocity
	
	if DEBUG and Engine.get_frames_drawn() % 30 == 0:  # Only print every 30 frames
		print("Wave physics: time=", elapsed, 
			  " pos=", projectile.global_position,
			  " wave_offset=", wave_offset)
	
	# We've handled the physics completely - don't use default movement
	return true
