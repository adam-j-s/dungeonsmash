# Makes projectiles move in a wave pattern
class_name WaveBehavior
extends BehaviorBase

var wave_amplitude = 50.0  # Height of the wave
var wave_frequency = 3.0  # Frequency of the wave
var original_y = 0.0  # Initial Y position
var elapsed_time = 0.0  # Track time for sine calculation

func _init_behavior():
	# Get wave parameters
	wave_amplitude = float(get_param("wave_amplitude", 50.0))
	wave_frequency = float(get_param("wave_frequency", 3.0))
	
	if DEBUG:
		print("Initialized wave behavior with amplitude: ", wave_amplitude, " frequency: ", wave_frequency)

func get_behavior_name() -> String:
	return "WaveBehavior"

func on_projectile_created(projectile):
	# Set wave properties on the projectile
	projectile.set_meta("wave_amplitude", wave_amplitude)
	projectile.set_meta("wave_frequency", wave_frequency)
	projectile.set_meta("wave_elapsed_time", 0.0)
	
	# Store starting Y position - CRITICAL for wave pattern
	original_y = projectile.global_position.y
	projectile.set_meta("original_y", original_y)
	
	# Make projectile cyan/blue for visual identification
	projectile.modulate = Color(0.3, 0.7, 0.9)
	
	if DEBUG:
		print("Applied wave behavior to projectile with starting y: ", original_y)

# Handle wave movement - completely override normal physics calculation
func on_projectile_physics_process(projectile, delta):
	# Update elapsed time
	var elapsed = projectile.get_meta("wave_elapsed_time", 0.0) + delta
	projectile.set_meta("wave_elapsed_time", elapsed)
	
	# Get original y position
	var orig_y = 0.0
	if projectile and is_instance_valid(projectile):
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
	var wave_offset = sin(elapsed * wave_frequency) * wave_amplitude
	
	# Apply wave offset by directly setting Y position
	projectile.global_position.y = orig_y + wave_offset
	
	# Set velocity for other systems that might need it
	if typeof(projectile.direction) == TYPE_VECTOR2:
		projectile.velocity = projectile.direction * projectile.speed
	else:
		projectile.velocity = Vector2(projectile.direction * projectile.speed, 0)
	
	# Calculate Y component of velocity for physics interactions
	var y_velocity = cos(elapsed * wave_frequency) * wave_amplitude * wave_frequency
	projectile.velocity.y = y_velocity
	
	if DEBUG and Engine.get_frames_drawn() % 10 == 0:  # Only print every 10 frames
		print("Wave physics: time=", elapsed, 
			  " pos=", projectile.global_position,
			  " wave_offset=", wave_offset)
	
	# We've handled the physics completely - don't use default movement
	return true
