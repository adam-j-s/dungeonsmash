# Creates area-of-effect attacks around the wielder - Enhanced for safety
class_name AreaAttackStyle
extends AttackStyle

var attack_radius = 25.0
var damage_multiplier = 1.2  # Area attacks deal 20% bonus damage
var effect_color = Color(0.9, 0.3, 0.1, 0.5)  # Orange for area attacks


# Get attack range from parameters or default
func get_attack_range():
	# Check for range in JSON structure first
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			return Vector2(
				float(weapon.weapon_data.range.get("x", 50)),
				float(weapon.weapon_data.range.get("y", 30))
			)
	
	# Fallback to param
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
	
	# Get duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "attack_duration" in weapon.weapon_data.stats:
			attack_duration = float(weapon.weapon_data.stats.attack_duration)
		else:
			attack_duration = float(get_param("attack_duration", 0.3))
	else:
		attack_duration = float(get_param("attack_duration", 0.3))
	
	# Get damage multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "damage_multiplier" in weapon.weapon_data.stats:
			damage_multiplier = float(weapon.weapon_data.stats.damage_multiplier)
		else:
			damage_multiplier = float(get_param("damage_multiplier", 1.2))
	else:
		damage_multiplier = float(get_param("damage_multiplier", 1.2))
	
	if DEBUG:
		print("Area style initialized with radius: ", attack_radius)

func get_style_name() -> String:
	return "AreaAttackStyle"

func execute_attack():
	
	if DEBUG:
		print("Executing area attack with weapon: ", weapon.get_weapon_name() if is_instance_valid(weapon) else "Invalid weapon")
	
	if !is_instance_valid(wielder) or !is_instance_valid(weapon):
		print("Missing wielder or weapon reference - cannot execute area attack")
		return false
	
	# Use the standard cleanup method with the hitbox name
	cleanup_existing_hitboxes("AreaHitbox")
	
	# Update aim direction using our enhanced method
	update_aim_direction()
	
	# Create a circular hitbox for area damage
	var area_hitbox = Area2D.new()
	area_hitbox.name = "AreaHitbox"
	
	# Add to groups for better tracking
	area_hitbox.add_to_group("active_attack_hitboxes")
	area_hitbox.add_to_group("area_attack_hitboxes")
	
	# Add circular collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_radius
	collision.shape = shape
	area_hitbox.add_child(collision)
	
	# Position around player
	area_hitbox.position = Vector2.ZERO  # Centered on player
	
	# Store weapon and wielder in hitbox for hit callback
	area_hitbox.set_meta("weapon", weapon)
	area_hitbox.set_meta("wielder", wielder)
	
	# Use safe signal connection
	connect_signal_safe(area_hitbox, "body_entered", self, "_on_area_hit")
	
	# Set up collision using base class method
	setup_hitbox_collisions(area_hitbox, false)  # false = don't include world
	
	# Add visual effect (circle expanding outward)
	var circle = ColorRect.new()
	circle.color = effect_color
	var size = shape.radius * 2
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center the rect
	circle.scale = Vector2(0.1, 0.1)  # Start small
	area_hitbox.add_child(circle)
	
	# Add to wielder
	wielder.add_child(area_hitbox)
	
	# Create the tween after adding to scene
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), attack_duration * 0.6)
	
	# Create particle effect for more visual impact
	create_area_particles(area_hitbox, shape.radius)
	
	# Create a timer for cleanup
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = attack_duration
	wielder.add_child(timer)
	
	# Connect timer using direct lambda for reliable cleanup
	timer.timeout.connect(func():
		if DEBUG:
			print("Area attack timer lambda triggered")
		cleanup_attack(area_hitbox, timer)
	)
	timer.start()
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true
	
# New handler for attack timer - kept for backward compatibility
func _on_attack_timer_timeout(hitbox, timer):
	if DEBUG:
		print("Area attack timer timeout triggered")
	cleanup_attack(hitbox, timer)
	
