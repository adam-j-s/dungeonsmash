# singularity_node.gd - Custom node for singularity effects
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

# Runtime state
var duration: float = 0.0
var affected_bodies: Array = []
const DEBUG = true

func _ready():
	print("SINGULARITY NODE READY: Initialized with pull_strength: ", pull_strength)
	# Set up body detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up timer for lifetime
	var timer = Timer.new()
	timer.wait_time = max_duration
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_ended)
	add_child(timer)
	timer.start()

func _process(delta):
	#Debug output just once at start
	if duration == 0:
			print("SINGULARITY PROCESS: Starting with pull_strength: ", pull_strength)
	duration += delta
	
	# Pull nearby bodies
	for body in affected_bodies:
		if is_instance_valid(body) and body is CharacterBody2D:
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
	
	# Update visuals
	update_visuals(delta)

func _on_body_entered(body):
	if body != wielder_ref and not body in affected_bodies:
		affected_bodies.append(body)

func _on_body_exited(body):
	if body in affected_bodies:
		affected_bodies.erase(body)

func update_visuals(delta):
	# Find the visual child
	var visual = null
	for child in get_children():
		if child is ColorRect:
			visual = child
			break
	
	if visual:
		# Grow the visual over time
		visual.scale = Vector2(1, 1) * (1 + duration / max_duration)
		
		# Increase opacity near end for dramatic effect
		if duration > max_duration * 0.8:
			visual.color.a = 0.5 + ((duration - (max_duration * 0.8)) / (max_duration * 0.2)) * 0.5

func _on_lifetime_ended():
	# Signal that singularity is ending
	emit_signal("singularity_ended")

# Clean up function to disconnect signals
func cleanup():
	# Disconnect signals to prevent errors
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)
