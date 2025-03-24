# melee_attack_style.gd
class_name MeleeAttackStyle
extends AttackStyle

var attack_range = Vector2(50, 30)
var attack_duration = 0.2
var hit_effect = ""
var hit_sound = ""

func _init_style():
	# Initialize melee-specific properties
	attack_range = get_attack_range()
	attack_duration = float(get_param("attack_duration", 0.2))
	hit_effect = get_param("hit_effect", "")
	hit_sound = get_param("hit_sound", "")

func get_style_name() -> String:
	return "MeleeAttackStyle"

func execute_attack():
	print("MeleeAttackStyle executing attack")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference")
		return false
	
	# Create hitbox for melee damage
	create_hitbox()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# Create a hitbox for the attack
func create_hitbox():
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = attack_range
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Position the hitbox in front of the wielder
	if wielder and wielder.has_node("Sprite2D"):
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties
	hitbox.collision_layer = 0
	if wielder and wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Add visual representation of hitbox (for debugging)
	if DEBUG:
		var visual = ColorRect.new()
		visual.size = shape.size
		visual.position = -shape.size / 2
		visual.color = Color(1.0, 0.3, 0.3, 0.4)  # Transparent red
		hitbox.add_child(visual)
	
	# Add to wielder
	if wielder:
		wielder.add_child(hitbox)
		
		# Create timer to remove hitbox after delay
		create_timer(
			wielder,
			attack_duration,
			self,
			"remove_hitbox",
			[hitbox]
		)
	
	# Optional attack animation
	play_attack_animation()

# Remove the hitbox once attack completes
func remove_hitbox(hitbox):
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()
	
	# Notify when attack ends
	on_attack_end()

# Handle collision with the hitbox
func _on_hitbox_body_entered(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Weapon hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction
		var attack_direction = 1
		if wielder and wielder.has_node("Sprite2D"):
			attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		var knockback_dir = Vector2(attack_direction, -0.3).normalized()
		
		# Calculate damage with stats
		var effective_damage = weapon.calculate_damage()
		
		# Apply damage and knockback
		body.take_damage(effective_damage, knockback_dir, float(get_param("knockback_force", 500.0)))
		
		print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
		
		# Apply hit effects
		if weapon:
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
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Swing animation
		tween.tween_property(weapon_sprite, "rotation", attack_direction * 0.5, attack_duration * 0.5)
		tween.tween_property(weapon_sprite, "rotation", 0, attack_duration * 0.5)

# Play hit effects when hitting an enemy
func play_hit_effects(target):
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
	if weapon and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	var scene = wielder.get_tree().current_scene
	if scene.has_node("BehaviorManager"):
		return scene.get_node("BehaviorManager")
	
	return null

# Helper function to get params either from weapon or using a default
func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value
