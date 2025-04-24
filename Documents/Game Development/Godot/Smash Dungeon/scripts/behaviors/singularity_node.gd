# SingularityNode - Custom node for singularity effects - JSON compatible
class_name SingularityNode
extends Area2D

signal singularity_ended

# Configuration
var pull_radius: float = 150.0
var pull_strength: float = 600.0
var max_duration: float = 2.0
var explosion_radius: float = 120.0
var wielder_ref = null
var weapon_ref = null
var allow_self_pull = false
var allow_self_damage = false  # Added to store explosion self-damage setting

# Runtime state
var duration: float = 0.0
var affected_bodies: Array = []
const DEBUG = true

func _ready():
	if DEBUG:
		print("SINGULARITY NODE READY: Initialized with pull_strength: ", pull_strength)
		print("  pull_radius: " + str(pull_radius))
		print("  pull_strength: " + str(pull_strength))
		print("  max_duration: " + str(max_duration))
		print("  explosion_radius: " + str(explosion_radius))
		print("  allow_self_pull: " + str(allow_self_pull))
		print("  allow_self_damage: " + str(allow_self_damage))
	
	# Set up body detection with safer signal handling
	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if !body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Set up timer for lifetime
	var timer = Timer.new()
	timer.wait_time = max_duration
	timer.one_shot = true
	
	# Store the callable for later cleanup
	var timeout_callable = Callable(self, "_on_lifetime_ended")
	timer.set_meta("timeout_callable", timeout_callable)
	
	# Connect and start
	timer.timeout.connect(timeout_callable)
	add_child(timer)
	timer.start()

func _process(delta):
	# Add instance validation check
	if !is_instance_valid(self):
		return
	
	# Update duration
	duration += delta
	
	# Pull nearby bodies
	pull_affected_bodies(delta)
	
	# Update visuals
	update_visuals(delta)

# Separated function to apply pull forces
func pull_affected_bodies(delta):
	# Create a temporary copy of the array to allow safe modification during iteration
	var bodies_to_process = affected_bodies.duplicate()
	
	for body in bodies_to_process:
		# Skip invalid bodies
		if !is_instance_valid(body):
			affected_bodies.erase(body)
			continue
			
		# Skip non-character bodies
		if !(body is CharacterBody2D):
			continue
			
		# Calculate direction to singularity
		var pull_dir = (global_position - body.global_position).normalized()
		
		# Strength based on distance (inverse square law)
		var distance = global_position.distance_to(body.global_position)
		var strength = pull_strength
		
		# Avoid division by zero and make close range stronger
		if distance > 10:
			strength = pull_strength / (distance * 0.1)
		else:
			strength = pull_strength * 5
		
		# Apply pull as force
		if "velocity" in body:
			body.velocity += pull_dir * strength * delta * 30
		
		# Also modify position directly
		body.global_position += pull_dir * strength * delta * 0.5

func _on_body_entered(body):
	# Validate body and wielder
	if !is_instance_valid(body) or !is_instance_valid(wielder_ref):
		return
		
	# Check if this is the wielder
	var is_wielder = (body == wielder_ref)
	
	# Allow wielder to be affected if allow_self_pull is true
	if is_wielder and !allow_self_pull:
		if DEBUG:
			print("Wielder entered singularity but self-pull not allowed")
		return
		
	# Don't add the same body twice
	if body in affected_bodies:
		return
		
	# Add body to affected list
	affected_bodies.append(body)
	
	if DEBUG:
		if is_wielder:
			print("Wielder entered singularity - self-pull allowed")
		else:
			print("Body entered singularity: ", body.name)

func _on_body_exited(body):
	# Only remove bodies that are in the affected list
	if body in affected_bodies:
		affected_bodies.erase(body)
		
		if DEBUG:
			print("Body exited singularity: ", body.name)

func update_visuals(delta):
	# Find the visual child
	var visual = null
	for child in get_children():
		if is_instance_valid(child) and child is ColorRect:
			visual = child
			break
	
	if is_instance_valid(visual):
		# Grow the visual over time
		visual.scale = Vector2(1, 1) * (1 + duration / max_duration)
		
		# Increase opacity near end for dramatic effect
		if duration > max_duration * 0.8:
			visual.color.a = 0.5 + ((duration - (max_duration * 0.8)) / (max_duration * 0.2)) * 0.5

func _on_lifetime_ended():
	if DEBUG:
		print("Singularity lifetime ended, allow_self_damage=", allow_self_damage)
		
	# Signal that singularity is ending
	emit_signal("singularity_ended")

# Clean up function to disconnect signals
func cleanup():
	if DEBUG:
		print("Cleaning up singularity node")
		
	# Disconnect signals to prevent errors - use is_connected check for safety
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)
	
	# Clear affected bodies
	affected_bodies.clear()
