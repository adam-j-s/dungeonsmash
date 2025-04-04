# Base class for all weapon attack styles
class_name AttackStyle
extends Node

# Configuration
var weapon = null
var wielder = null
var params = {}
var DEBUG = true

# Initialize the style with weapon reference and parameters
func initialize(weapon_ref, parameters = {}):
	weapon = weapon_ref
	params = parameters
	
	if weapon:
		wielder = weapon.wielder
	
	_init_style()
	return self

# Virtual method for specialized initialization
func _init_style():
	pass

func get_param(param_name, default_value):
	# Check style parameters first
	if param_name in params:
		return params[param_name]
	
	# Check weapon data if available
	if weapon and "weapon_data" in weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	
	# Fall back to default
	return default_value

# Get style name
func get_style_name() -> String:
	return "AttackStyle"

# Execute the attack - override in child classes
func execute_attack():
	print("Base attack style - override in child classes")
	return false

# Helper function to create a timer - useful for attacks
func create_timer(parent_node, wait_time, target, method, binds = []):
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	parent_node.add_child(timer)
	
	# Connect the timeout signal
	if target and method:
		if binds.size() > 0:
			timer.timeout.connect(Callable(target, method).bind(binds))
		else:
			timer.timeout.connect(Callable(target, method))
	
	timer.start()
	return timer

# Notification when attack ends
func on_attack_end():
	# Check if weapon is still valid before accessing it
	if is_instance_valid(weapon) and weapon != null:
		# Notify behavior manager if available
		if weapon.has_node("BehaviorManager"):
			weapon.get_node("BehaviorManager").on_attack_end()
