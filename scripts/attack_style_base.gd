# attack_style_base.gd (in res://scripts/)
class_name AttackStyle
extends Resource

# References
var weapon = null
var wielder = null

# Debug flag
const DEBUG = true

# Initialize the attack style with a weapon reference
func initialize(weapon_ref):
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		if DEBUG:
			print("Attack style initialized with weapon: ", weapon.get_weapon_name())
	else:
		push_error("Attack style initialized with null weapon reference")
	
	_init_style()

# Override in derived styles for custom initialization
func _init_style():
	# Override in derived styles
	pass

# Get the name of this attack style
func get_style_name() -> String:
	return "BaseAttackStyle"

# Execute the attack - core method that must be implemented by all styles
# Returns true if attack was successful, false otherwise
func execute_attack():
	print("Base attack style - override in derived classes")
	return false

# Called when attack execution is complete - useful for cleanup
func on_attack_end():
	if DEBUG:
		print(get_style_name() + ": Attack ended")
	pass

# Called when a projectile is created by this attack style
func _on_projectile_created(_projectile):
	if DEBUG:
		print(get_style_name() + ": Projectile created")
	pass

# Helper to get a parameter with a default value from weapon data
func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value

# Helper to get attack range as Vector2
func get_attack_range() -> Vector2:
	var range_param = get_param("attack_range", Vector2(50, 30))
	# Handle both Vector2 and numeric types
	if range_param is Vector2:
		return range_param
	else:
		return Vector2(float(range_param), float(range_param))

# Helper to create a timer for delayed operations (instead of using await)
# Helper to create a timer for delayed operations (instead of using await)
func create_timer(node, duration, callback_object, callback_method, callback_args = []):
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	node.add_child(timer)
	
	# Create the callback
	timer.timeout.connect(func():
		# Call the method with arguments if provided
		if callback_args.size() > 0:
			callback_object.callv(callback_method, callback_args)
		else:
			callback_object.call(callback_method)
		
		# Remove timer
		timer.queue_free()
	)
	
	timer.start()
	return timer
