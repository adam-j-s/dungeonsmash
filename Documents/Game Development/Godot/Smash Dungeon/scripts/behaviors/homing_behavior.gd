# Homing Behavior - JSON compatible version
class_name HomingBehavior
extends BehaviorBase

var homing_strength = 0.5  # How strongly it tracks targets (0-1)
var tracking_multiplier = 5.0  # Stronger homing for better effect
var target = null  # Cached target
var max_turn_angle = 180.0  # Maximum turn angle in degrees per second
var target_prediction = 0.0  # How much to predict target movement (0-1)
var color_pulse = true  # Whether to apply color pulsing effect

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get homing strength parameter
		if "homing_strength" in behavior_params:
			homing_strength = float(behavior_params.homing_strength)
		else:
			homing_strength = float(get_param("homing_strength", 0.5))
		
		# Get tracking multiplier if specified
		if "tracking_multiplier" in behavior_params:
			tracking_multiplier = float(behavior_params.tracking_multiplier)
		
		# Get max turn angle if specified
		if "max_turn_angle" in behavior_params:
			max_turn_angle = float(behavior_params.max_turn_angle)
		
		# Get target prediction if specified
		if "target_prediction" in behavior_params:
			target_prediction = float(behavior_params.target_prediction)
		
		# Get color pulse setting if specified
		if "color_pulse" in behavior_params:
			color_pulse = bool(behavior_params.color_pulse)
	else:
		# Get parameters from flat structure
		homing_strength = float(get_param("homing_strength", 0.5))
		tracking_multiplier = float(get_param("tracking_multiplier", 5.0))
		max_turn_angle = float(get_param("max_turn_angle", 180.0))
		target_prediction = float(get_param("target_prediction", 0.0))
		color_pulse = bool(get_param("color_pulse", true))
	
	# Check weapon data for specific homing settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for specific homing settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a homing behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "homing":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get homing strength if specified
						if "homing_strength" in behavior_params:
							homing_strength = float(behavior_params.homing_strength)
	
	# Ensure minimum homing strength for better effectiveness
	homing_strength = max(homing_strength, 0.2)
	
	# Clamp target prediction between 0 and 1
	target_prediction = clamp(target_prediction, 0.0, 1.0)
	
	if DEBUG:
		print("Initialized homing behavior with strength: ", homing_strength)
		print("Tracking multiplier: ", tracking_multiplier)
		print("Max turn angle: ", max_turn_angle)

func get_behavior_name() -> String:
	return "HomingBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Set homing properties on the projectile
	projectile.set_meta("homing_strength", homing_strength)
	projectile.set_meta("tracking_multiplier", tracking_multiplier)
	projectile.set_meta("max_turn_angle", max_turn_angle)
	
	# If projectile is already a HomingProjectile, update its properties
	if projectile is HomingProjectile:
		projectile.homing_strength = homing_strength
		
		# Set additional properties if accessible
		if "tracking_multiplier" in projectile:
			projectile.tracking_multiplier = tracking_multiplier
		if "max_turn_angle" in projectile:
			projectile.max_turn_angle = max_turn_angle
		if "target_prediction" in projectile:
			projectile.target_prediction = target_prediction
	
	# Apply homing visual style
	apply_homing_visual(projectile)
	
	if DEBUG:
		print("Applied homing behavior to projectile with strength: ", homing_strength)

# Apply visual style to homing projectile
func apply_homing_visual(projectile):
	# Set a blue-purple homing color
	projectile.modulate = Color(0.4, 0.5, 1.0)
	
	# Add a trail effect if possible
	if projectile.has_method("add_trail"):
		# Check if method exists before calling
		projectile.add_trail(Color(0.4, 0.5, 1.0, 0.5), 20)
	elif "get_children" in projectile:
		# Try to create a simple trail manually
		var trail_effect = create_trail_effect()
		if is_instance_valid(trail_effect):
			projectile.add_child(trail_effect)

