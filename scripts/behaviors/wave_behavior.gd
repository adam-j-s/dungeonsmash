# Makes projectiles move in a wave pattern
class_name WaveBehavior
extends BehaviorBase

var wave_amplitude = 50.0  # Height of the wave
var wave_frequency = 3.0  # Frequency of the wave
var start_y = 0.0  # Initial Y position to wave around

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
	
	# Store starting Y position
	start_y = projectile.global_position.y
	projectile.set_meta("start_y", start_y)
	
	# Make projectile cyan/blue for visual identification
	projectile.modulate = Color(0.3, 0.7, 0.9)
	
	if DEBUG:
		print("Applied wave behavior to projectile")

# Handle wave movement in process
func on_projectile_process(projectile, delta):
	# If projectile is already a WaveProjectile, let it handle movement
	if projectile is WaveProjectile:
		return false  # Let projectile handle it
	
	# Get timer value for sine calculation
	var timer = projectile.timer
	
	# Get original start_y or use current y as base
	var base_y = projectile.get_meta("start_y", projectile.global_position.y)
	
	# Calculate wave offset
	var y_offset = sin(timer * wave_frequency) * wave_amplitude
	
	# Move projectile in standard X direction
	var move_x = 0
	if typeof(projectile.direction) == TYPE_VECTOR2:
		move_x = projectile.direction.x * projectile.speed * delta
		projectile.global_position.x += move_x
	else:
		move_x = projectile.direction * projectile.speed * delta
		projectile.global_position.x += move_x
	
	# Set Y position according to wave
	projectile.global_position.y = base_y + y_offset
	
	# Update velocity for physics (useful for collisions)
	var y_velocity = cos(timer * wave_frequency) * wave_amplitude * wave_frequency
	
	if typeof(projectile.velocity) == TYPE_VECTOR2:
		projectile.velocity.y = y_velocity
	
	return true  # Handled movement

