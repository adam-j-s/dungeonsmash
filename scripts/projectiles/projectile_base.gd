# projectile_base.gd - Base class for all projectile types
class_name ProjectileBase
extends CharacterBody2D

# Debug flag
const DEBUG = true  # Set to true only when debugging

# Basic properties
var speed = 400.0
var direction = Vector2.RIGHT
var lifetime = 1.0
var timer = 0.0
var damage = 10
var knockback = 500
var effects = []
var hit_effect = ""
var wielder_ref = null
var weapon_id = ""

# Track hit targets
var hit_targets = []

# Behaviors attached to this projectile
var behaviors = []

# Called when the node enters the scene tree for the first time
func _ready():
	# Get wielder reference from metadata if not already set
	if !wielder_ref and has_meta("wielder"):
		wielder_ref = get_meta("wielder")
		
	# Store initial position for tracking
	set_meta("initial_position", global_position)
	
	# Get weapon ID from metadata
	if has_meta("weapon_id"):
		weapon_id = get_meta("weapon_id")
	elif has_meta("weapon") and get_meta("weapon").has_method("get_weapon_id"):
		weapon_id = get_meta("weapon").get_weapon_id()
		
	# Setup collision masks
	setup_collision_masks()

# Set up collision masks based on projectile type
func setup_collision_masks():
	# Default collision mask (world + enemy)
	var world_mask = 1
	var enemy_mask = 4 if wielder_ref and wielder_ref.name == "Player1" else 2
	
	# Default behavior - hit both world and enemies
	collision_mask = enemy_mask | world_mask

# Main process method - handles lifetime and delegates to specific implementations
func _process(delta):
	# Update lifetime
	timer += delta
	if timer >= lifetime:
		on_lifetime_end()
		return
	
		# ADD THIS CODE: Special handling for piercing projectiles passing through targets
	if get_meta("handling_own_movement", false):
		var move_delta = velocity * delta
		global_position += move_delta
		
		# Skip the rest of normal processing
		return
		
	# Allow behaviors to handle processing
	var handled_by_behavior = process_behaviors(delta)
	
	# If not handled by behaviors, use the specific movement implementation
	if !handled_by_behavior:
		# Use the new calculation method instead of _handle_movement
		_calculate_movement(delta)

# Physics process - handles actual movement and collisions
func _physics_process(delta):
	# Debug behavior processing
	if behaviors.size() > 0 and Engine.get_frames_drawn() % 30 == 0:
		print("Processing behaviors for projectile ", name, ": ", behaviors.size(), " behaviors")
		for behavior in behaviors:
			print("  - ", behavior.get_behavior_name())
	
	# Let behaviors handle physics if they can
	var handled_by_behavior = process_behaviors_physics(delta)
	
	# Only do default physics if no behavior handled it
	if !handled_by_behavior:
		# Move using physics system
		var collision_result = move_and_collide(velocity * delta)
		
		# Handle collisions
		if collision_result:
			_handle_collision(collision_result)

# New method - Calculate movement but only set velocity (don't move directly)
# New method - Calculate movement but only set velocity (don't move directly)
func _calculate_movement(delta):
	# Skip calculation if projectile is handling its own movement
	if get_meta("handling_own_movement", false):
		return
		
	# Default implementation - calculate velocity based on direction and speed
	if typeof(direction) == TYPE_VECTOR2:
		velocity = direction * speed
	else:
		# Check if we should preserve Y velocity component (for gravity effects)
		if get_meta("preserve_y_velocity", false) and "velocity" in self:
			var current_y = velocity.y
			velocity = Vector2(float(direction) * speed, current_y)
		else:
			velocity = Vector2(float(direction) * speed, 0.0)

# Virtual method - Original method kept for backward compatibility
# Child classes should override _calculate_movement instead
func _handle_movement(delta):
	# Default implementation - move in a straight line
	_calculate_movement(delta)
	return true  # Movement handled

