# Simple bounce behavior for projectiles (direct reverse with damage)
class_name BounceBehavior
extends BehaviorBase

var remaining_bounces = 0
var damping_factor = 0.8  # Energy lost on each bounce
var bounce_cooldown = 0.0  # Cooldown to prevent multiple bounces

func _init_behavior():
	# Get parameters with improved JSON structure handling
	var bounce_param = get_param("bounce_count", "3")
	var damping_param = get_param("damping_factor", "0.8")
	
	# Parse bounce_count with type handling
	if typeof(bounce_param) == TYPE_DICTIONARY and bounce_param.has("value"):
		# Handle nested dictionary format
		remaining_bounces = int(bounce_param.value)
	elif typeof(bounce_param) == TYPE_INT:
		# Direct integer
		remaining_bounces = bounce_param
	elif typeof(bounce_param) == TYPE_STRING:
		# String that needs conversion
		if "=" in bounce_param:
			# Handle legacy param format like "bounce_count=3"
			var parts = bounce_param.split("=")
			if parts.size() > 1:
				remaining_bounces = int(parts[1].strip_edges())
		else:
			# Simple string value
			remaining_bounces = int(bounce_param)
	else:
		# Default fallback
		remaining_bounces = 3
	
	# Parse damping_factor with type handling
	if typeof(damping_param) == TYPE_DICTIONARY and damping_param.has("value"):
		damping_factor = float(damping_param.value)
	elif typeof(damping_param) == TYPE_FLOAT:
		damping_factor = damping_param
	elif typeof(damping_param) == TYPE_STRING:
		if "=" in damping_param:
			var parts = damping_param.split("=")
			if parts.size() > 1:
				damping_factor = float(parts[1].strip_edges())
		else:
			damping_factor = float(damping_param)
	else:
		# Default fallback
		damping_factor = 0.8
	
	# Check for parameters in JSON behaviors array
	if weapon and "weapon_data" in weapon:
		if "behaviors" in weapon.weapon_data and typeof(weapon.weapon_data.behaviors) == TYPE_ARRAY:
			for behavior in weapon.weapon_data.behaviors:
				if typeof(behavior) == TYPE_DICTIONARY and behavior.has("type") and behavior.type == "bounce":
					if "params" in behavior and typeof(behavior.params) == TYPE_DICTIONARY:
						# Override with specific params from the behavior entry
						if "bounce_count" in behavior.params:
							remaining_bounces = int(behavior.params.bounce_count)
						if "damping_factor" in behavior.params:
							damping_factor = float(behavior.params.damping_factor)
	
	if DEBUG:
		print("Initialized bounce behavior with bounce_count: ", remaining_bounces)
		print("damping_factor: ", damping_factor)

func get_behavior_name() -> String:
	return "BounceBehavior"

func on_projectile_created(projectile):
	# Reset remaining bounces for each new projectile
	remaining_bounces = int(get_param("bounce_count", 3))
	bounce_cooldown = 0.0  # Reset cooldown
	
	# Set properties on the projectile
	projectile.set_meta("bounce_count", remaining_bounces)
	
	if DEBUG:
		print("Bounce behavior applied to projectile with bounce_count: ", remaining_bounces)

# Update cooldown in process
func on_projectile_process(projectile, delta):
	# Update cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown -= delta
		if bounce_cooldown < 0.0:
			bounce_cooldown = 0.0
	
	# Never take over movement
	return false

# Handle projectile collision
func on_projectile_collision(projectile, collision):
	# Skip if in cooldown
	if bounce_cooldown > 0.0:
		print("In bounce cooldown, skipping collision handling")
		return false
	
	# Get collider
	var collider = collision.get_collider()
	
	# Only bounce off walls, not characters
	if !collider.has_method("take_damage"):
		# If we have bounces remaining, bounce
		if remaining_bounces > 0:
			print("Bounce behavior handling collision with wall, remaining bounces: ", remaining_bounces)
			
			# Tell the projectile not to destroy itself
			projectile.set_meta("cancel_destruction", true)
			
			# Set cooldown to prevent multiple bounces in rapid succession
			bounce_cooldown = 0.15
			
			# PERFECTLY REVERSE DIRECTION: Exact opposite with no adjustments
			if typeof(projectile.direction) == TYPE_VECTOR2:
				# Simply negate the direction components exactly
				projectile.direction.x = -projectile.direction.x
				projectile.direction.y = -projectile.direction.y
				
				# Update velocity to exactly match the reversed direction
				projectile.velocity.x = projectile.direction.x * projectile.speed * damping_factor
				projectile.velocity.y = projectile.direction.y * projectile.speed * damping_factor
			else:
				# For scalar direction, just invert it
				projectile.direction = -projectile.direction
				# Update velocity
				projectile.velocity = Vector2(projectile.direction * projectile.speed * damping_factor, 0)
			
			# CAREFUL REPOSITIONING: Move just enough to prevent getting stuck
			projectile.global_position -= projectile.direction.normalized() * 5
			
			# CRITICAL: Clear hit targets to allow hitting again after bounce
			if "hit_targets" in projectile:
				projectile.hit_targets.clear()
				print("Cleared hit targets array - projectile can damage targets again!")
			
			# Decrement bounce counter
			remaining_bounces -= 1
			
			# Visual feedback
			projectile.modulate = Color(2.0, 2.0, 2.0)  # Bright flash
			
			# Create timer to restore normal color
			var timer = Timer.new()
			timer.wait_time = 0.1
			timer.one_shot = true
			projectile.add_child(timer)
			timer.timeout.connect(func():
				projectile.modulate = Color(0.2, 1.0, 0.4)  # Green color
				timer.queue_free()
			)
			timer.start()
			
			print("Projectile bounced! New direction: ", projectile.direction, " velocity: ", projectile.velocity)
			return true
		else:
			# No bounces remaining, allow projectile to be destroyed
			print("No bounces remaining, allowing destruction")
			projectile.set_meta("cancel_destruction", false)
			return false
	else: 
		# This is a collision with a character
		# Make sure we allow destruction so damage is applied
		projectile.set_meta("cancel_destruction", false)
	
	# Don't handle character collisions directly
	return false
