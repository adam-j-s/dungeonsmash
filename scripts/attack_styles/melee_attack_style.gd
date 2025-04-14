# Melee attack style with enhanced safety and direction handling
class_name MeleeAttackStyle
extends AttackStyle

var attack_range = Vector2(50, 30)
var hit_effect = ""
var hit_sound = ""

# Import CollisionUtils
const CollisionUtils = preload("res://scripts/collision_utils.gd")

func get_attack_range():
	# Check for range in JSON structure
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			return Vector2(
				float(weapon.weapon_data.range.get("x", 50)),
				float(weapon.weapon_data.range.get("y", 30))
			)
		# Fallback to flat structure
		elif "attack_range_x" in weapon.weapon_data and "attack_range_y" in weapon.weapon_data:
			return Vector2(
				float(weapon.weapon_data.attack_range_x),
				float(weapon.weapon_data.attack_range_y)
			)
	
	# If range_param is provided as a parameter, use it
	var range_param = get_param("attack_range", 100)
	
	# If it's already a Vector2, return it directly
	if range_param is Vector2:
		return range_param
	
	# If it's a scalar value, convert to Vector2
	if typeof(range_param) == TYPE_INT or typeof(range_param) == TYPE_FLOAT:
		return Vector2(float(range_param), float(range_param) * 0.6)
	
	# Default fallback
	return Vector2(50, 30)

func _init_style():
	# Initialize melee-specific properties
	attack_range = get_attack_range()
	
	# Get duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "attack_duration" in weapon.weapon_data.stats:
			attack_duration = float(weapon.weapon_data.stats.attack_duration)
		else:
			attack_duration = float(get_param("attack_duration", 0.2))
	else:
		attack_duration = float(get_param("attack_duration", 0.2))
		
	# Get effects from JSON
	if weapon and "weapon_data" in weapon:
		if "effects" in weapon.weapon_data and weapon.weapon_data.effects.size() > 0:
			var effects = weapon.weapon_data.effects
			if effects.size() > 0:
				hit_effect = effects[0]  # Take first effect as hit effect
	else:
		hit_effect = get_param("hit_effect", "")
		
	# Sound effect
	hit_sound = get_param("hit_sound", "")

func get_style_name() -> String:
	return "MeleeAttackStyle"

func execute_attack():
	if DEBUG:
		print("MeleeAttackStyle executing attack")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference")
		return false
	
	# Update aim direction using our enhanced method
	update_aim_direction()
	if DEBUG:
		print("Updated aim direction for melee attack: ", aim_direction)
	
	# Create hitbox for melee damage
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# Make sure attack_range is properly handled
	if typeof(attack_range) == TYPE_VECTOR2:
		shape.size = attack_range
	else:
		# Fallback if attack_range isn't a Vector2
		print("Warning: attack_range is not a Vector2, using default")
		shape.size = Vector2(50, 30)
	
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Get attack direction from aim_direction
	var attack_direction
	var attack_angle = 0
	
	# Use twin stick aim if enabled
	if "use_twin_stick_aiming" in wielder and wielder.use_twin_stick_aiming:
		# Use aim_direction for positioning and rotation
		attack_direction = aim_direction.normalized()
		attack_angle = atan2(attack_direction.y, attack_direction.x)
		
		# Position based on aim direction vector
		hitbox.position = attack_direction * (shape.size.x / 2)
		
		# Rotate hitbox to match aim direction
		hitbox.rotation = attack_angle
		
		if DEBUG:
			print("Positioned hitbox with twin stick direction: ", attack_direction, " angle: ", attack_angle)
	else:
		# Traditional direction based on sprite flip
		var direction_value = sign(aim_direction.x)
		attack_direction = Vector2(direction_value, 0)
		
		# Position based on simple left/right direction
		hitbox.position.x = direction_value * (shape.size.x / 2)
		
		if DEBUG:
			print("Positioned hitbox with traditional direction: ", direction_value)
	
	# Store attack direction in hitbox metadata for use in hit callbacks
	hitbox.set_meta("attack_direction", attack_direction)
	
	# Set collision properties using CollisionUtils
	if CollisionUtils != null:
		CollisionUtils.setup_collision_mask(hitbox, wielder, false)
	else:
		# Fallback to manual setup
		hitbox.collision_layer = 0
		if wielder and wielder.name == "Player1":
			hitbox.collision_mask = 4  # Detect Player 2
			if DEBUG:
				print("Set hitbox to detect Player 2")
		else:
			hitbox.collision_mask = 2  # Detect Player 1
			if DEBUG:
				print("Set hitbox to detect Player 1")
	
	# Use our safe signal connection method
	connect_signal_safe(hitbox, "body_entered", self, "_on_hitbox_body_entered")
	
	if DEBUG:
		print("Connected hitbox body_entered signal safely")
	
	# Add visual representation of hitbox (for debugging)
	if DEBUG:
		var visual = ColorRect.new()
		visual.size = shape.size
		visual.position = -shape.size / 2
		visual.color = Color(1.0, 0.3, 0.3, 0.4)  # Transparent red
		visual.name = "HitboxVisual"
		hitbox.add_child(visual)
		print("Added visual debug representation to hitbox")
	
	# Add hitbox to wielder
	if wielder:
		wielder.add_child(hitbox)
		if DEBUG:
			print("Added hitbox to wielder: " + wielder.name)
		
		# Create a timer with proper cleanup
		# Create a timer with proper cleanup
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = attack_duration
		wielder.add_child(timer)

		# Direct connection instead of using connect_signal_safe
		timer.timeout.connect(func():
			print("DEBUG: Timer timeout triggered")
			_on_attack_timer_timeout(hitbox, timer)
		)
		timer.start()

		if DEBUG:
			print("Created timer to remove hitbox after " + str(attack_duration) + " seconds")
	
	# Optional attack animation
	play_attack_animation()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# New handler for attack timer to safely clean up
