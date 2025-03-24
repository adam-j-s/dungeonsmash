# Makes projectiles track targets
class_name HomingBehavior
extends Behavior

var target = null
var tracking_multiplier = 5.0  # Increased multiplier for stronger homing effect

func _init_behavior():
	# Any additional setup specific to homing
	pass

func get_behavior_name() -> String:
	return "HomingBehavior"

func on_projectile_created(projectile):
	# Apply homing properties to the projectile
	var homing_strength = float(get_param("homing_strength", 0.5))
	
	# Ensure minimum homing strength for better effectiveness
	homing_strength = max(homing_strength, 0.2)
	
	# Set properties on the projectile
	projectile.homing_strength = homing_strength
	projectile.set_meta("homing_strength", homing_strength)
	projectile.projectile_type = "homing"
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["homing_strength"] = homing_strength
		config["projectile_type"] = "homing"
		projectile.apply_config(config)
	
	# Add this behavior directly to the projectile for callbacks
	if projectile.has_method("add_behavior"):
		projectile.add_behavior(self)
	
	if DEBUG:
		print("Applied homing behavior to projectile with strength: ", homing_strength)

# NEW: Process the projectile's movement (called from projectile.gd)
func on_projectile_process(projectile, delta):
	# Find the target if we don't have one yet
	if !target:
		target = find_target(projectile)
	
	if target:
		# Get direction to target
		var to_target = (target.global_position - projectile.global_position).normalized()
		
		# Get the homing strength
		var strength = projectile.homing_strength
		
		# Calculate the turn rate - stronger homing for more aggressive tracking
		var turn_rate = delta * strength * tracking_multiplier
		
		# Update velocity with stronger tracking
		var current_velocity = projectile.velocity
		var speed = current_velocity.length()
		
		# Gradually adjust direction toward target
		var new_velocity = current_velocity.lerp(to_target * speed, turn_rate)
		
		# Maintain original speed to prevent acceleration
		if new_velocity.length() > 0:
			new_velocity = new_velocity.normalized() * speed
		
		# Apply the new velocity
		projectile.velocity = new_velocity
		
		# Move the projectile directly for immediate effect
		projectile.global_position += new_velocity * delta
		
		# Visual feedback
		projectile.modulate = Color(0.5 + 0.5 * sin(projectile.timer * 5), 0.5, 1.0)
		
		if DEBUG:
			print("Homing behavior tracking target: ", target.name)
		
		# Return true to indicate we've handled movement
		return true
	
	# Return false if we couldn't handle movement (no target)
	return false

# NEW: Physics process handler
func on_projectile_physics_process(projectile, delta):
	# We don't need to do anything special here
	return false  # Let projectile handle physics normally

# Helper function to find a suitable target
func find_target(projectile):
	# Get wielder reference
	var wielder_ref = projectile.wielder_ref
	if !wielder_ref:
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

# NEW: Handle what happens when projectile hits a target
func on_projectile_hit(projectile, target):
	if DEBUG:
		print("Homing projectile hit target: ", target.name)
	# Nothing special needed beyond default behavior

# NEW: Handle what happens when projectile is destroyed
func on_projectile_destroyed(projectile):
	if DEBUG:
		print("Homing projectile destroyed")
	# Nothing special needed beyond default behavior