# Virtual method - Override in child classes for specific collision handling
func _handle_collision(collision):
	var collider = collision.get_collider()
	
	# Check if this is a world object (not a player)
	var is_world = !collider.has_method("take_damage")
	
	# First notify behaviors about collision
	notify_behaviors_on_collision(collision)
	
	# Check if any behavior wants to cancel destruction
	var should_pierce = get_meta("cancel_destruction", false)
	
	if DEBUG:
		print("Collision detected, should_pierce=", should_pierce, ", is_world=", is_world)
	# Add this in the _handle_collision method in projectile_base.gd
	if DEBUG:
		print("COLLISION DEBUG: Collider name: ", collider.name)
		print("COLLISION DEBUG: Collider path: ", collider.get_path())
		print("COLLISION DEBUG: Collider class: ", collider.get_class())
	# Only proceed with default handling if no cancellation requested
	if !should_pierce:
		if is_world:
			# Default behavior for world collisions - destroy projectile
			destroy()
		elif collider != wielder_ref:
			# Enemy collision
			_handle_hit(collider)
		
func notify_behaviors_on_collision(collision):
	for behavior in behaviors:
		if behavior != null and behavior.has_method("on_projectile_collision"):
			behavior.on_projectile_collision(self, collision)

# Handle hit
func _handle_hit(target):
	# Skip if already hit or invalid target
	if target == null or target in hit_targets:
		return
		
	# Track this target as hit
	hit_targets.append(target)
	
	# Apply damage
	if target.has_method("take_damage"):
		# Calculate direction
		var hit_dir = Vector2.RIGHT
		if typeof(direction) == TYPE_VECTOR2:
			hit_dir = direction.normalized()
		else:
			hit_dir = Vector2(float(direction), 0).normalized()
		
		# CHANGE: Check piercing before applying damage to set knockback to 0
		var should_pierce = get_meta("cancel_destruction", false)
		if should_pierce:
			# Set knockback to 0 for piercing weapons
			knockback = 0
			
		# Apply the damage
		target.take_damage(damage, hit_dir, knockback)
	
	# Notify behaviors about hit
	notify_behaviors_on_hit(target)
	
	# Apply weapon effects if available
	if is_instance_valid(wielder_ref) and wielder_ref.has_node("Weapon"):
		var weapon_node = wielder_ref.get_node("Weapon")
		if weapon_node and weapon_node.has_method("apply_effects"):
			weapon_node.apply_effects(target, "hit")
	
	# Check if we should cancel destruction (for piercing)
	var should_pierce = get_meta("cancel_destruction", false)
	print("PROJECTILE DEBUG: should_pierce=" + str(should_pierce) + ", target=" + target.name)
	
	# Only destroy if not piercing
	if !should_pierce:
		print("PROJECTILE DEBUG: Destroying projectile")
		destroy()
	else:
		print("PROJECTILE DEBUG: Piercing through target")
		
		# IMPORTANT ADDITION: Move the projectile forward
		# This is the key part that will make it pass through
		if typeof(direction) == TYPE_VECTOR2:
			# Calculate sufficient distance to clear collision
			var escape_distance = direction.normalized() * 30
			global_position += escape_distance
		else:
			# Handle scalar direction
			var dir_value = 1 if direction > 0 else -1
			global_position.x += dir_value * 30
			
		if DEBUG:
			print("Piercing through target")
# Called when lifetime ends
func on_lifetime_end():
	# Default behavior - destroy when lifetime ends
	destroy()

# Cleanup method:
func cleanup_signals():
	# Get all signals this node has
	var signals = get_signal_list()
	
	# For each signal
	for sig in signals:
		var signal_name = sig["name"]
		
		# Get connections for this signal
		var connections = get_signal_connection_list(signal_name)
		
		# Disconnect each connection
		for conn in connections:
			if is_connected(signal_name, conn["callable"]):
				disconnect(signal_name, conn["callable"])
				
# Clean destruction with effects
func destroy():
	print("PROJECTILE DEBUG: destroy() called")
	# Clean up signals directly here instead of in a separate method
	cleanup_signals()
	# Notify behaviors about destruction
	notify_behaviors_on_destroyed()
	# Queue free after all effects are done
	queue_free()