# Create a simple trail effect
func create_trail_effect():
	# Create a CPUParticles2D for the trail
	var particles = CPUParticles2D.new()
	particles.name = "HomingTrail"
	particles.amount = 15
	particles.lifetime = 0.5
	particles.local_coords = false  # Use global coordinates
	particles.emitting = true
	particles.one_shot = false
	
	# Set particle properties
	particles.direction = Vector2(0, 0)
	particles.spread = 10
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 0
	particles.initial_velocity_max = 0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 4.0
	
	# Make particles fade out
	var gradient = Gradient.new()
	gradient.colors = [Color(0.4, 0.5, 1.0, 0.5), Color(0.4, 0.5, 1.0, 0.0)]
	particles.color_ramp = gradient
	
	return particles

# The main homing functionality
func on_projectile_process(projectile, delta):
	# Validate projectile
	if !is_instance_valid(projectile):
		return false
	
	# If this is a HomingProjectile, let it handle its own homing
	if projectile is HomingProjectile:
		return false  # Let projectile handle it
	
	# Get cached parameters from projectile if available
	var strength = projectile.get_meta("homing_strength", homing_strength)
	var multiplier = projectile.get_meta("tracking_multiplier", tracking_multiplier)
	var max_angle = projectile.get_meta("max_turn_angle", max_turn_angle)
	
	# Find the target if we don't have one yet
	if !target or !is_instance_valid(target):
		target = find_target(projectile)
	
	if target and is_instance_valid(target):
		# Get direction to target
		var target_pos = target.global_position
		
		# Apply target prediction if enabled
		if target_prediction > 0.0 and "velocity" in target:
			# Predict target's future position based on its velocity
			target_pos += target.velocity * delta * target_prediction * 20.0
		
		var to_target = (target_pos - projectile.global_position).normalized()
		
		# Calculate the turn rate based on delta time, strength and multiplier
		var turn_rate = delta * strength * multiplier
		
		# Limit maximum turn angle per second
		var max_turn_rate_delta = deg_to_rad(max_angle) * delta
		turn_rate = min(turn_rate, max_turn_rate_delta)
		
		# Get current velocity
		var current_velocity = projectile.velocity
		var speed = current_velocity.length()
		
		# Gradually adjust direction toward target
		var new_velocity = current_velocity.lerp(to_target * speed, turn_rate)
		
		# Maintain original speed to prevent acceleration
		if new_velocity.length() > 0:
			new_velocity = new_velocity.normalized() * speed
		
		# Apply the new velocity - ONLY update velocity, don't change position
		projectile.velocity = new_velocity
		
		# Update direction property if it exists
		if "direction" in projectile and typeof(projectile.direction) == TYPE_VECTOR2:
			projectile.direction = new_velocity.normalized()
		
		# Visual feedback - color pulsing
		if color_pulse and "timer" in projectile:
			projectile.modulate = Color(0.5 + 0.5 * sin(projectile.timer * 5), 0.5, 1.0)
		
		return true  # We handled the movement
	
	return false  # Let projectile handle standard movement

# Helper function to find a suitable target
func find_target(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return null
	
	# Get wielder reference
	var wielder_ref = projectile.wielder_ref
	if !is_instance_valid(wielder_ref):
		return null
	
	# Determine enemy name based on wielder
	var enemy_name = "Player2" if wielder_ref.name == "Player1" else "Player1"
	
	# Method 1: Find by name
	var root = projectile.get_tree().get_root()
	if root.has_node(enemy_name):
		return root.get_node(enemy_name)
	
	# Method 2: Find via group
	var players = projectile.get_tree().get_nodes_in_group("players")
	for player in players:
		if player != wielder_ref:
			return player
	
	# Method 3: Last resort - scan all CharacterBody2D nodes
	var scene = projectile.get_tree().current_scene
	for node in scene.get_children():
		if node is CharacterBody2D and node != wielder_ref:
			if node.name == "Player1" or node.name == "Player2":
				return node
	
	return null
