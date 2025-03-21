# behavior.gd - Base class for weapon behaviors
class_name Behavior
extends Resource

# Debug flag
const DEBUG = false

# References
var weapon = null
var wielder = null

# Behavior parameters loaded from CSV
var params = {}

# Initialize the behavior with a weapon reference and parameters
func initialize(weapon_ref, parameters = {}):
	weapon = weapon_ref
	wielder = weapon_ref.wielder
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
	return "BaseBehavior"

# Process cooldown modifications if this behavior affects cooldowns
func modify_cooldown(current_cooldown: float) -> float:
	return current_cooldown # Default: no modification

# Called when the weapon is used
func on_weapon_used():
	pass

# Called when a projectile is created
func on_projectile_created(projectile):
	pass

# Called when something is hit
func on_hit(target):
	pass

# Called on successful attack
func on_attack_executed(attack_style: String):
	pass

# Called when attack ends
func on_attack_end():
	pass

# Helper to get parameter with a default value
func get_param(key: String, default_value = null):
	if key in params:
		return params[key]
	return default_value
