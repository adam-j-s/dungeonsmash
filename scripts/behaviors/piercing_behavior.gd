# Piercing Behavior - Allows projectiles to pass through multiple targets - JSON compatible
class_name PiercingBehavior
extends BehaviorBase

var piercing_count = 1  # How many targets to pierce through
var damage_decay_factor = 0.8  # Damage decreases by 20% for each pierce
var push_distance = 15.0  # Distance to push projectile after hit
var trail_effect = true  # Whether to leave a visual trail

func _init_behavior():
	# Enhanced parameter handling for JSON
	
	# Try to get parameters from JSON structure first
	if "params" in params:
		# Extract from nested params structure if present
		var behavior_params = params.get("params", {})
		
		# Get piercing count
		if "piercing" in behavior_params:
			piercing_count = int(behavior_params.piercing)
		else:
			piercing_count = int(get_param("piercing", 1))
		
		# Get damage decay factor
		if "damage_decay_factor" in behavior_params:
			damage_decay_factor = float(behavior_params.damage_decay_factor)
		else:
			damage_decay_factor = float(get_param("damage_decay_factor", 0.8))
			
		# Get push distance
		if "push_distance" in behavior_params:
			push_distance = float(behavior_params.push_distance)
		else:
			push_distance = float(get_param("push_distance", 15.0))
			
		# Get trail effect setting
		if "trail_effect" in behavior_params:
			trail_effect = bool(behavior_params.trail_effect)
	else:
		# Fallback to flat parameters
		piercing_count = int(get_param("piercing", 1))
		damage_decay_factor = float(get_param("damage_decay_factor", 0.8))
		push_distance = float(get_param("push_distance", 15.0))
	
	# Check weapon data for piercing settings
	if weapon and "weapon_data" in weapon:
		var weapon_data = weapon.weapon_data
		
		# Check for direct piercing property
		if "piercing" in weapon_data:
			piercing_count = int(weapon_data.piercing)
		
		# Check for specific settings in behaviors
		if "behaviors" in weapon_data and typeof(weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY:
					# Check if this is a piercing behavior
					var behavior_type = behavior.get("type", "")
					if behavior_type == "piercing":
						# Extract parameters from this behavior
						var behavior_params = behavior.get("params", {})
						
						# Get piercing count if specified
						if "piercing" in behavior_params:
							piercing_count = int(behavior_params.piercing)
	
	# Ensure reasonable values
	piercing_count = max(1, piercing_count)  # Minimum of 1 pierce
	damage_decay_factor = clamp(damage_decay_factor, 0.5, 1.0)  # Reasonable decay range
	push_distance = clamp(push_distance, 5.0, 30.0)  # Reasonable push range
	
	if DEBUG:
		print("Initialized piercing behavior with count: ", piercing_count)
		print("Damage decay factor: ", damage_decay_factor)
		print("Push distance: ", push_distance)

func get_behavior_name() -> String:
	return "PiercingBehavior"

func on_projectile_created(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Set piercing properties on the projectile
	projectile.set_meta("piercing", piercing_count)
	projectile.set_meta("original_damage", projectile.damage)
	projectile.set_meta("hit_count", 0)
	projectile.set_meta("cancel_destruction", false)
	projectile.set_meta("push_distance", push_distance)
	
	# Apply piercing visual style
	apply_piercing_visual(projectile)
	
	if DEBUG:
		print("Applied piercing behavior to projectile with count: ", piercing_count)

# Apply visual style to piercing projectile
func apply_piercing_visual(projectile):
	# Validate projectile
	if !is_instance_valid(projectile):
		return
	
	# Add blue tint to indicate piercing
	projectile.modulate = Color(0.3, 0.5, 1.0)
	
	# Add a trail effect if enabled
	if trail_effect:
		create_trail_effect(projectile)

# Create a simple trail effect for piercing projectiles
func create_trail_effect(projectile):
	# Create a CPUParticles2D for the trail
	var particles = CPUParticles2D.new()
	particles.name = "PiercingTrail"
	particles.amount = 10
	particles.lifetime = 0.4
	particles.local_coords = false  # Use global coordinates
	particles.emitting = true
	particles.one_shot = false
	
	# Set particle properties
	particles.direction = Vector2(0, 0)
	particles.spread = 10
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 0
	particles.initial_velocity_max = 0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	
	# Make particles fade out
	var gradient = Gradient.new()
	gradient.colors = [Color(0.3, 0.5, 1.0, 0.5), Color(0.3, 0.5, 1.0, 0.0)]
	particles.color_ramp = gradient
	
	# Add to projectile
	projectile.add_child(particles)

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
	
	# Add hit flash effect for visual feedback
	create_pierce_flash(target, hit_count)
	
	# If we have piercing left, prevent destruction
	if remaining_pierces > 0:
		# Decrement piercing counter
		remaining_pierces -= 1
		projectile.set_meta("piercing", remaining_pierces)
		
		# Set flag to prevent destruction
		projectile.set_meta("cancel_destruction", true)
		
		if DEBUG:
			print("PIERCE DEBUG: Setting cancel_destruction=true, remaining=", remaining_pierces)
		
		# Get the configured push distance
		var current_push_distance = projectile.get_meta("push_distance", push_distance)
		
		# IMPROVED SOLUTION: Push forward slightly
		if typeof(projectile.direction) == TYPE_VECTOR2:
			var push_vector = projectile.direction.normalized() * current_push_distance
			projectile.global_position += push_vector
		else:
			var dir_value = 1 if projectile.direction > 0 else -1
			projectile.global_position.x += dir_value * current_push_distance
		
		if DEBUG:
			print("Moved projectile slightly forward to pass through target")
	else:
		# Allow destruction after last pierce
		projectile.set_meta("cancel_destruction", false)
		projectile.knockback = original_knockback  # Restore for final hit
		
		if DEBUG:
			print("PIERCE DEBUG: Setting cancel_destruction=false")
			print("No more pierces, allowing destruction")

# Create a flash effect on the target when pierced
func create_pierce_flash(target, hit_count):
	# Create a flash at hit position
	var flash = ColorRect.new()
	
	# Color changes with each hit
	var intensity = 1.0 - (hit_count * 0.15)  # Gets dimmer with more hits
	flash.color = Color(0.3, 0.5, 1.0, intensity)  # Blue flash
	
	# Size slightly larger than target
	flash.size = Vector2(30, 30)
	flash.position = Vector2(-15, -15)  # Center
	
	# Add to target
	target.add_child(flash)
	
	# Create fade effect
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	
	# Remove after effect completes
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.one_shot = true
	flash.add_child(timer)
	
	# Safely remove when done
	var cleanup_callable = func():
		if is_instance_valid(flash):
			flash.queue_free()
	
	timer.timeout.connect(cleanup_callable)
	timer.start()
