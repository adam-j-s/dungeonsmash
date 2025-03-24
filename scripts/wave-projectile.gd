# wave_projectile.gd - Projectile that moves in a wave pattern
class_name WaveProjectile
extends ProjectileBase

var wave_amplitude = 50.0  # Height of the wave
var wave_frequency = 3.0  # Frequency of the wave
var start_y = 0.0  # Initial Y position

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

# Override to implement wave movement
func _handle_movement(delta):
	# Update X position normally
	if typeof(direction) == TYPE_VECTOR2:
		global_position.x += direction.x * speed * delta
	else:
		global_position.x += direction * speed * delta
	
	# Y position follows a sine wave
	global_position.y = start_y + sin(timer * wave_frequency) * wave_amplitude
	
	# Update velocity for physics
	if typeof(direction) == TYPE_VECTOR2:
		velocity.x = direction.x * speed
	else:
		velocity.x = direction * speed
	
	# Y velocity follows cosine (derivative of sine)
	velocity.y = cos(timer * wave_frequency) * wave_amplitude * wave_frequency
	
	return true  # Movement handled

# Add visual trail to enhance wave effect
func add_wave_trail():
	# Create a trail effect node
	var trail = Line2D.new()
	trail.name = "WaveTrail"
	trail.default_color = Color(0.3, 0.7, 0.9, 0.5)  # Matching wave color but transparent
	trail.width = 5
	trail.set_meta("max_points", 12)  # Number of points to keep in trail
	
	# Create script to update trail
	var script = GDScript.new()
	script.source_code = """
	extends Line2D
	
	var max_points = 12
	
	func _ready():
		max_points = get_meta("max_points", 12)
	
	func _process(delta):
		# Add current position to front of line
		add_point(Vector2.ZERO)
		
		# Remove old points if too many
		while get_point_count() > max_points:
			remove_point(0)
	"""
	script.reload()
	trail.set_script(script)
	
	# Add to projectile
	add_child(trail)
