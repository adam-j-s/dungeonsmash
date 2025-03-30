# Creates multiple projectiles in a spread pattern
class_name MultishotBehavior
extends BehaviorBase

var projectile_count = 3  # Number of projectiles to fire
var projectile_spread = 15.0  # Angle spread in degrees
var count_modifier = 0  # Additional projectiles beyond base config
var is_cluster = false  # Whether this is a cluster bomb
var split_delay = 0.2  # Delay before cluster splits
var use_carrier_mode = true  # Whether to use carrier mode for multishot

func _init_behavior():
	# Get parameters with safer parsing
	var count_param = get_param("projectile_count", "3")
	var spread_param = get_param("projectile_spread", "15.0")
	
	# Parse the parameters properly
	# Handle the case where parameters might be combined
	if typeof(count_param) == TYPE_STRING and "," in count_param:
		var parts = count_param.split(",")
		count_param = parts[0]  # Take just the first part before any comma
	
	# Convert to proper types safely
	if typeof(count_param) == TYPE_STRING:
		projectile_count = int(count_param)
	else:
		projectile_count = int(count_param)
		
	if typeof(spread_param) == TYPE_STRING:
		projectile_spread = float(spread_param)
	else:
		projectile_spread = float(spread_param)
		
	count_modifier = int(get_param("count_modifier", "0"))
	
	# Special handling for cluster bombs
	is_cluster = weapon.weapon_id == "cluster_bomb" if weapon else false
	split_delay = float(get_param("split_delay", "0.2"))
	
	# Apply count modifier if any
	projectile_count += count_modifier
	
	# Use carrier mode for all multishot weapons (safer)
	use_carrier_mode = true
	
	if DEBUG:
		print("Initialized multishot behavior with count: ", projectile_count, " spread: ", projectile_spread)
		if is_cluster:
			print("Cluster bomb mode enabled - will split after ", split_delay, " seconds")
		if use_carrier_mode:
			print("Using carrier mode for multishot")

func get_behavior_name() -> String:
	return "MultishotBehavior"

# This method tells ProjectileAttackStyle how many projectiles to spawn
func get_actual_projectile_count():
	# Always return 1 when in carrier mode - we'll handle the splitting ourselves
	if use_carrier_mode:
		return 1
	else:
		return projectile_count

# Called when weapon with multishot behavior is used
func on_weapon_used():
	# Set metadata on the weapon to indicate it's in multishot mode
	weapon.set_meta("is_multishot", true)
	weapon.set_meta("multishot_count", projectile_count)
	weapon.set_meta("multishot_spread", projectile_spread)
	weapon.set_meta("use_carrier_mode", use_carrier_mode)

# Handle projectile creation for multishot weapons
func on_projectile_created(projectile):
	# CRITICAL: Skip if this projectile is already a child of a carrier
	if projectile.has_meta("from_carrier") or projectile.has_meta("is_cluster_child"):
		return
	
	# For carrier mode, tag the projectile as a carrier
	if use_carrier_mode:
		projectile.set_meta("is_carrier", true)
		projectile.set_meta("carrier_count", projectile_count)
		projectile.set_meta("carrier_spread", projectile_spread)
		
		# Very short delay for regular multishot, longer for cluster bombs
		var delay = 0.05  # Very short delay for regular multishot
		if is_cluster:
			delay = split_delay  # Use longer delay for cluster bombs
		
		projectile.set_meta("carrier_split_delay", delay)
		
		# For cluster bombs, apply additional setup
		if is_cluster:
			projectile.set_meta("is_cluster", true)
			setup_cluster_bomb(projectile, 0)
		
		# Prevent players from riding projectiles
		projectile.collision_layer = 0
		
		if DEBUG:
			print("Set up carrier projectile with count: ", projectile_count)
		
		return

# Process the projectile each frame
func on_projectile_process(projectile, delta):
	# Check for carrier projectile that needs to split
	if projectile.has_meta("is_carrier"):
		var split_time = projectile.get_meta("carrier_split_delay", 0.05)
		
		# For cluster bombs, apply gravity physics using the original method
		if projectile.has_meta("is_cluster") and "velocity" in projectile:
			# Apply strong gravity effect to carrier
			projectile.velocity.y += 980 * 0.8 * delta  # Proper gravity value from old code
			
			if DEBUG and Engine.get_frames_drawn() % 30 == 0:
				print("Applied gravity to cluster bomb carrier, velocity: ", projectile.velocity)
		
		# Check if it's time to split
		if projectile.timer >= split_time:
			if DEBUG:
				print("Carrier projectile splitting at position ", projectile.global_position)
			
			# If this is a cluster bomb, use cluster bomb split
			if projectile.has_meta("is_cluster"):
				create_cluster_projectiles(projectile)
			else:
				# For regular multishot, split into multiple projectiles
				create_multishot_projectiles(projectile)
			
			# Remove the carrier projectile
			projectile.destroy()
			
			# Return true to indicate we've handled this projectile
			return true
	
	# Not handled, continue normal processing
	return false

