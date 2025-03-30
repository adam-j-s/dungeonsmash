# behavior_base.gd - Base class for all weapon behaviors
class_name BehaviorBase
extends Resource

# Debug flag
const DEBUG = true

# References
var weapon = null
var wielder = null

# Behavior parameters loaded from CSV
var params = {}

# Initialize the behavior with a weapon reference and parameters
func initialize(weapon_ref, parameters = {}):
	weapon = weapon_ref
	wielder = weapon_ref.wielder if weapon_ref else null
	params = parameters
	_init_behavior()
	
	if DEBUG:
		print("Initialized behavior: ", get_behavior_name())
		print("Parameters: ", params)

# Override this in child behaviors for custom initialization
func _init_behavior():
	pass

# Get the name of this behavior
func get_behavior_name() -> String:
	return "BehaviorBase"

# Process cooldown modifications if this behavior affects cooldowns
func modify_cooldown(current_cooldown: float) -> float:
	return current_cooldown # Default: no modification

# Called when the weapon is used
func on_weapon_used():
	if DEBUG:
		print(get_behavior_name() + ": weapon used")
	pass

# Called when a projectile is created
func on_projectile_created(projectile):
	if DEBUG:
		print(get_behavior_name() + ": projectile created")
	pass

# Called during projectile's process function (movement & behavior)
# Return true if the behavior handled movement, false otherwise
func on_projectile_process(projectile, delta):
	if DEBUG:
		print(get_behavior_name() + ": projectile process")
	return false # Default: didn't handle movement

# Called during projectile's physics_process function
# Return true if the behavior handled physics, false otherwise
func on_projectile_physics_process(projectile, delta):
	if DEBUG:
		print(get_behavior_name() + ": projectile physics process")
	return false # Default: didn't handle physics

# Called when a projectile hits something
func on_projectile_hit(projectile, target):
	if DEBUG:
		print(get_behavior_name() + ": projectile hit " + target.name)
	pass

# Called when a projectile is destroyed
func on_projectile_destroyed(projectile):
	if DEBUG:
		print(get_behavior_name() + ": projectile destroyed")
	pass

# Called when something is hit
func on_hit(target):
	if DEBUG:
		print(get_behavior_name() + ": hit " + target.name)
	pass

# Called on successful attack
func on_attack_executed(attack_style: String):
	if DEBUG:
		print(get_behavior_name() + ": attack executed with style " + attack_style)
	pass

# Called when attack ends
func on_attack_end():
	if DEBUG:
		print(get_behavior_name() + ": attack ended")
	pass

# Helper to get parameter with a default value
func get_param(key: String, default_value = null):
	if key in params:
		return params[key]
	return default_value