func _on_attack_timer_timeout(hitbox, timer):
	if DEBUG:
		print("Timer expired, safely removing hitbox")
	
	# Use our enhanced cleanup method
	cleanup_hitbox_safe(hitbox, timer)

# Handle collision with the hitbox - improved for safety
func _on_hitbox_body_entered(body):
	# Safety checks first
	if !is_instance_valid(body) or !is_instance_valid(weapon) or !is_instance_valid(wielder):
		if DEBUG:
			print("Skipping hit due to invalid references")
		return
	
	if body == wielder:
		if DEBUG:
			print("Skipping self-hit")
		return  # Don't hit yourself
		
	if DEBUG:
		print("Weapon hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Get knockback direction safely - first try to get from hitbox metadata
		var knockback_dir
		
		# Using body's parent should give us the hitbox that triggered this callback
		var hitbox = body.get_parent().get_node_or_null("WeaponHitbox")
		if is_instance_valid(hitbox) and hitbox.has_meta("attack_direction"):
			knockback_dir = hitbox.get_meta("attack_direction")
			if DEBUG:
				print("Using stored attack direction from hitbox: ", knockback_dir)
		else:
			# Fallback to calculating from current aim direction
			var direction_value = sign(aim_direction.x)
			knockback_dir = Vector2(direction_value, -0.3).normalized()
			if DEBUG:
				print("Calculated fallback direction: ", knockback_dir)
		
		# Calculate damage with stats
		var effective_damage = weapon.calculate_damage()
		
		# Get knockback force from JSON stats
		var knockback_force = 500.0  # Default
		if "weapon_data" in weapon:
			if "stats" in weapon.weapon_data and "knockback_force" in weapon.weapon_data.stats:
				knockback_force = float(weapon.weapon_data.stats.knockback_force)
			else:
				knockback_force = float(weapon.weapon_data.get("knockback_force", 500.0))
		
		# Apply damage and knockback
		body.take_damage(effective_damage, knockback_dir, knockback_force)
		
		if DEBUG:
			print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
		
		# Apply hit effects
		weapon.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)
		
		# Play hit effects
		play_hit_effects(body)

# Play attack animation on the weapon/wielder
func play_attack_animation():
	# Find weapon sprite 
	var weapon_sprite = null
	if weapon:
		for child in weapon.get_children():
			if child is Sprite2D:
				weapon_sprite = child
				break
	
	# If found, animate it
	if weapon_sprite:
		# Create rotation tween
		var tween = weapon_sprite.create_tween()
		
		# Use twin stick aim or traditional direction
		var rotation_angle
		if "use_twin_stick_aiming" in wielder and wielder.use_twin_stick_aiming:
			# Get rotation from aim direction
			var aim_angle = atan2(aim_direction.y, aim_direction.x)
			rotation_angle = aim_angle
		else:
			# Traditional direction
			var attack_direction = 1 if aim_direction.x < 0 else -1
			rotation_angle = attack_direction * 0.5
		
		# Swing animation
		tween.tween_property(weapon_sprite, "rotation", rotation_angle, attack_duration * 0.5)
		tween.tween_property(weapon_sprite, "rotation", 0, attack_duration * 0.5)

# Play hit effects when hitting an enemy
func play_hit_effects(target):
	# Safety check
	if !is_instance_valid(target) or !is_instance_valid(wielder):
		return
		
	# Create a hit flash effect
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.8)  # Bright white
	flash.size = Vector2(30, 30)
	flash.position = Vector2(-15, -15)  # Center
	
	# Create effect at hit position
	var effect = Node2D.new()
	effect.name = "HitEffect"
	effect.global_position = target.global_position
	effect.add_child(flash)
	
	# Add to scene
	wielder.get_tree().current_scene.add_child(effect)
	
	# Create fade out effect
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	
	# Remove after effect completes
	create_timer(
		effect,
		0.2,
		self,
		"remove_effect",
		[effect]
	)

# Remove an effect node
func remove_effect(effect):
	if effect and is_instance_valid(effect):
		effect.queue_free()

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
	if weapon and is_instance_valid(weapon) and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree():
		var scene = wielder.get_tree().current_scene
		if scene and scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")
	
	return null