# Set up cluster bomb specific behavior
func setup_cluster_bomb(projectile, index):
	# Mark as a cluster bomb projectile
	projectile.set_meta("is_cluster", true)
	projectile.set_meta("cluster_count", projectile_count)
	projectile.set_meta("cluster_spread", projectile_spread)
	projectile.set_meta("split_time", split_delay)
	projectile.set_meta("should_split", true)
	
	# Set gravity factor for cluster bombs
	projectile.set_meta("gravity_factor", 0.8)
	
	# Add upward velocity for better arc
	if "velocity" in projectile and typeof(projectile.velocity) == TYPE_VECTOR2:
		# Add strong upward component to create an arc
		projectile.velocity.y = -250  # Strong initial upward velocity
		
		if DEBUG:
			print("Applied upward velocity to cluster bomb: ", projectile.velocity)
	
	# Make it visually distinct
	projectile.modulate = Color(1.0, 0.3, 0.2)  # Red for cluster bomb
	
	if DEBUG:
		print("Set up cluster bomb projectile for splitting")

# Create multiple projectiles from a carrier projectile
func create_multishot_projectiles(carrier_projectile):
	if DEBUG:
		print("Splitting carrier into ", projectile_count, " projectiles")
	
	# Get scene and wielder
	var scene = carrier_projectile.get_tree().current_scene
	if !scene:
		print("ERROR: Scene not found for multishot projectiles")
		return
	
	# Get the count and spread
	var count = carrier_projectile.get_meta("carrier_count", projectile_count)
	var spread = carrier_projectile.get_meta("carrier_spread", projectile_spread)
	
	# Get other parent properties to pass along
	var parent_speed = carrier_projectile.speed
	var parent_lifetime = carrier_projectile.lifetime
	var parent_damage = carrier_projectile.damage
	var parent_knockback = carrier_projectile.knockback
	
	# Generate unique group ID
	var multishot_group_id = str(Time.get_ticks_msec()) + str(randi())
	
	# Create child projectiles with spread
	for i in range(count):
		# Calculate spread angle - similar to old code approach
		var angle_offset = spread * (i - (count-1)/2.0) / ((count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		
		# Calculate direction based on parent
		var base_direction = carrier_projectile.direction
		var new_direction
		
		# Handle different direction types
		if typeof(base_direction) == TYPE_VECTOR2:
			new_direction = base_direction.rotated(angle_rad)
		else:
			# Convert scalar direction to vector
			var dir_vector = Vector2(base_direction, 0)
			new_direction = dir_vector.rotated(angle_rad)
		
		# Create projectile config - copy all properties from parent
		var config = {
			"speed": parent_speed,
			"direction": new_direction,
			"lifetime": parent_lifetime,
			"damage": parent_damage,
			"knockback": parent_knockback,
			"weapon_id": weapon.weapon_id if weapon else ""
		}
		
		# Create the projectile
		var projectile = ProjectileFactory.create_projectile(config, carrier_projectile.wielder_ref)
		
		# CRITICAL: Mark this as a child from carrier to avoid recursion
		projectile.set_meta("from_carrier", true)
		
		# Metadata to identify this projectile
		projectile.set_meta("multishot_index", i)
		projectile.set_meta("multishot_group_id", multishot_group_id)
		
		# Setup proper collision masks - CRITICAL FIX!
		# Default mask should detect enemy and world, but NOT own player
		var enemy_mask = 4 if carrier_projectile.wielder_ref and carrier_projectile.wielder_ref.name == "Player1" else 2
		var world_mask = 1  # Terrain layer
		projectile.collision_mask = enemy_mask | world_mask
		
		# Position with offset to prevent self-collisions
		projectile.global_position = carrier_projectile.global_position
		
		# Apply an offset based on direction to prevent collisions
		projectile.global_position += new_direction.normalized() * (25 + 10 * i)
		
		# CRITICAL: Set collision layer to 0 to prevent player riding
		projectile.collision_layer = 0
		
		# Add to scene
		scene.add_child(projectile)
		
		# Apply behaviors from the weapon EXCEPT multishot
		if weapon and weapon.has_node("BehaviorManager"):
			var behavior_manager = weapon.get_node("BehaviorManager")
			if behavior_manager:
				# Apply only non-multishot behaviors
				for behavior in behavior_manager.behaviors:
					if behavior.get_behavior_name() == "HomingBehavior":
						if behavior.has_method("on_projectile_created"):
							behavior.on_projectile_created(projectile)
		
		if DEBUG:
			print("Created multishot projectile ", i, " at ", projectile.global_position)

# Create the cluster projectiles
func create_cluster_projectiles(parent_projectile):
	if DEBUG:
		print("Splitting cluster bomb into ", projectile_count, " projectiles")
	
	# Get scene and wielder
	var scene = parent_projectile.get_tree().current_scene
	if !scene:
		print("ERROR: Scene not found for cluster projectiles")
		return
	
	# Get explosion radius from parent
	var explosion_radius = 40.0
	if parent_projectile.has_meta("explosion_radius"):
		explosion_radius = parent_projectile.get_meta("explosion_radius")
	
	# Get parent properties
	var parent_speed = parent_projectile.speed if "speed" in parent_projectile else 300
	var parent_lifetime = parent_projectile.lifetime if "lifetime" in parent_projectile else 1.0
	var parent_damage = parent_projectile.damage if "damage" in parent_projectile else 6
	var parent_knockback = parent_projectile.knockback if "knockback" in parent_projectile else 250
	
	# CRITICAL: Determine parent direction correctly
	var parent_dir_x = 1.0
	if "direction" in parent_projectile:
		if typeof(parent_projectile.direction) == TYPE_VECTOR2:
			parent_dir_x = sign(parent_projectile.direction.x)
		else:
			parent_dir_x = sign(parent_projectile.direction)
	
	# Double-check direction with velocity as backup
	if "velocity" in parent_projectile and parent_projectile.velocity.x != 0:
		parent_dir_x = sign(parent_projectile.velocity.x)
		
	if DEBUG:
		print("Parent direction determined as: ", parent_dir_x)
	
	# Get parent velocity magnitude for creating child velocities
	var parent_speed_magnitude = parent_speed
	if "velocity" in parent_projectile:
		parent_speed_magnitude = parent_projectile.velocity.length()
	
	# Define colors for better visibility
	var colors = [Color(1.0, 0.6, 0.1), Color(0.2, 0.8, 0.3), Color(0.3, 0.5, 1.0)]
	
	# Load the gravity behavior script for adding to children
	var gravity_script = load("res://scripts/behaviors/gravity_behavior.gd")
	
	# Create child projectiles
	for i in range(projectile_count):
		# SIMPLIFIED CONFIG - focus on the key properties
		var config = {
			"damage": int(parent_damage * 0.7),
			"knockback": parent_knockback,
			"lifetime": parent_lifetime * 1.2,
			"explosion_radius": explosion_radius,
			"weapon_id": weapon.weapon_id if weapon else ""
		}
		
		# Set direction as scalar value - CRITICAL for correct direction
		config["direction"] = parent_dir_x
		
		# Create the projectile
		var projectile = ProjectileFactory.create_projectile(config, parent_projectile.wielder_ref)
		
		# Set metadata
		projectile.set_meta("is_cluster_child", true)
		projectile.set_meta("from_carrier", true)
		projectile.set_meta("cluster_child_index", i)
		projectile.set_meta("explosion_radius", explosion_radius)
		
		# Position at parent with offset to prevent collisions
		projectile.global_position = parent_projectile.global_position
		
		# Apply different offsets for each bomb
		var offset_x = parent_dir_x * 30 * (i - 1)  # -30, 0, 30 based on direction
		var offset_y = -20 * (i + 1)  # Higher offset for each bomb
		projectile.global_position += Vector2(offset_x, offset_y)
		
		# Set colors
		projectile.modulate = colors[i % colors.size()]
		
		# CRITICAL: Adjust velocity for proper arcs
		if "velocity" in projectile:
			var velocity_x = parent_dir_x * parent_speed_magnitude * 0.8
			
			# Different vertical velocities for different arcs
			var velocity_y = 0
			if i == 0:      # Left bomb - higher arc
				velocity_y = -200  # High arc
			elif i == 1:    # Middle bomb
				velocity_y = -150  # Medium arc
			else:           # Right bomb
				velocity_y = -100  # Low arc
				
			projectile.velocity = Vector2(velocity_x, velocity_y)
			
			if DEBUG:
				print("Child ", i, " initial velocity: ", projectile.velocity)
		
		# CRITICAL: Set collision to prevent player riding
		projectile.collision_layer = 0
		
		# Set proper collision mask
		var enemy_mask = 4 if parent_projectile.wielder_ref and parent_projectile.wielder_ref.name == "Player1" else 2
		var world_mask = 1
		projectile.collision_mask = enemy_mask | world_mask
		
		# Add a dedicated gravity behavior to each child bomb
		if gravity_script:
			var gravity_behavior = gravity_script.new()
			
			# Initialize the gravity behavior
			if gravity_behavior.has_method("_init_behavior_with_params"):
				var gravity_params = {"gravity_factor": "1.5"}  # Stronger gravity
				gravity_behavior._init_behavior_with_params(gravity_params)
			
			# Add behavior to projectile
			projectile.add_behavior(gravity_behavior)
			
			if DEBUG:
				print("Added dedicated gravity behavior to child ", i)
		
		# Add to scene
		scene.add_child(projectile)
		
		# Apply explosive behavior
		if weapon and weapon.has_node("BehaviorManager"):
			var behavior_manager = weapon.get_node("BehaviorManager")
			if behavior_manager:
				for behavior in behavior_manager.behaviors:
					if behavior.get_behavior_name() == "ExplosiveBehavior":
						if behavior.has_method("on_projectile_created"):
							behavior.on_projectile_created(projectile)
		
		if DEBUG:
			print("Created cluster child ", i, " at ", projectile.global_position)
