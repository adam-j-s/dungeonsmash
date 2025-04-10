# Creates area-of-effect attacks around the wielder
class_name AreaAttackStyle
extends AttackStyle

var attack_radius = 25.0
var damage_multiplier = 1.2  # Area attacks deal 20% bonus damage
var effect_color = Color(0.9, 0.3, 0.1, 0.5)  # Orange for area attacks
# Load friendly fire utility
const CollisionUtils = preload("res://scripts/collision_utils.gd")

# Get attack range from parameters or default
func get_attack_range():
	var range_param = get_param("attack_range", 50)
	
	# If it's already a Vector2, return it directly
	if range_param is Vector2:
		return range_param
	
	# If it's a scalar value, convert to Vector2
	if typeof(range_param) == TYPE_INT or typeof(range_param) == TYPE_FLOAT:
		return Vector2(float(range_param), float(range_param))
	
	# Default fallback
	return Vector2(50, 50)
func _init_style():
	# Initialize area-specific properties
	var attack_range = get_attack_range()
	if attack_range is Vector2:
		attack_radius = attack_range.x / 2  # Use X component as radius
	else:
		attack_radius = float(get_param("attack_radius", 25.0))
	
	attack_duration = float(get_param("attack_duration", 0.3))
	damage_multiplier = float(get_param("damage_multiplier", 1.2))
	
	if DEBUG:
		print("Area style initialized with radius: ", attack_radius)

func get_style_name() -> String:
	return "AreaAttackStyle"

func execute_attack():
	print("Executing area attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder:
		print("Missing wielder reference")
		return false
	
	# Create a circular hitbox for area damage
	var area_hitbox = Area2D.new()
	area_hitbox.name = "AreaHitbox"
	
	# Add circular collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_radius
	collision.shape = shape
	area_hitbox.add_child(collision)
	
	# Position around player
	area_hitbox.position = Vector2.ZERO  # Centered on player
	
	# Use utility to set up collision mask
	CollisionUtils.setup_collision_mask(area_hitbox, wielder, false)
	
	# Store weapon reference for use in hit callback
	area_hitbox.set_meta("weapon", weapon)
	area_hitbox.set_meta("wielder", wielder)
	
	# Create and store a callable for the hit signal
	var hit_callable = func(body): _on_area_hit(body)
	area_hitbox.set_meta("hit_callable", hit_callable)
	
	# Connect hit signal using the stored callable
	area_hitbox.body_entered.connect(hit_callable)
	
	# Add visual effect (circle expanding outward)
	var circle = ColorRect.new()
	circle.color = effect_color
	var size = shape.radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	circle.scale = Vector2(0.1, 0.1)  # Start small
	area_hitbox.add_child(circle)
	
	# Add to wielder FIRST
	wielder.add_child(area_hitbox)
	
	# NOW create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), attack_duration * 0.6)
	
	# Create particle effect for more visual impact
	create_area_particles(area_hitbox, shape.radius)
	
	# Create a timer to remove the hitbox after attack duration
	var timer = Timer.new()
	timer.wait_time = attack_duration
	timer.one_shot = true
	wielder.add_child(timer)
	
	# Create a cleanup function
	var cleanup_func = func():
		if area_hitbox and is_instance_valid(area_hitbox):
			# Disconnect signal before destroying
			if area_hitbox.has_meta("hit_callable"):
				var callable = area_hitbox.get_meta("hit_callable")
				if area_hitbox.is_connected("body_entered", callable):
					area_hitbox.disconnect("body_entered", callable)
					
			# Create fade-out effect
			for child in area_hitbox.get_children():
				if child is ColorRect:
					var fade_tween = child.create_tween()
					fade_tween.tween_property(child, "modulate:a", 0.0, 0.1)
			
			# Remove after brief delay
			await wielder.get_tree().create_timer(0.1).timeout
			if area_hitbox and is_instance_valid(area_hitbox):
				area_hitbox.queue_free()
		
		# Clean up timer
		timer.queue_free()
		
		# Notify attack end
		on_attack_end()
	
	# Connect timer to cleanup function
	timer.timeout.connect(cleanup_func)
	timer.start()
	
	return true
	
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

# Remove the area hitbox when attack completes
func remove_area_hitbox(hitbox):
	if hitbox and is_instance_valid(hitbox):
		# Create fade out effect
		var circle = null
		for child in hitbox.get_children():
			if child is ColorRect:
				circle = child
				break
		
		if circle:
			var tween = circle.create_tween()
			tween.tween_property(circle, "modulate:a", 0.0, 0.1)
		
		# Remove after brief delay for visual fade-out
		create_timer(
			hitbox.get_parent(),
			0.1,
			self,
			"queue_free_node",
			[hitbox]
		)
	
	# Notify when attack ends
	on_attack_end()

# Helper to remove a node
func queue_free_node(node):
	if node and is_instance_valid(node):
		node.queue_free()

# Create particle effects for more visual impact
# Create particle effects for more visual impact
func create_area_particles(parent, radius):
	# Use CPUParticles2D for particles
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 20
	particles.lifetime = attack_duration
	
	# Fix for the EMISSION_SHAPE_CIRCLE error
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.8
	
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 3.0
	particles.color = effect_color
	particles.color_ramp = create_color_ramp()
	
	parent.add_child(particles)

# Create a color ramp for particles
func create_color_ramp():
	var gradient = Gradient.new()
	gradient.colors = [
		effect_color,
		Color(effect_color.r, effect_color.g, effect_color.b, 0)
	]
	gradient.offsets = [0, 1]
	return gradient

# Handle area attack hits
func _on_area_hit(body):
	# Get weapon and wielder references from metadata
	var area_hitbox = body.get_parent()
	var weapon_ref = null
	var wielder_ref = null
	
	# Safely get metadata
	if area_hitbox.has_meta("weapon"):
		weapon_ref = area_hitbox.get_meta("weapon")
			
	if area_hitbox.has_meta("wielder"):
		wielder_ref = area_hitbox.get_meta("wielder")
		
	if !weapon_ref or !wielder_ref:
		return  # Skip if missing references
	
	# Check for self-damage
	var is_self = body == wielder_ref
	if is_self:
		# If it's self, check if self-damage is allowed
		var allow_self_damage = weapon_ref.get_meta("allow_self_damage", false)
		if !allow_self_damage:
			return  # Skip self-damage if not allowed
	
	# Check for friendly fire (for non-self targets)
	var is_friendly = false
	if !is_self and wielder_ref and "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	
	# Get friendly fire setting
	var allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false)
	
	# Skip friendly hits if friendly fire is disabled
	if is_friendly and !allows_friendly_fire:
		if DEBUG:
			print("Friendly fire prevented in area attack")
		return
	
	print("Area hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction (away from player)
		var hit_dir = (body.global_position - wielder_ref.global_position).normalized()
		
		# Calculate damage with area damage bonus
		var effective_damage = int(weapon_ref.calculate_damage() * damage_multiplier)
		
		# Apply self-damage reduction if it's self-damage
		if is_self:
			effective_damage = int(effective_damage * 0.5)  # 50% damage to self
		
		# Apply damage and knockback
		body.take_damage(
			effective_damage, 
			hit_dir, 
			float(get_param("knockback_force", 300.0))
		)
		
		print(wielder_ref.name + " hits " + body.name + 
			  " with area attack from " + weapon_ref.get_weapon_name())
		
		# Apply hit effects
		if weapon_ref:
			weapon_ref.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)
		

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
