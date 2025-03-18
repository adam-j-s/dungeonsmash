extends CharacterBody2D

# Basic properties
var speed = 400.0
var direction = 1
var lifetime = 1.0
var timer = 0.0
var damage = 10
var knockback = 500
var effects = []
var hit_effect = ""
var wielder_ref = null
var config_params = null  # Store parameters if initialize is called before ready
var initial_position = Vector2.ZERO  # Track starting position for debugging

# Called when the node enters the scene tree for the first time
func _ready():
	if has_meta("wielder"):
		wielder_ref = get_meta("wielder")
	
	# Store initial position for tracking
	initial_position = global_position
	
	# Apply stored config if initialize was called before ready
	if config_params != null:
		apply_config(config_params)
	
	# Make visually distinct for debugging
	modulate = Color(1.5, 1.5, 1.5)  # Brighter
	
	# Create a debug timer to verify the scene is processing
	var debug_timer = Timer.new()
	debug_timer.wait_time = 0.2
	debug_timer.one_shot = true
	debug_timer.timeout.connect(func(): print("Projectile timer fired - scene is processing"))
	add_child(debug_timer)
	debug_timer.start()
	
	print("Projectile created at: ", global_position, " with direction: ", direction)

# Use regular process instead of physics_process for more direct control
func _process(delta):
	# Visual indicator - pulse color to show function is running
	modulate = Color(1.0 + sin(timer * 10) * 0.5, 1.0, 1.0)
	
	# Move directly using global_position
	global_position += Vector2(direction * speed * delta, 0)
	
	# Print debug info - include distance traveled from start
	var distance = global_position - initial_position
	print("Projectile lifetime: " + str(timer) + "/" + str(lifetime) + 
		  ", position: " + str(global_position) + 
		  ", distance: " + str(distance.length()) +
		  ", speed: " + str(speed) +
		  ", direction: " + str(direction))
	
	# Check lifetime
	timer += delta
	if timer >= lifetime:
		print("Projectile reached end of lifetime, destroying")
		queue_free()

# Initialize the projectile with configuration
func initialize(config):
	print("Initialize called with: ", config)
	config_params = config
	
	# If already added to the scene tree, apply config immediately
	if is_inside_tree():
		apply_config(config)
	# Otherwise config will be applied in _ready
	
	return self  # Return self to allow method chaining

# Actually apply the configuration
func apply_config(config):
	# Set properties with more validation
	speed = float(config.get("speed", 400.0))
	direction = int(config.get("direction", 1))
	lifetime = float(config.get("lifetime", 1.0))
	damage = int(config.get("damage", 10))
	knockback = int(config.get("knockback", 500))
	effects = config.get("effects", [])
	hit_effect = config.get("hit_effect", "")
	
	# Ensure non-zero values for critical properties
	if speed == 0:
		speed = 400.0
		print("WARNING: Speed was zero, set to default 400")
	
	if direction == 0:
		direction = 1
		print("WARNING: Direction was zero, set to default 1")
	
	# Set initial velocity (though we're not using it with direct position manipulation)
	velocity = Vector2(direction * speed, 0)
	
	print("Projectile initialized - Speed: ", speed, " Direction: ", direction)
