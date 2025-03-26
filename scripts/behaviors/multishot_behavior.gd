# Creates multiple projectiles in a spread pattern
class_name MultishotBehavior
extends BehaviorBase

var projectile_count = 3  # Number of projectiles to fire
var projectile_spread = 15.0  # Angle spread in degrees
var count_modifier = 0  # Additional projectiles beyond base config
var is_cluster = false  # Whether this is a cluster bomb
var split_delay = 0.6  # Delay before cluster splits

func _init_behavior():
	# Get parameters
	projectile_count = int(get_param("projectile_count", 3))
	projectile_spread = float(get_param("projectile_spread", 15.0))
	count_modifier = int(get_param("count_modifier", 0))
	
	# Special handling for cluster bombs
	is_cluster = weapon.weapon_id == "cluster_bomb" if weapon else false
	split_delay = float(get_param("split_delay", 0.6))
	
	# Apply count modifier if any
	projectile_count += count_modifier
	
	if DEBUG:
		print("Initialized multishot behavior with count: ", projectile_count, " spread: ", projectile_spread)
		if is_cluster:
			print("Cluster bomb mode enabled - will split after ", split_delay, " seconds")

func get_behavior_name() -> String:
	return "MultishotBehavior"

# Handle projectile creation for cluster bombs
func on_projectile_created(projectile):
	# Only set up special handling for cluster bombs
	if is_cluster:
		projectile.set_meta("is_cluster", true)
		projectile.set_meta("cluster_count", projectile_count)
		projectile.set_meta("cluster_spread", projectile_spread)
		projectile.set_meta("split_time", split_delay)
		projectile.set_meta("should_split", true)
		
		# Make it visually distinct
		projectile.modulate = Color(1.0, 0.6, 0.1)  # Orange tint
		
		if DEBUG:
			print("Set up cluster bomb projectile for splitting")

# Process the cluster bomb splitting
func on_projectile_process(projectile, delta):
	# Check if this is a cluster projectile that should split
	if projectile.get_meta("is_cluster", false) and projectile.get_meta("should_split", false):
		# Check if it's time to split
		if projectile.timer >= projectile.get_meta("split_time", split_delay):
			# Trigger the split
			create_cluster_projectiles(projectile)
			
			# Prevent future splits
			projectile.set_meta("should_split", false)
			
			# Remove the original projectile
			projectile.destroy()
			
			# Return true to indicate we've handled this projectile
			return true
	
	# Not handled, continue normal processing
	return false

# Create the cluster projectiles
func create_cluster_projectiles(parent_projectile):
	if DEBUG:
		print("Splitting cluster bomb into ", projectile_count, " projectiles")
	
	# Get scene and wielder
	var scene = parent_projectile.get_tree().current_scene
	
	# Get cluster parameters
	var count = parent_projectile.get_meta("cluster_count", projectile_count)
	var spread = parent_projectile.get_meta("cluster_spread", projectile_spread)
	
	# Get explosion radius from parent if available
	var explosion_radius = 40.0  # Default
	if "explosion_radius" in parent_projectile.get_meta_list():
		explosion_radius = parent_projectile.get_meta("explosion_radius")
	
	# Create child projectiles with spread
	for i in range(count):
		# Calculate spread angle
		var angle_offset = spread * (i - (count-1)/2.0) / ((count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		
		# Calculate direction - rotate current velocity
		var new_direction = parent_projectile.velocity.rotated(angle_rad).normalized()
		
		# Create projectile config
		var config = {
			"speed": parent_projectile.speed * 0.8,  # Slightly slower than parent
			"direction": new_direction,
			"lifetime": parent_projectile.get_meta("lifetime", 1.0),
			"damage": int(parent_projectile.damage * 0.7),  # Less damage per child
			"knockback": parent_projectile.knockback,
			"weapon_id": weapon.weapon_id if weapon else "",
			"explosion_radius": explosion_radius,
			"weapon": weapon
		}
		
		# Create projectile through factory
		var projectile = ProjectileFactory.create_projectile(config, parent_projectile.wielder_ref)
		
		# Set position to parent position
		projectile.global_position = parent_projectile.global_position
		
		# Add to scene
		scene.add_child(projectile)
		
		# Apply behaviors - CRITICAL
		if weapon and weapon.has_method("on_projectile_created"):
			weapon.on_projectile_created(projectile)
		
		if DEBUG:
			print("Created cluster child ", i, " at ", projectile.global_position)

# Handle normal multishot attack
func on_attack_executed(attack_style: String):
	# Only handle normal multishot for non-cluster weapons
	if is_cluster:
		return  # Don't create multiple projectiles at once for clusters
	
	# Only handle projectile attacks
	if attack_style != "projectile" and attack_style != "ImprovedProjectileAttackStyle":
		return
		
	# Skip if we don't have a valid weapon
	if !weapon or !weapon.wielder:
		return
	
	# Get direction from wielder's sprite
	var attack_direction = 1 if weapon.wielder.get_node("Sprite2D").flip_h else -1
	var base_direction = Vector2(attack_direction, 0)
	
	# Reference position for spawning
	var spawn_position = weapon.wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Create additional projectiles with spread
	# Skip the middle one as it's already created by normal attack
	var center_index = floor(projectile_count / 2.0)
	
	for i in range(projectile_count):
		# Skip the center projectile (already created by attack handler)
		if i == center_index:
			continue
			
		# Calculate spread angle
		var angle_offset = projectile_spread * (i - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		var direction = base_direction.rotated(angle_rad)
		
		# Create projectile config
		var config = {
			"speed": float(weapon.weapon_data.get("projectile_speed", 400)),
			"direction": direction,
			"lifetime": float(weapon.weapon_data.get("projectile_lifetime", 1.0)),
			"damage": weapon.calculate_damage(),
			"knockback": float(weapon.weapon_data.get("knockback_force", 500)),
			"weapon_id": weapon.weapon_id,
			"weapon": weapon
		}
		
		# Create projectile through factory
		var projectile = ProjectileFactory.create_projectile(config, weapon.wielder)
		
		# Set position with slight offset to prevent collision issues
		var offset_y = (i - center_index) * 5  # Small vertical offset
		projectile.global_position = spawn_position + Vector2(0, offset_y)
		
		# Add to scene
		weapon.wielder.get_parent().add_child(projectile)
		
		# Notify weapon of projectile creation - CRITICAL for behaviors
		weapon.on_projectile_created(projectile)
