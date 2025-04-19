# Wave projectile - moves in a wave pattern - Fixed collision handling
class_name WaveProjectile
extends ProjectileBase

# Wave configuration
var wave_amplitude = 50.0
var wave_frequency = 3.0
var original_y = 0.0
var wave_time = 0.0
var wave_direction = 1.0  # 1.0 for up-first, -1.0 for down-first

func _ready():
	# Call the parent _ready first to set up base properties
	super._ready()
	
	# Store the initial Y position for the wave calculation
	original_y = global_position.y
	
	# Get wave parameters from metadata or use defaults
	if has_meta("wave_amplitude"):
		wave_amplitude = get_meta("wave_amplitude")
	if has_meta("wave_frequency"):
		wave_frequency = get_meta("wave_frequency")
	if has_meta("wave_direction"):
		wave_direction = get_meta("wave_direction")
	
	# Initialize timer to starting point
	wave_time = 0.0
	
	# Make sure collision mask is set properly by calling the base method
	setup_collision_masks()
	
	if DEBUG:
		print("Wave projectile initialized with amplitude: ", wave_amplitude, ", frequency: ", wave_frequency)
		print("Initial position: ", global_position, ", Original Y: ", original_y)
		print("Collision mask: ", collision_mask)

# Override setup_collision_masks to ensure proper collision handling
func setup_collision_masks():
	# Call the parent method to set up basic collision masks
	super.setup_collision_masks()
	
	# If we need any wave-specific collision adjustments, add them here
	
	if DEBUG:
		print("Wave projectile collision masks set up. Mask: ", collision_mask)

# Override the calculation method to include wave movement
func _calculate_movement(delta):
	# Update wave time
	wave_time += delta
	
	# Call parent method to handle basic velocity calculation
	super._calculate_movement(delta)
	
	# Calculate the wave offset
	var wave_offset = sin(wave_time * wave_frequency) * wave_amplitude * wave_direction
	
	# Directly set the Y position based on wave calculation
	global_position.y = original_y + wave_offset
	
	# Calculate Y velocity component for physics interactions
	var y_velocity = cos(wave_time * wave_frequency) * wave_amplitude * wave_frequency * wave_direction
	
	# Update velocity Y component while keeping X component
	velocity.y = y_velocity
	
	if DEBUG and Engine.get_frames_drawn() % 30 == 0:
		print("Wave movement: time=", wave_time, 
			  " pos=", global_position,
			  " wave_offset=", wave_offset,
			  " velocity=", velocity)
