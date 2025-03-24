# push_attack_style.gd - Creates attacks that push enemies away from the wielder
class_name PushAttackStyle
extends AttackStyle

var push_range = Vector2(60, 40)
var push_duration = 0.3
var knockback_multiplier = 1.5  # Push attacks have stronger knockback
var damage_multiplier = 1.1  # Slight damage boost for push attacks

func _init_style():
	# Initialize push-specific properties
	push_range = get_param("attack_range", Vector2(60, 40))
	push_duration = float(get_param("push_duration", 0.3))
	knockback_multiplier = float(get_param("knockback_multiplier", 1.5))
	damage_multiplier = float(get_param("damage_multiplier", 1.1))
	
	if DEBUG:
		print("Push style initialized with range: ", push_range)

func get_style_name() -> String:
	return "PushAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing push attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder:
		print("Missing wielder reference - cannot execute push attack")
		return false
	
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
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	push_hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties
	push_hitbox.collision_layer = 0
	if wielder.name == "Player1":
		push_hitbox.collision_mask = 4  # Detect Player 2
	else:
		push_hitbox.collision_mask = 2  # Detect Player 1
	
	# Store weapon and wielder reference for hit callback
	push_hitbox.set_meta("weapon", weapon)
	push_hitbox.set_meta("wielder", wielder)
	
	# Connect hit signal
	push_hitbox.body_entered.connect(_on_push_hit)
	
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
	
	# Create timer to remove hitbox after delay
	create_timer(
		wielder,
		push_duration,
		self,
		"remove_push_hitbox",
		[push_hitbox]
	)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# Remove the push hitbox when attack completes
func remove_push_hitbox(hitbox):
	if hitbox and is_instance_valid(hitbox):
		# Create fade out effect for visual elements
		for child in hitbox.get_children():
			if child is Line2D or child is ColorRect:
				var tween = child.create_tween()
				tween.tween_property(child, "modulate:a", 0.0, 0.1)
		
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

# Create force field wave effect for push visualization
func create_push_wave(parent, direction):
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

# Handle push attack hits
func _on_push_hit(body):
	# Get hitbox and references
	var push_hitbox = body.get_parent()
	var weapon_ref = push_hitbox.get_meta("weapon")
	var wielder_ref = push_hitbox.get_meta("wielder")
	
	if !weapon_ref or !wielder_ref or body == wielder_ref:
		return  # Don't push yourself or if missing references
	
	print("Push hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate push direction (away from player)
		var push_dir = (body.global_position - wielder_ref.global_position).normalized()
		
		# Calculate damage with slight boost (push has offensive value)
		var effective_damage = int(weapon_ref.calculate_damage() * damage_multiplier)
		
		# Calculate knockback force with boost (primary push effect)
		var knockback_force = float(get_param("knockback_force", 300.0)) * knockback_multiplier
		
		# Apply damage and extra strong knockback
		body.take_damage(effective_damage, push_dir, knockback_force)
		
		# Create a visual trail effect for the push
		create_push_trail(body, push_dir, knockback_force)
		
		# Apply additional physical impulse for more responsive push
		if body is CharacterBody2D and "velocity" in body:
			# Boost existing velocity in push direction
			body.velocity = push_dir * knockback_force * 1.2
		
		print(wielder_ref.name + " pushes " + body.name + " with " + weapon_ref.get_weapon_name())
		
		# Apply hit effects
		if weapon_ref:
			weapon_ref.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Create a visual trail effect for the push
func create_push_trail(target, direction, force):
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
		"queue_free_node",
		[trail]
	)

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
