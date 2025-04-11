# Projectile that moves in a wave pattern
class_name WaveProjectile
extends ProjectileBase

var wave_amplitude = 50.0  # Height of the wave
var wave_frequency = 3.0  # Frequency of the wave
var start_y = 0.0  # Initial Y position
const WaveTrailScript = preload("res://scripts/effects/wave_trail.gd")

func _ready():
	super._ready()
	
	# Get wave parameters from metadata if available
	if has_meta("wave_amplitude"):
		wave_amplitude = get_meta("wave_amplitude")
	if has_meta("wave_frequency"):
		wave_frequency = get_meta("wave_frequency")
	
	# Store initial Y position
	start_y = global_position.y
	set_meta("start_y", start_y)
	
	# Set visual appearance - cyan/blue for wave projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.3, 0.7, 0.9)  # Cyan-blue color
	
	# Add wave trail effect
	add_wave_trail()
	
	# Adjust collision mask - wave projectiles usually ignore world collisions
	collision_mask = 0
	if wielder_ref and wielder_ref.name == "Player1":
		collision_mask = 4  # Detect Player 2
	else:
		collision_mask = 2  # Detect Player 1

# Override to implement wave movement calculation
func _calculate_movement(delta):
	# Calculate X velocity based on direction
	var x_velocity = 0
	if typeof(direction) == TYPE_VECTOR2:
		x_velocity = direction.x * speed
	else:
		x_velocity = direction * speed
	
	# Y velocity follows a cosine wave (derivative of sine position)
	var y_velocity = cos(timer * wave_frequency) * wave_amplitude * wave_frequency
	
	# Set the velocity vector for physics to use
	velocity = Vector2(x_velocity, y_velocity)
	
	return true  # Movement calculated

# Keep original method for backward compatibility
func _handle_movement(delta):
	return _calculate_movement(delta)

# Add visual trail to enhance wave effect
func add_wave_trail():
	# Create a trail effect node
	var trail = Line2D.new()
	trail.name = "WaveTrail"
	trail.default_color = Color(0.3, 0.7, 0.9, 0.5) # Matching wave color but transparent
	trail.width = 5
	trail.set_meta("max_points", 12) # Number of points to keep in trail
	
	trail.set_script(WaveTrailScript)
	
	# Add to projectile
	add_child(trail)
