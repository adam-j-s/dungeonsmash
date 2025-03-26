# improved_homing_behavior.gd - Makes projectiles track targets
class_name ImprovedHomingBehavior
extends BehaviorBase

var homing_strength = 0.5  # How strongly it tracks targets (0-1)
var tracking_multiplier = 5.0  # Stronger homing for better effect
var target = null  # Cached target

func _init_behavior():
	# Get homing parameters
	homing_strength = float(get_param("homing_strength", 0.5))
	
	# Ensure minimum homing strength for better effectiveness
	homing_strength = max(homing_strength, 0.2)
	
	# Optional tracking multiplier
	if "tracking_multiplier" in params:
		tracking_multiplier = float(params["tracking_multiplier"])

func get_behavior_name() -> String:
	return "HomingBehavior"

func on_projectile_created(projectile):
	# Set homing properties on the projectile
	projectile.set_meta("homing_strength", homing_strength)
	
	# If projectile is already a HomingProjectile, update its properties
	if projectile is HomingProjectile:
		projectile.homing_strength = homing_strength
	
	if DEBUG:
		print("Applied homing behavior to projectile with strength: ", homing_strength)

# The main homing functionality
func on_projectile_process(projectile, delta):
	# If this is a HomingProjectile, let it handle its own homing
	if projectile is HomingProjectile:
		return false  # Let projectile handle it
	
	# Find the target if we don't have one yet
	if !target or !is_instance_valid(target):
		target = find_target(projectile)
	
	if target and is_instance_valid(target):
		# Get direction to target
		var to_target = (target.global_position - projectile.global_position).normalized()
		
		# Calculate the turn rate
		var turn_rate = delta * homing_strength * tracking_multiplier
		
		# Update velocity with tracking
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
		
		# Visual feedback
		projectile.modulate = Color(0.5 + 0.5 * sin(projectile.timer * 5), 0.5, 1.0)
		
		return true  # We handled the movement
	
	return false  # Let projectile handle standard movement

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
