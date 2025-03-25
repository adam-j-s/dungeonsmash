# Creates multiple projectiles in a spread pattern
class_name MultishotBehavior
extends BehaviorBase

var projectile_count = 3  # Number of projectiles to fire
var projectile_spread = 15.0  # Angle spread in degrees
var count_modifier = 0  # Additional projectiles beyond base config

func _init_behavior():
	# Get parameters
	projectile_count = int(get_param("projectile_count", 3))
	projectile_spread = float(get_param("projectile_spread", 15.0))
	count_modifier = int(get_param("count_modifier", 0))
	
	# Apply count modifier if any
	projectile_count += count_modifier
	
	if DEBUG:
		print("Initialized multishot behavior with count: ", projectile_count, " spread: ", projectile_spread)

func get_behavior_name() -> String:
	return "MultishotBehavior"

# This behavior only affects weapon attack execution, not individual projectiles
func on_attack_executed(attack_style: String):
	# Only handle projectile attacks
	if attack_style != "projectile" and attack_style != "ImprovedProjectileAttackStyle":
		return
		
	# Skip if we don't have a valid weapon
	if !weapon or !weapon.wielder:
		return
	
	# Get attack handler from weapon
	var attack_handler = weapon.attack_handler
	if !attack_handler:
		return
		
	# The main projectile is already created by the weapon's attack style
	# We'll create the additional projectiles here
	
	# Get direction from wielder's sprite
	var attack_direction = 1 if weapon.wielder.get_node("Sprite2D").flip_h else -1
	var base_direction = Vector2(attack_direction, 0)
	
	# Reference position for spawning
	var spawn_position = weapon.wielder.global_position + Vector2(attack_direction * 30, 0)
	
	# Create additional projectiles with spread
	# Skipping index (projectile_count/2) as that's the center projectile already created
	var skip_index = floor(projectile_count / 2.0)
	
	for i in range(projectile_count):
		# Skip the center projectile (already created by attack handler)
		if i == skip_index:
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
		var offset_y = (i - skip_index) * 5  # Small vertical offset
		projectile.global_position = spawn_position + Vector2(0, offset_y)
		
		# Add to scene
		weapon.wielder.get_parent().add_child(projectile)
		
		# Notify weapon of projectile creation
		weapon.on_projectile_created(projectile)
		
	if DEBUG:
		print("Created ", projectile_count - 1, " additional projectiles")

