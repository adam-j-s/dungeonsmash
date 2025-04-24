# Base class for all weapon attack styles - Enhanced for better direction, signal handling, and collision utilities
class_name AttackStyle
extends Node

# Configuration
var weapon = null
var wielder = null
var params = {}
const DEBUG = true

# Import CollisionUtils at top level
const CollisionUtils = preload("res://scripts/collision_utils.gd")

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
		callable = callable.bindv(binds) # Changed bind to bindv
	
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

# NEW: Helper method for setting up hitbox collisions
func setup_hitbox_collisions(hitbox, include_world=false):
	# Use CollisionUtils if available
	if CollisionUtils != null:
		return CollisionUtils.setup_collision_mask(hitbox, wielder, include_world)
	else:
		# Fallback to manual setup with all layers covered
		hitbox.collision_layer = 0
		var mask = 0
		
		# Determine which layers to target based on wielder
		if wielder:
			# Check if wielder is an enemy
			var is_enemy = wielder.has_method("get_class") and wielder.get_class() == "WispEnemy"
			
			if is_enemy:
				# Enemies target both player layers
				mask = mask | 2 | 4  # PLAYER1_LAYER | PLAYER2_LAYER
			elif wielder.name == "Player1":
				# Player1 targets Player2 and enemies
				mask = mask | 4 | 8  # PLAYER2_LAYER | ENEMY_LAYER
			else:
				# Player2 targets Player1 and enemies
				mask = mask | 2 | 8  # PLAYER1_LAYER | ENEMY_LAYER
		
		# Include world layer if requested
		if include_world:
			mask = mask | 1  # WORLD_LAYER
			
		hitbox.collision_mask = mask
		return mask

# Helper to create a standard attack hitbox 
func create_attack_hitbox(hitbox_name, shape_size, include_world=false):
	var hitbox = Area2D.new()
	hitbox.name = hitbox_name
	
	# Add to standard tracking group
	hitbox.add_to_group("active_attack_hitboxes")
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = shape_size
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Set collision properties using our unified method
	setup_hitbox_collisions(hitbox, include_world)
	
	return hitbox

# Helper to create an attack timer that automatically cleans up the hitbox
func create_attack_timer(duration, hitbox):
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	
	# Use direct lambda to ensure cleanup happens
	timer.timeout.connect(func():
		if DEBUG:
			print("Attack timer expired via lambda, cleaning up")
		cleanup_attack(hitbox, timer)
	)
	
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

# MAIN STANDARDIZED CLEANUP METHOD - All styles should use this
func cleanup_attack(hitbox, timer=null):
	if DEBUG:
		print("CLEANUP ATTACK: Executing standardized cleanup")
	
	# 1. Disconnect all tracked signals
	disconnect_signals()
	
	# 2. Remove hitbox from all groups
	if is_instance_valid(hitbox):
		if hitbox.has_method("get_groups"):
			for group in hitbox.get_groups():
				if DEBUG:
					print("CLEANUP: Removing hitbox from group: ", group)
				hitbox.remove_from_group(group)
		
		# 3. Free the hitbox
		hitbox.queue_free()
	
	# 4. Free the timer
	if timer != null and is_instance_valid(timer):
		timer.queue_free()
	
	# 5. Notify that attack has ended
	call_deferred("_deferred_attack_end")
	
	if DEBUG:
		print("CLEANUP ATTACK: Completed")

# Helper to clean up any existing hitboxes (for use at start of execute_attack)
func cleanup_existing_hitboxes(hitbox_name):
	# First, check if wielder is valid
	if !is_instance_valid(wielder):
		return
		
	# 1. Clean up hitboxes that are direct children of the wielder
	for child in wielder.get_children():
		if is_instance_valid(child) and child.name == hitbox_name:
			if DEBUG:
				print("Found existing ", hitbox_name, " on wielder, removing it")
			cleanup_attack(child, null)
	
	# 2. Clean up any hitboxes in the scene that are part of groups
	if is_instance_valid(wielder) and is_instance_valid(wielder.get_tree()):
		var scene = wielder.get_tree().current_scene
		if is_instance_valid(scene):
			# Find all active hitboxes
			var nodes = wielder.get_tree().get_nodes_in_group("active_attack_hitboxes")
			for node in nodes:
				if is_instance_valid(node) and node.name == hitbox_name:
					if DEBUG:
						print("Cleaning up hitbox from active_attack_hitboxes group")
					cleanup_attack(node, null)
			
			# Also search the entire scene for any hitboxes by name that might have been missed
			for node in scene.get_children():
				if is_instance_valid(node) and node.name == hitbox_name:
					if DEBUG:
						print("Found orphaned ", hitbox_name, " in scene, removing it")
					cleanup_attack(node, null)

# Standard timer timeout handler - all attack styles should use this
func _on_attack_timer_timeout(hitbox, timer):
	if DEBUG:
		print("Standard attack timer timeout, cleaning up")
	cleanup_attack(hitbox, timer)

# FOR BACKWARD COMPATIBILITY - use cleanup_attack instead for new code
func cleanup_hitbox_safe(hitbox, timer=null):
	if DEBUG:
		print("WARNING: Using deprecated cleanup_hitbox_safe - use cleanup_attack instead")
	cleanup_attack(hitbox, timer)

# FOR BACKWARD COMPATIBILITY - use cleanup_attack instead for new code
func cleanup_hitbox(hitbox, timer=null):
	if DEBUG:
		print("WARNING: Using deprecated cleanup_hitbox - use cleanup_attack instead")
	cleanup_attack(hitbox, timer)

# FOR BACKWARD COMPATIBILITY - use cleanup_attack instead for new code
func enhanced_cleanup_hitbox(hitbox, timer=null):
	if DEBUG:
		print("WARNING: Using deprecated enhanced_cleanup_hitbox - use cleanup_attack instead")
	cleanup_attack(hitbox, timer)
