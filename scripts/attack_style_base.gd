# attack_style_base.gd - Base class for weapon attack styles
class_name AttackStyle
extends Resource

# Debug flag
const DEBUG = true

# References to weapon and wielder
var weapon = null
var wielder = null

# Initialize with weapon reference
func initialize(weapon_ref):
	print("AttackStyle.initialize called with weapon: ", weapon_ref.weapon_id if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")
	else:
		print("WARNING: No weapon reference provided to attack style")
	
	_init_style()
	
	print("Attack style initialized: ", get_style_name())

# Override in child classes for custom initialization
func _init_style():
	pass

# Get the name of this attack style
func get_style_name() -> String:
	return "BaseAttackStyle"

# Execute the attack - override this in child classes
func execute_attack():
	# Base implementation does nothing
	print("Base attack style executed - should be overridden by child classes")

# Get a parameter from the weapon data
func get_param(param_name, default_value = null):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value

# Handle collision with a target
func on_hit(target):
	# Apply weapon effects
	if weapon:
		weapon.apply_effects(target, "hit")
