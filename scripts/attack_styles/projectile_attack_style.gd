# projectile_attack_style.gd - Creates basic projectiles with positioning
class_name ProjectileAttackStyle
extends AttackStyle

# Configuration
var projectile_count = 1
var projectile_spread = 0.0

func _init_style():
	# Initialize minimal properties needed for projectile creation
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
	
	# Create the appropriate number of projectiles with spread
	if projectile_count > 1:
		# Create multiple projectiles with spread
		for i in range(projectile_count):
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
	
	# Create basic configuration object
	var config = {
		"speed": float(get_param("projectile_speed", 400)),
		"direction": direction_vector,
		"lifetime": float(get_param("projectile_lifetime", 1.0)),
		"damage": weapon.calculate_damage(),
		"knockback": float(get_param("knockback_force", 500)),
		"weapon_id": weapon.weapon_id,
		"weapon": weapon
	}
	
	# Create a standard projectile
	var projectile = ProjectileFactory.create_projectile(config, wielder)
	
	# Set position
	projectile.global_position = spawn_position
	
	# Add to scene
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		if DEBUG:
			print("Added projectile at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add projectile to scene - no parent for wielder")
		projectile.queue_free()
		return null
	
	# Notify weapon of projectile creation
	# This is where behaviors will be attached via BehaviorManager
	if weapon:
		weapon.on_projectile_created(projectile)
	
	return projectile
