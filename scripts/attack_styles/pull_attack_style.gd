class_name PullAttackStyle
extends AttackStyle

var pull_range = Vector2(60, 40)
var pull_duration = 0.3
var pull_strength_multiplier = 0.5  # Pull attacks deal less damage but have utility
var damage_reduction = 0.7  # Pull attacks deal less damage but have utility
var aim_direction = Vector2.RIGHT  # Default right direction

func _init_style():
	# Initialize pull-specific properties from JSON structure
	
	# Get range from JSON or parameters
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			pull_range = Vector2(
				float(weapon.weapon_data.range.get("x", 60)),
				float(weapon.weapon_data.range.get("y", 40))
			)
		else:
			pull_range = get_param("attack_range", Vector2(60, 40))
	else:
		pull_range = get_param("attack_range", Vector2(60, 40))
	
	# Get pull duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "pull_duration" in weapon.weapon_data.stats:
			pull_duration = float(weapon.weapon_data.stats.pull_duration)
		else:
			pull_duration = float(get_param("pull_duration", 0.3))
	else:
		pull_duration = float(get_param("pull_duration", 0.3))
		
	# Get pull strength multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "pull_strength" in weapon.weapon_data.stats:
			pull_strength_multiplier = float(weapon.weapon_data.stats.pull_strength)
		else:
			pull_strength_multiplier = float(get_param("pull_strength", 0.5))
	else:
		pull_strength_multiplier = float(get_param("pull_strength", 0.5))
	
	# Get damage reduction from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "damage_reduction" in weapon.weapon_data.stats:
			damage_reduction = float(weapon.weapon_data.stats.damage_reduction)
		else:
			damage_reduction = float(get_param("damage_reduction", 0.7))
	else:
		damage_reduction = float(get_param("damage_reduction", 0.7))
	
	if DEBUG:
		print("Pull style initialized with range: ", pull_range)
	
	# Aim Direction
	if "aim_direction" in params:
		aim_direction = params["aim_direction"]
	
func get_style_name() -> String:
	return "PullAttackStyle"