# Initialize the projectile with configuration
func initialize(config):
	# Set basic properties - convert types explicitly
	speed = float(config.get("speed", 400.0))
	
	# Handle vector or float direction
	if typeof(config.get("direction")) == TYPE_VECTOR2:
		direction = config.get("direction")
	else:
		direction = float(config.get("direction", 1))
	
	lifetime = float(config.get("lifetime", 1.0))
	damage = int(config.get("damage", 10))
	knockback = float(config.get("knockback", 500))
	effects = config.get("effects", [])
	hit_effect = config.get("hit_effect", "")
	
	# Store weapon ID if provided
	if "weapon_id" in config:
		weapon_id = config["weapon_id"]
		set_meta("weapon_id", weapon_id)
	
	# Set initial velocity
	_calculate_movement(0) # Use new method to set velocity
	
	# Find behaviors for this projectile
	find_behaviors()
	
	return self  # Return self to allow method chaining

# Find and attach behaviors from the behavior manager
func find_behaviors():
	if weapon_id.is_empty():
		return
	
	# Try to find global behavior manager
	var behavior_manager = _find_behavior_manager()
	
	if behavior_manager:
		# Let the behavior manager apply behaviors to this projectile
		behavior_manager.apply_behaviors_to_projectile(self)
		
		if DEBUG:
			print("Found behavior manager, behaviors applied to projectile")

# Helper to find the behavior manager
func _find_behavior_manager():
	# Use a try/catch approach to avoid crashes
	if wielder_ref and is_instance_valid(wielder_ref):
		# First try the wielder's weapon
		if wielder_ref.has_node("Weapon/BehaviorManager"):
			return wielder_ref.get_node("Weapon/BehaviorManager")
	
	# Try the global scene if available
	if is_instance_valid(self) and is_inside_tree():
		var tree = get_tree()
		if tree:
			var scene = tree.current_scene
			if scene and scene.has_node("BehaviorManager"):
				return scene.get_node("BehaviorManager")
	
	# If we get here, no behavior manager was found
	if DEBUG:
		print("No behavior manager found for projectile")
	
	return null

# Delegate processing to behaviors
func process_behaviors(delta):
	var handled = false
	
	# Try directly attached behaviors first
	if behaviors.size() > 0:
		for behavior in behaviors:
			if behavior.has_method("on_projectile_process"):
				if behavior.on_projectile_process(self, delta):
					handled = true
					break
	
	return handled

# Delegate physics processing to behaviors
func process_behaviors_physics(delta):
	var handled = false
	
	# Try directly attached behaviors first
	if behaviors.size() > 0:
		for behavior in behaviors:
			if behavior.has_method("on_projectile_physics_process"):
				if behavior.on_projectile_physics_process(self, delta):
					handled = true
					break
	
	return handled

# Notify behaviors that projectile hit an enemy
func notify_behaviors_on_hit(target):
	for behavior in behaviors:
		if behavior != null and behavior.has_method("on_projectile_hit"):
			behavior.on_projectile_hit(self, target)

# Notify behaviors that projectile is being destroyed
func notify_behaviors_on_destroyed():
	for behavior in behaviors:
		if behavior.has_method("on_projectile_destroyed"):
			behavior.on_projectile_destroyed(self)

# Add a behavior to this projectile
func add_behavior(behavior):
	if !behavior in behaviors:
		behaviors.append(behavior)
		return true
	return false

# Clear all behaviors
func clear_behaviors():
	behaviors.clear()

# Check if this projectile has a specific behavior
func has_behavior(behavior_name):
	for behavior in behaviors:
		if behavior.has_method("get_behavior_name") and behavior.get_behavior_name() == behavior_name:
			return true
	return false

# Get a behavior by name
func get_behavior(behavior_name):
	for behavior in behaviors:
		if behavior.has_method("get_behavior_name") and behavior.get_behavior_name() == behavior_name:
			return behavior
	return null

# Utility method to check if a target has already been hit
func has_hit_target(target):
	return target in hit_targets

# Utility method to track hit targets for piercing
func add_hit_target(target):
	if !target in hit_targets:
		hit_targets.append(target)
