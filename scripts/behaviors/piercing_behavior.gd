# simplified_piercing_behavior.gd - A reliable, minimal implementation
class_name PiercingBehavior
extends BehaviorBase

var piercing_count = 1  # How many targets to pierce through
var damage_decay_factor = 0.8  # Damage decreases by 20% for each pierce

func _init_behavior():
	# Get piercing parameters
	piercing_count = int(get_param("piercing", 1))
	damage_decay_factor = float(get_param("damage_decay_factor", 0.8))
	
	if DEBUG:
		print("Initialized piercing behavior with count: ", piercing_count)

func get_behavior_name() -> String:
	return "PiercingBehavior"

func on_projectile_created(projectile):
	# Set piercing properties on the projectile
	projectile.set_meta("piercing", piercing_count)
	projectile.set_meta("original_damage", projectile.damage)
	projectile.set_meta("hit_count", 0)
	projectile.set_meta("cancel_destruction", false)
	
	# Add blue tint to indicate piercing
	projectile.modulate = Color(0.3, 0.5, 1.0)
	
	if DEBUG:
		print("Applied piercing behavior to projectile with count: ", piercing_count)

# Handle piercing hit logic
func on_projectile_hit(projectile, target):
	# Safety check
	if !is_instance_valid(projectile) or !is_instance_valid(target):
		return
	
	# Get current hit count and piercing count
	var hit_count = projectile.get_meta("hit_count", 0)
	var remaining_pierces = projectile.get_meta("piercing", 0)
	
	# Set knockback to 0 FIRST - before any damage is applied
	# This is critical to prevent pushing
	var original_knockback = projectile.knockback
	projectile.knockback = 0
	
	# Increment hit counter
	hit_count += 1
	projectile.set_meta("hit_count", hit_count)
	
	if DEBUG:
		print("Piercing projectile hit [", hit_count, "], remaining pierces: ", remaining_pierces)
	
	# Reduce damage for next hit
	var original_damage = projectile.get_meta("original_damage", projectile.damage)
	projectile.damage = int(original_damage * pow(damage_decay_factor, hit_count))
	
	# If we have piercing left, prevent destruction
	if remaining_pierces > 0:
		# Decrement piercing counter
		remaining_pierces -= 1
		projectile.set_meta("piercing", remaining_pierces)
		
		# Set flag to prevent destruction
		projectile.set_meta("cancel_destruction", true)
		print("PIERCE DEBUG: Setting cancel_destruction=true, remaining=" + str(remaining_pierces))
		
		# IMPROVED SOLUTION: Just push forward slightly
		if typeof(projectile.direction) == TYPE_VECTOR2:
			var push_distance = projectile.direction.normalized() * 15  # Less aggressive push
			projectile.global_position += push_distance
		else:
			var dir_value = 1 if projectile.direction > 0 else -1
			projectile.global_position.x += dir_value * 15
		
		if DEBUG:
			print("Moved projectile slightly forward to pass through target")
	else:
		# Allow destruction after last pierce
		projectile.set_meta("cancel_destruction", false)
		projectile.knockback = original_knockback  # Restore for final hit
		print("PIERCE DEBUG: Setting cancel_destruction=false")
		if DEBUG:
			print("No more pierces, allowing destruction")
