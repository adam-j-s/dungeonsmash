# Creates attacks that push enemies away from the wielder - Enhanced for safety
class_name PushAttackStyle
extends AttackStyle

var push_range = Vector2(60, 40)
var push_duration = 0.3
var knockback_multiplier = 1.5  # Push attacks have stronger knockback
var damage_multiplier = 1.1  # Slight damage boost for push attacks

# Import CollisionUtils
const CollisionUtils = preload("res://scripts/collision_utils.gd")

func _init_style():
	# Initialize push-specific properties from JSON structure
	
	# Get range from JSON or parameters
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			push_range = Vector2(
				float(weapon.weapon_data.range.get("x", 60)),
				float(weapon.weapon_data.range.get("y", 40))
			)
		else:
			push_range = get_param("attack_range", Vector2(60, 40))
	else:
		push_range = get_param("attack_range", Vector2(60, 40))
	
	# Get push duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "push_duration" in weapon.weapon_data.stats:
			push_duration = float(weapon.weapon_data.stats.push_duration)
		else:
			push_duration = float(get_param("push_duration", 0.3))
	else:
		push_duration = float(get_param("push_duration", 0.3))
		
	# Get knockback multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "knockback_multiplier" in weapon.weapon_data.stats:
			knockback_multiplier = float(weapon.weapon_data.stats.knockback_multiplier)
		else:
			knockback_multiplier = float(get_param("knockback_multiplier", 1.5))
	else:
		knockback_multiplier = float(get_param("knockback_multiplier", 1.5))
	
	# Get damage multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "damage_multiplier" in weapon.weapon_data.stats:
			damage_multiplier = float(weapon.weapon_data.stats.damage_multiplier)
		else:
			damage_multiplier = float(get_param("damage_multiplier", 1.1))
	else:
		damage_multiplier = float(get_param("damage_multiplier", 1.1))
	
	if DEBUG:
		print("Push style initialized with range: ", push_range)
	
func get_style_name() -> String:
	return "PushAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing push attack with weapon: ", weapon.get_weapon_name() if is_instance_valid(weapon) else "Invalid weapon")
	
	if !is_instance_valid(wielder) or !is_instance_valid(weapon):
		print("Missing wielder or weapon reference - cannot execute push attack")
		return false
	
	# Update aim direction using our enhanced method
	update_aim_direction()
	
	# Create a hitbox that pushes enemies away from the player
	var push_hitbox = Area2D.new()
	push_hitbox.name = "PushHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = push_range
	collision.shape = shape
	push_hitbox.add_child(collision)
	
	# Position in front of player	
	var attack_direction = sign(aim_direction.x)
	push_hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Store attack direction in hitbox metadata
	push_hitbox.set_meta("attack_direction", attack_direction)
	
	# Store weapon and wielder reference in hitbox
	push_hitbox.set_meta("weapon", weapon)
	push_hitbox.set_meta("wielder", wielder)
	
	# Set up collision - use CollisionUtils if available
	if CollisionUtils != null:
		CollisionUtils.setup_collision_mask(push_hitbox, wielder, false)
	else:
		# Manual setup
		push_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			push_hitbox.collision_mask = 4  # Detect Player 2
		else:
			push_hitbox.collision_mask = 2  # Detect Player 1
	
	# Use our safe signal connection method
	connect_signal_safe(push_hitbox, "body_entered", self, "_on_push_hit")
	
	# Add visual effect for the push
	var push_visual = Line2D.new()
	push_visual.width = 5
	push_visual.default_color = Color(0.2, 0.8, 0.2, 0.7)  # Green for push
	push_visual.add_point(Vector2.ZERO)
	push_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
	push_hitbox.add_child(push_visual)
	
	# Add force field effect for more visual impact
	create_push_wave(push_hitbox, attack_direction)
	
	# Add to wielder
	wielder.add_child(push_hitbox)
	
	# Create timer for cleanup
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = push_duration
	wielder.add_child(timer)
	
	# Connect timer using our safe method
	connect_signal_safe(timer, "timeout", self, "_on_attack_timer_timeout", [push_hitbox, timer])
	timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# New handler for attack timer
func _on_attack_timer_timeout(hitbox, timer):
	# Use our enhanced cleanup method
	cleanup_hitbox_safe(hitbox, timer)

