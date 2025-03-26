# homing_projectile.gd - Projectile that homes in on targets
class_name HomingProjectile
extends ProjectileBase

var homing_strength = 0.5  # How strongly the projectile homes in (0-1)
var target = null  # Current target being tracked

func _ready():
	super._ready()
	
	# Get homing strength from metadata if available
	if has_meta("homing_strength"):
		homing_strength = get_meta("homing_strength")
	
	# Ensure minimum homing strength for better effectiveness
	homing_strength = max(homing_strength, 0.2)
	
	# Set visual appearance - blue for homing projectiles
	for child in get_children():
		if child is ColorRect:
			child.color = Color(0.2, 0.4, 1.0)  # Blue color
	
	# Adjust collision mask - homing projectiles should hit both world and enemies
	setup_collision_masks()

# Override to implement homing behavior - now only calculating velocity
func _calculate_movement(delta):
	# Find the target if we don't have one yet
	if !target or !is_instance_valid(target):
		target = find_target()
	
	if target and is_instance_valid(target):
		# Get direction to target
		var to_target = (target.global_position - global_position).normalized()
		
		# Calculate the turn rate - stronger homing for more aggressive tracking
		var tracking_multiplier = 5.0
		var turn_rate = delta * homing_strength * tracking_multiplier
		
		# Update velocity with tracking
		var current_velocity = velocity
		var current_speed = current_velocity.length()
		
		# Gradually adjust direction toward target
		var new_velocity = current_velocity.lerp(to_target * current_speed, turn_rate)
		
		# Maintain original speed to prevent acceleration
		if new_velocity.length() > 0:
			new_velocity = new_velocity.normalized() * current_speed
		
		# Apply the new velocity - ONLY update velocity, don't change position
		velocity = new_velocity
		
		# Visual feedback - pulse blue color
		for child in get_children():
			if child is ColorRect:
				child.modulate = Color(0.5 + 0.5 * sin(timer * 5), 0.5, 1.0)
		
		return true  # Movement handled
	
	# If no target, fall back to standard movement
	return super._calculate_movement(delta)

# Keep original method for backward compatibility
func _handle_movement(delta):
	return _calculate_movement(delta)

# Find a suitable target
func find_target():
	# Get wielder reference
	if !wielder_ref:
		return null
	
	# Determine enemy name based on wielder
	var enemy_name = "Player2" if wielder_ref.name == "Player1" else "Player1"
	
	# Method 1: Find by name
	var root = get_tree().get_root()
	if root.has_node(enemy_name):
		return root.get_node(enemy_name)
	
	# Method 2: Find via group
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player != wielder_ref:
			return player
	
	# Method 3: Last resort - scan all CharacterBody2D nodes
	var scene = get_tree().current_scene
	for node in scene.get_children():
		if node is CharacterBody2D and node != wielder_ref:
			if node.name == "Player1" or node.name == "Player2":
				return node
	
	return null