# Handle area attack hits - enhanced for safety
func _on_area_hit(body):
	# Safety checks first
	if !is_instance_valid(body):
		return
	
	# Get hitbox reference using a more robust method
	var hitbox = null
	
	# Method 1: Check direct parent lookup
	if is_instance_valid(body.get_parent()):
		hitbox = body.get_parent().get_node_or_null("AreaHitbox")
	
	# Method 2: If not found, check through wielder's children
	if !is_instance_valid(hitbox) and is_instance_valid(wielder):
		for child in wielder.get_children():
			if is_instance_valid(child) and child.name == "AreaHitbox":
				hitbox = child
				break
	
	# Method 3: Check if body might have stored the hitbox reference
	if !is_instance_valid(hitbox) and body.has_meta("source_hitbox"):
		hitbox = body.get_meta("source_hitbox")
	
	# Method 4: Last resort - find any AreaHitbox in the scene
	if !is_instance_valid(hitbox) and is_instance_valid(wielder) and wielder.get_tree():
		var potential_hitboxes = wielder.get_tree().get_nodes_in_group("area_attack_hitboxes")
		if potential_hitboxes.size() > 0:
			hitbox = potential_hitboxes[0]
	
	# Exit if no valid hitbox found after all attempts
	if !is_instance_valid(hitbox):
		return
	
	# Get metadata from hitbox with safe checks
	var weapon_ref = null
	var wielder_ref = null
	
	if hitbox.has_meta("weapon"):
		weapon_ref = hitbox.get_meta("weapon")
	
	if hitbox.has_meta("wielder"):
		wielder_ref = hitbox.get_meta("wielder")
	
	if !is_instance_valid(weapon_ref) or !is_instance_valid(wielder_ref):
		return  # Skip if missing references
	
	# Skip self damage
	if body == wielder_ref:
		return
	
	# Check for friendly fire with null safety
	var is_friendly = false
	if is_instance_valid(wielder_ref) and is_instance_valid(body) and "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	
	# Get friendly_fire setting from JSON flags or metadata with enhanced safety
	var allows_friendly_fire = false
	if is_instance_valid(weapon_ref):
		if "weapon_data" in weapon_ref:
			if "flags" in weapon_ref.weapon_data:
				allows_friendly_fire = weapon_ref.weapon_data.flags.get("friendly_fire", false)
			elif weapon_ref.has_meta("friendly_fire"):
				allows_friendly_fire = weapon_ref.get_meta("friendly_fire")
	
	# Skip friendly hits if friendly fire is disabled
	if is_friendly and !allows_friendly_fire:
		if DEBUG:
			print("Friendly fire prevented in area attack")
		return
	
	if DEBUG:
		print("Area hit: ", body.name)
	
	# Check if the body can take damage
	if is_instance_valid(body) and body.has_method("take_damage"):
		# Calculate direction (away from player) with safety checks
		var hit_dir = Vector2.ZERO
		if is_instance_valid(body) and is_instance_valid(wielder_ref):
			hit_dir = (body.global_position - wielder_ref.global_position).normalized()
		else:
			hit_dir = Vector2.RIGHT  # Default direction if positions can't be determined
		
		# Calculate damage with area damage bonus
		var effective_damage = 10  # Default fallback
		if is_instance_valid(weapon_ref) and weapon_ref.has_method("calculate_damage"):
			effective_damage = int(weapon_ref.calculate_damage() * damage_multiplier)
		
		# Get knockback from JSON stats with enhanced safety
		var knockback_force = 300.0  # Default
		if is_instance_valid(weapon_ref) and "weapon_data" in weapon_ref:
			if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
				knockback_force = float(weapon_ref.weapon_data.stats.knockback_force)
			else:
				knockback_force = float(get_param("knockback_force", 300.0))
		
		# Apply damage and knockback with final safety check
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(
				effective_damage, 
				hit_dir, 
				knockback_force
			)
			
			if DEBUG and is_instance_valid(wielder_ref) and is_instance_valid(weapon_ref):
				print(wielder_ref.name + " hits " + body.name + 
					" with area attack from " + weapon_ref.get_weapon_name())
			
			# Apply hit effects with safety check
			if is_instance_valid(weapon_ref) and weapon_ref.has_method("apply_effects"):
				weapon_ref.apply_effects(body, "hit")
			
			# Notify behaviors about hit
			if is_instance_valid(body):
				notify_behaviors_on_hit(body)

# Create particle effects for more visual impact
func create_area_particles(parent, radius):
	if !is_instance_valid(parent):
		return
		
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
	if is_instance_valid(weapon) and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree() and wielder.get_tree().current_scene:
		var scene = wielder.get_tree().current_scene
		if is_instance_valid(scene) and scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")
	
	return null