# Handle push attack hits - enhanced for safety
func _on_push_hit(body):
	# Safety checks first
	if !is_instance_valid(body):
		return
	
	# Get the hitbox that triggered this callback
	var push_hitbox = body.get_parent().get_node_or_null("PushHitbox")
	if !is_instance_valid(push_hitbox):
		return
	
	# Get weapon and wielder from hitbox metadata
	var weapon_ref = null
	var wielder_ref = null
	
	if push_hitbox.has_meta("weapon"):
		weapon_ref = push_hitbox.get_meta("weapon") 
	
	if push_hitbox.has_meta("wielder"):
		wielder_ref = push_hitbox.get_meta("wielder")
	
	if !is_instance_valid(weapon_ref) or !is_instance_valid(wielder_ref):
		return  # Skip if missing references
	
	# Skip self hit
	if body == wielder_ref:
		return
	
	# Check for friendly fire
	var is_friendly = false
	if "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	
	# Get friendly_fire setting from JSON flags
	var allows_friendly_fire = false
	if "weapon_data" in weapon_ref:
		if "flags" in weapon_ref.weapon_data:
			allows_friendly_fire = weapon_ref.weapon_data.flags.get("friendly_fire", false)
		else:
			# Fallback to metadata for backward compatibility
			allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false)
	
	# Skip friendly hits if friendly fire is disabled
	if is_friendly and !allows_friendly_fire:
		if DEBUG:
			print("Friendly fire prevented in push attack")
		return
	
	if DEBUG:
		print("Push hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate push direction (away from player)
		var push_dir = (body.global_position - wielder_ref.global_position).normalized()
		
		# Calculate damage with slight boost (push has offensive value)
		var effective_damage = int(weapon_ref.calculate_damage() * damage_multiplier)
		
		# Calculate knockback force with boost (primary push effect)
		var knockback_force = 0.0
		if "weapon_data" in weapon_ref:
			if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
				knockback_force = float(weapon_ref.weapon_data.stats.knockback_force) * knockback_multiplier
			else:
				knockback_force = float(get_param("knockback_force", 300.0)) * knockback_multiplier
		else:
			knockback_force = float(get_param("knockback_force", 300.0)) * knockback_multiplier
		
		# Apply damage and extra strong knockback
		body.take_damage(effective_damage, push_dir, knockback_force)
		
		# Create a visual trail effect for the push
		create_push_trail(body, push_dir, knockback_force)
		
		# Apply additional physical impulse for more responsive push
		if body is CharacterBody2D and "velocity" in body:
			# Boost existing velocity in push direction
			body.velocity = push_dir * knockback_force * 1.2
		
		if DEBUG:
			print(wielder_ref.name + " pushes " + body.name + " with " + weapon_ref.get_weapon_name())
		
		# Apply hit effects
		if is_instance_valid(weapon_ref):
			weapon_ref.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Create force field wave effect for push visualization
func create_push_wave(parent, direction):
	if !is_instance_valid(parent):
		return
		
	# Create semi-transparent push wave
	var wave = ColorRect.new()
	wave.color = Color(0.2, 0.8, 0.2, 0.3)  # Translucent green
	
	# Size based on push range
	var width = push_range.x
	var height = push_range.y * 1.5  # Make it taller for better visual
	wave.size = Vector2(width / 2, height)
	
	# Position at start of push
	wave.position = Vector2(0, -height/2)
	parent.add_child(wave)
	
	# Create expansion animation
	var tween = wave.create_tween()
	tween.tween_property(wave, "position:x", direction * width, push_duration * 0.8)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, push_duration * 0.8)
	
	# Also add particles for more impact
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = push_duration
	particles.explosiveness = 0.6
	particles.direction = Vector2(direction, 0)
	particles.spread = 20
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.scale_amount = 2
	particles.color = Color(0.2, 0.8, 0.2)  # Green
	
	parent.add_child(particles)
	particles.emitting = true

# Create a visual trail effect for the push
func create_push_trail(target, direction, force):
	if !is_instance_valid(target) or !is_instance_valid(wielder):
		return
		
	# Determine trail length based on force
	var trail_length = min(force * 0.2, 100)  # Cap at reasonable length
	
	# Create a trail showing push direction
	var trail = Line2D.new()
	trail.default_color = Color(0.2, 0.8, 0.2, 0.5)  # Translucent green
	trail.width = 3
	trail.add_point(target.global_position)
	trail.add_point(target.global_position + direction * trail_length)
	
	# Add to scene
	target.get_tree().current_scene.add_child(trail)
	
	# Fade out
	var tween = trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.3)
	
	# Remove after effect completes
	create_timer(
		trail,
		0.3,
		self,
		"remove_effect",
		[trail]
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
	if is_instance_valid(weapon) and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree() and wielder.get_tree().current_scene:
		var scene = wielder.get_tree().current_scene
		if is_instance_valid(scene) and scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")
	
	return null