# Execute attack with proper signal handling
func execute_attack():
	if DEBUG:
		print("Executing pull attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder:
		print("Missing wielder reference - cannot execute pull attack")
		return false
	
	# Creates a hitbox that pulls enemies toward the player
	var pull_hitbox = Area2D.new()
	pull_hitbox.name = "PullHitbox"
	
	# Add a larger collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = pull_range
	collision.shape = shape
	pull_hitbox.add_child(collision)
	
	# Twin Stick operator
	if "use_twin_stick_aiming" in wielder and wielder.use_twin_stick_aiming: 
		aim_direction = wielder.aim_direction
		if DEBUG:
			print("Updated dagger aim direction from twin stick: ", aim_direction)
	
	# Position in front of player
	var attack_direction = sign(aim_direction.x)
	pull_hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties using CollisionUtils if available
	if "CollisionUtils" in get_script() and get_script().CollisionUtils != null:
		get_script().CollisionUtils.setup_collision_mask(pull_hitbox, wielder, false)
	else:
		# Fallback to manual setup
		pull_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			pull_hitbox.collision_mask = 4  # Detect Player 2
		else:
			pull_hitbox.collision_mask = 2  # Detect Player 1
	
	# Add visual effect for the pull (a brief line indicating the pull)
	var pull_visual = Line2D.new()
	pull_visual.width = 5
	pull_visual.default_color = Color(0.8, 0.2, 0.8, 0.7)  # Purple for pull
	pull_visual.add_point(Vector2.ZERO)
	pull_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
	pull_hitbox.add_child(pull_visual)
	
	# Add particles for more visual impact
	create_pull_particles(pull_hitbox, attack_direction)
	
	# Store weapon and wielder references for hit callback
	pull_hitbox.set_meta("weapon", weapon)
	pull_hitbox.set_meta("wielder", wielder)
	
	# CRITICAL CHANGE: Connect the body_entered signal BEFORE adding to scene
	# This ensures the signal connection is maintained
	var hit_callable = func(body): _on_pull_hit_direct(body)
	pull_hitbox.set_meta("pull_hit_callable", hit_callable)
	pull_hitbox.body_entered.connect(hit_callable)
	
	# Add to wielder
	wielder.add_child(pull_hitbox)
	
	# Create a timer to remove hitbox after duration
	var timer = Timer.new()
	timer.wait_time = pull_duration
	timer.one_shot = true
	wielder.add_child(timer)
	
	# Connect timer directly without using callable/metadata
	timer.timeout.connect(func():
		# Remove hitbox when timer expires
		if is_instance_valid(pull_hitbox):
			# Disconnect signals safely
			if pull_hitbox.has_meta("pull_hit_callable"):
				var callable = pull_hitbox.get_meta("pull_hit_callable")
				if pull_hitbox.is_connected("body_entered", callable):
					pull_hitbox.disconnect("body_entered", callable)
			
			# Create fade out effect
			for child in pull_hitbox.get_children():
				if child is Line2D:
					var tween = child.create_tween()
					tween.tween_property(child, "modulate:a", 0.0, 0.1)
			
			# Queue free after brief delay
			pull_hitbox.queue_free()
		
		# Clean up timer as well
		if is_instance_valid(timer):
			timer.queue_free()
			
		# Notify when attack ends
		on_attack_end()
	)
	timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true
	
# New direct hit handler that doesn't rely on metadata
func _on_pull_hit_direct(body):
	print("Pull hit detected: ", body.name)
	
	# Skip if trying to pull self
	if !is_instance_valid(body) or body == wielder:
		return
	
	print("Processing pull hit: ", body.name)
	
	# Check for friendly fire
	var is_friendly = false
	if wielder and "player_number" in wielder and "player_number" in body:
		is_friendly = body.player_number == wielder.player_number
	
	# Get friendly fire setting from JSON flags
	var allows_friendly_fire = false
	if weapon and "weapon_data" in weapon:
		if "flags" in weapon.weapon_data:
			allows_friendly_fire = weapon.weapon_data.flags.get("friendly_fire", false)
		else:
			# Fallback to metadata for backward compatibility
			allows_friendly_fire = weapon.get_meta("friendly_fire", false)
	
	# Skip friendly hits if friendly fire is disabled
	if is_friendly and !allows_friendly_fire:
		if DEBUG:
			print("Friendly fire prevented in pull attack")
		return
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate pull direction (toward player)
		var pull_dir = (wielder.global_position - body.global_position).normalized()
		
		# Calculate reduced damage
		var effective_damage = int(weapon.calculate_damage() * damage_reduction)
		
		# Apply minimal damage with low knockback
		body.take_damage(effective_damage, pull_dir, 50)
		
		# Direct position manipulation for pulling
		if body is CharacterBody2D:
			# Calculate pull distance based on weapon knockback
			var pull_strength = 0.0
			if "weapon_data" in weapon:
				if "stats" in weapon.weapon_data and "knockback_force" in weapon.weapon_data.stats:
					pull_strength = float(weapon.weapon_data.stats.knockback_force)
				else:
					pull_strength = float(get_param("knockback_force", 300.0))
			else:
				pull_strength = float(get_param("knockback_force", 300.0))
			
			var pull_distance = pull_dir * pull_strength * pull_strength_multiplier
			
			# Create a visual trail effect for the pull
			create_pull_trail(body, wielder)
			
			# Apply direct position change
			body.global_position += pull_distance
			
			# Set velocity for smoother motion
			if "velocity" in body:
				body.velocity = pull_dir * pull_strength
			
			# Add stun effect
			create_stun_effect(body, 0.2)
		
		print(wielder.name + " pulls " + body.name + " with " + weapon.get_weapon_name())
		
		# Apply hit effects
		weapon.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Helper function to create a timer
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

# New function that properly handles signal disconnection
func remove_pull_hitbox_with_signals(hitbox):
	if hitbox and is_instance_valid(hitbox):
		# Disconnect signals safely
		if hitbox.has_meta("pull_hit_callable"):
			var callable = hitbox.get_meta("pull_hit_callable")
			if hitbox.is_connected("body_entered", callable):
				hitbox.disconnect("body_entered", callable)
		
		# Force-free any existing tweens
		for child in hitbox.get_children():
			if child is Line2D:
				if child.has_meta("active_tween") and is_instance_valid(child.get_meta("active_tween")):
					child.get_meta("active_tween").kill()
				
				# Create fade out effect
				var tween = child.create_tween()
				child.set_meta("active_tween", tween)
				tween.tween_property(child, "modulate:a", 0.0, 0.1)
		
		# Queue free immediately instead of using another timer
		# This prevents the visual from staying
		hitbox.queue_free()
	
	# Notify when attack ends
	on_attack_end()

# Keep the original function for backward compatibility
# But make it call our new function
func remove_pull_hitbox(hitbox):
	remove_pull_hitbox_with_signals(hitbox)

# Helper to remove a node
func queue_free_node(node):
	if node and is_instance_valid(node):
		node.queue_free()

# Create particle effects for pull visualization
func create_pull_particles(parent, direction):
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = pull_duration
	particles.explosiveness = 0.2
	particles.direction = Vector2(-direction, 0)
	particles.spread = 20
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 2.0
	particles.color = Color(0.8, 0.2, 0.8)  # Purple
	particles.position = Vector2(direction * pull_range.x, 0)
	
	parent.add_child(particles)
	particles.emitting = true

# Create a visual trail effect for the pull
func create_pull_trail(target, destination):
	# Create a trail of particles connecting the target to the destination
	var trail = Line2D.new()
	trail.default_color = Color(0.8, 0.2, 0.8, 0.5)  # Translucent purple
	trail.width = 3
	trail.add_point(target.global_position)
	trail.add_point(destination.global_position)
	
	# Add to scene
	target.get_tree().current_scene.add_child(trail)
	
	# Fade out
	var tween = trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	
	# Remove after effect completes
	create_timer(
		trail,
		0.2,
		self,
		"queue_free_node",
		[trail]
	)

# Create a brief stun effect on the target
func create_stun_effect(target, duration):
	# Visual indicator for stun
	var stun_indicator = Sprite2D.new()
	
	# Use a simple ColorRect if no texture
	var rect = ColorRect.new()
	rect.color = Color(1, 1, 0, 0.7)  # Yellow
	rect.size = Vector2(10, 10)
	rect.position = Vector2(-5, -20)  # Above head
	stun_indicator.add_child(rect)
	
	# Add to target
	target.add_child(stun_indicator)
	
	# Create animation
	var tween = stun_indicator.create_tween()
	tween.tween_property(stun_indicator, "rotation", 2 * PI, duration)
	
	# Remove after duration
	create_timer(
		target,
		duration,
		self,
		"queue_free_node",
		[stun_indicator]
	)
	
	# Apply stun effect on movement if possible
	if "velocity" in target:
		var original_velocity = target.velocity
		target.velocity = Vector2.ZERO
		
		# Restore movement after duration
		create_timer(
			target,
			duration,
			self,
			"restore_velocity",
			[target, original_velocity]
		)

# Restore velocity after stun
func restore_velocity(target, original_velocity):
	if target and is_instance_valid(target) and "velocity" in target:
		target.velocity = original_velocity * 0.5  # Reduced momentum after stun

# Notify behaviors about attack execution
func notify_behaviors_on_attack():
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_attack_executed(get_style_name())

# Notify behaviors about hit
func notify_behaviors_on_hit(target):
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_hit(target)

# Find a behavior manager to use
func find_behavior_manager():
	# First check if weapon has one
	if weapon and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	var scene = wielder.get_tree().current_scene
	if scene.has_node("BehaviorManager"):
		return scene.get_node("BehaviorManager")
		
	return null
