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

# Notification when attack ends - with frame synchronization
func on_attack_end():
	# Use call_deferred for frame synchronization
	call_deferred("_deferred_attack_end")

# Frame-synchronized attack end handling
func _deferred_attack_end():
	# Check if weapon is still valid before accessing it
	if is_instance_valid(weapon) and weapon != null:
		# Notify behavior manager if available
		if weapon.has_node("BehaviorManager"):
			weapon.get_node("BehaviorManager").on_attack_end()

# Helper for visual feedback on attack
func create_attack_flash(target, color=Color(1,1,1,0.3)):
	if !is_instance_valid(target):
		return
		
	var flash = ColorRect.new()
	flash.color = color
	flash.size = Vector2(50, 50)
	flash.position = Vector2(-25, -25)
	target.add_child(flash)
	
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)
	
	return flash  # Return in case caller wants to modify further

# Helper for visual feedback on hit
func create_impact_flash(target, color=Color(1,1,1,0.3)):
	if !is_instance_valid(target):
		return
		
	var flash = ColorRect.new()
	flash.color = color
	flash.size = Vector2(40, 40)
	flash.position = Vector2(-20, -20)
	target.add_child(flash)
	
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)
	
	return flash  # Return in case caller wants to modify further

# Helper for safely cleaning up hitboxes with frame sync
func cleanup_hitbox(hitbox, timer=null):
	# Remove hitbox when timer expires
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	if timer != null and is_instance_valid(timer):
		timer.queue_free()
	# Notify when attack ends
	on_attack_end()
