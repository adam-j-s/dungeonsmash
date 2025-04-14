# Base class for all weapon attack styles - Enhanced for better direction and signal handling
class_name AttackStyle
extends Node

# Configuration
var weapon = null
var wielder = null
var params = {}
var DEBUG = true

# Attack configuration
var attack_duration = 0.2  # Visual duration only, no longer affects cooldown

# Direction handling
var aim_direction = Vector2.RIGHT  # Default direction

# Signal tracking for safe cleanup
var active_signals = []  # Track signal connections

# Initialize the style with weapon reference and parameters
func initialize(weapon_ref, parameters = {}):
	weapon = weapon_ref
	params = parameters
	
	if weapon:
		wielder = weapon.wielder
	
	# Get aim_direction from params if provided
	if "aim_direction" in params:
		aim_direction = params["aim_direction"]
	
	_init_style()
	return self

# Virtual method for specialized initialization
func _init_style():
	# Child classes should set their attack_duration here
	pass

# Get parameter with fallbacks
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

# Update aim direction from wielder - call this before each attack
func update_aim_direction():
	if wielder == null:
		return aim_direction
		
	# Use the wielder's centralized direction function if available
	if wielder.has_method("get_attack_direction_value"):
		aim_direction = wielder.get_attack_direction_value()
		if DEBUG:
			print("Using wielder's get_attack_direction_value(): ", aim_direction)
	# Support twin stick aiming
	elif "use_twin_stick_aiming" in wielder and wielder.use_twin_stick_aiming and "aim_direction" in wielder:
		aim_direction = wielder.aim_direction
		if DEBUG:
			print("Using twin stick aim_direction: ", aim_direction)
	
	return aim_direction

# Safe signal connection with tracking
func connect_signal_safe(source_node, signal_name, target_instance, method_name, binds=[]):
	if !is_instance_valid(source_node):
		print("Warning: Attempted to connect signal to invalid node")
		return null
		
	# Create callable
	var callable = Callable(target_instance, method_name)
	if binds.size() > 0:
		callable = callable.bind(binds)
	
	# Store signal info for cleanup
	var signal_info = {
		"source": source_node,
		"signal": signal_name,
		"callable": callable
	}
	
	# Connect if not already connected
	if !source_node.is_connected(signal_name, callable):
		source_node.connect(signal_name, callable)
		active_signals.append(signal_info)
	
	return callable

# Safe signal disconnection
func disconnect_signals():
	for signal_info in active_signals:
		var source = signal_info.source
		if is_instance_valid(source) and source.is_connected(signal_info.signal, signal_info.callable):
			source.disconnect(signal_info.signal, signal_info.callable)
	
	active_signals.clear()

# Execute the attack - override in child classes
# UPDATED: No longer handles cooldown, only visual effects and gameplay mechanics
func execute_attack():
	if DEBUG:
		print("Base attack style - override in child classes")
		
	# IMPORTANT: Cooldown is now handled by the weapon before this is called
	# This function only needs to handle the visual aspects and gameplay mechanics
	
	# Schedule cleanup based on attack_duration (visual only)
	create_timer(self, attack_duration, self, "on_attack_end")
	
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

# Enhanced cleanup hitbox with signal disconnection
func cleanup_hitbox_safe(hitbox, timer=null):
	# Disconnect signals first
	disconnect_signals()
	
	# Then proceed with normal cleanup
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	if timer != null and is_instance_valid(timer):
		timer.queue_free()
	
	# Notify when attack ends
	on_attack_end()

# Original cleanup method (kept for backward compatibility)
func cleanup_hitbox(hitbox, timer=null):
	# Remove hitbox when timer expires
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	if timer != null and is_instance_valid(timer):
		timer.queue_free()
	# Notify when attack ends
	on_attack_end()
