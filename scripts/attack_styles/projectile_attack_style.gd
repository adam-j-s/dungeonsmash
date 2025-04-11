# Creates basic projectiles with positioning - JSON version
class_name ProjectileAttackStyle
extends AttackStyle

# Configuration
var projectile_count = 1
var projectile_spread = 0.0

func _init_style():
	# Initialize minimal properties needed for projectile creation
	# Get values from JSON structure if available
	if weapon and "weapon_data" in weapon:
		if "projectile_count" in weapon.weapon_data:
			projectile_count = int(weapon.weapon_data.projectile_count)
		elif "stats" in weapon.weapon_data and "projectile_count" in weapon.weapon_data.stats:
			projectile_count = int(weapon.weapon_data.stats.projectile_count)
			
		if "projectile_spread" in weapon.weapon_data:
			projectile_spread = float(weapon.weapon_data.projectile_spread)
		elif "stats" in weapon.weapon_data and "projectile_spread" in weapon.weapon_data.stats:
			projectile_spread = float(weapon.weapon_data.stats.projectile_spread)
	else:
		# Fallback to params
		projectile_count = int(get_param("projectile_count", 1))
		projectile_spread = float(get_param("projectile_spread", 0.0))
	
	if DEBUG:
		print("Projectile style initialized with count: ", projectile_count)

func get_style_name() -> String:
	return "ProjectileAttackStyle"

# Main attack execution method
func execute_attack():
	if DEBUG:
		print("Executing projectile attack with weapon: ", weapon.get_weapon_name() if weapon else "None")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference - cannot execute attack")
		return false
	
	# Get the base count of projectiles to fire
	var proj_count = projectile_count
	
	# Check if any behavior wants to override the projectile count
	if weapon.has_node("BehaviorManager"):
		var behavior_manager = weapon.get_node("BehaviorManager")
		for behavior in behavior_manager.behaviors:
			if behavior.has_method("get_actual_projectile_count"):
				proj_count = behavior.get_actual_projectile_count()
				if DEBUG:
					print("Behavior overrode projectile count to: ", proj_count)
	
	# Create the appropriate number of projectiles with spread
	if proj_count > 1:
		# Create multiple projectiles with spread
		for i in range(proj_count):
			create_projectile(i)
	else:
		# Create single projectile
		create_projectile()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	on_attack_end()
	
	return true

# Create a projectile and apply behaviors from weapon configuration
func create_projectile(index = 0):
	if DEBUG:
		print("Creating projectile...")
	
	# Calculate direction and position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Apply spread angle if this is a multi-projectile weapon
	var direction_vector = Vector2(attack_direction, 0)
	if projectile_count > 1 and projectile_spread > 0:
		# Calculate spread angle based on index
		var angle_offset = projectile_spread * (index - (projectile_count-1)/2.0) / ((projectile_count-1)/2.0)
		var angle_rad = deg_to_rad(angle_offset)
		direction_vector = direction_vector.rotated(angle_rad)
	
	# Position in front of wielder
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Get flags from weapon
	var friendly_fire = false
	var allow_self_damage = false
	
	# Get flags from proper location in weapon data
	if "flags" in weapon.weapon_data:
		friendly_fire = weapon.weapon_data.flags.get("friendly_fire", false)
		allow_self_damage = weapon.weapon_data.flags.get("allow_self_damage", false)
	else:
		# Fallback to metadata or flat structure
		if weapon.has_meta("friendly_fire"):
			friendly_fire = weapon.get_meta("friendly_fire")
		else:
			friendly_fire = weapon.weapon_data.get("friendly_fire", false)
			
		if weapon.has_meta("allow_self_damage"):
			allow_self_damage = weapon.get_meta("allow_self_damage")
		else:
			allow_self_damage = weapon.weapon_data.get("allow_self_damage", false)
	
	if DEBUG:
		print("DEBUG: Creating projectile with flags: friendly_fire=", friendly_fire, 
			  ", allow_self_damage=", allow_self_damage)
	
	# Get projectile speed from proper location
	var projectile_speed = 400.0  # Default
	if "projectile" in weapon.weapon_data and weapon.weapon_data.projectile != null:
		if "speed" in weapon.weapon_data.projectile and weapon.weapon_data.projectile.speed != null:
			projectile_speed = float(weapon.weapon_data.projectile.speed)
	else:
		projectile_speed = float(get_param("projectile_speed", 400.0))
	
	# Get projectile lifetime from proper location
	var projectile_lifetime = 1.0  # Default
	if "projectile" in weapon.weapon_data and weapon.weapon_data.projectile != null:
		if "lifetime" in weapon.weapon_data.projectile and weapon.weapon_data.projectile.lifetime != null:
			projectile_lifetime = float(weapon.weapon_data.projectile.lifetime)
	else:
		projectile_lifetime = float(get_param("projectile_lifetime", 1.0))
	
	# Get knockback from proper location
	var knockback_force = 500.0  # Default
	if "stats" in weapon.weapon_data and "knockback_force" in weapon.weapon_data.stats:
		knockback_force = float(weapon.weapon_data.stats.knockback_force)
	else:
		knockback_force = float(get_param("knockback_force", 500.0))
		
	# Create basic configuration object
	var config = {
		"speed": projectile_speed,
		"direction": direction_vector,
		"lifetime": projectile_lifetime,
		"damage": weapon.calculate_damage(),
		"knockback": knockback_force,
		"weapon_id": weapon.weapon_id,
		"weapon": weapon,
		"friendly_fire": friendly_fire,
		"allow_self_damage": allow_self_damage,
		"ensure_signal_safety": true  # Add a flag to tell factory to ensure signal safety
	}
	
	# Create a standard projectile
	var projectile = ProjectileFactory.create_projectile(config, wielder)
	
	# IMPORTANT: First position the projectile correctly
	projectile.global_position = spawn_position
	# Set projectile index as metadata for behaviors to use
	projectile.set_meta("projectile_index", index)
	
	# THEN apply behaviors after positioning
	if weapon and weapon.has_method("on_projectile_created"):
		print("Notifying weapon of projectile creation for behavior application")
		weapon.on_projectile_created(projectile)
	
	# Debug output after behaviors have been applied
	print("Created projectile: ", projectile.name)
	print("Behaviors attached: ", projectile.behaviors.size() if "behaviors" in projectile else "No behaviors array")
	
	# Check for specific behaviors
	if projectile.has_method("has_behavior"):
		# Log all behaviors for debugging
		for behavior in projectile.behaviors:
			if behavior and behavior.has_method("get_behavior_name"):
				print("- Has behavior: ", behavior.get_behavior_name())
	
	# Add to scene
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		if DEBUG:
			print("Added projectile at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add projectile to scene - no parent for wielder")
		projectile.queue_free()
		return null
	
	return projectile
