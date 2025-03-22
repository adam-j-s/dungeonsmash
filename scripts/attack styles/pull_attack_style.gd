# Pull attack implementation
class_name PullAttackStyle
extends AttackStyle

func _init_style():
	pass

func get_style_name() -> String:
	return "PullAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing pull attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Creates a hitbox that pulls enemies toward the player
		var pull_hitbox = Area2D.new()
		pull_hitbox.name = "PullHitbox"
		
		# Add a larger collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = get_param("attack_range", Vector2(60, 40))  # Wider pull area
		collision.shape = shape
		pull_hitbox.add_child(collision)
		
		# Position in front of player
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		pull_hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		pull_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			pull_hitbox.collision_mask = 4
		else:
			pull_hitbox.collision_mask = 2
			
		# Connect special pull signal
		pull_hitbox.body_entered.connect(_on_pull_hit)
		
		# Add visual effect for the pull (a brief line indicating the pull)
		var pull_visual = Line2D.new()
		pull_visual.width = 5
		pull_visual.default_color = Color(0.8, 0.2, 0.8, 0.7)  # Purple for pull
		pull_visual.add_point(Vector2.ZERO)
		pull_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
		pull_hitbox.add_child(pull_visual)
		
		# Add to wielder
		if wielder:
			wielder.add_child(pull_hitbox)
			
			# Remove after short duration
			var tree = wielder.get_tree()
			await tree.create_timer(0.3).timeout
			if pull_hitbox and is_instance_valid(pull_hitbox):
				pull_hitbox.queue_free()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	if weapon:
		weapon.on_attack_end()

func _on_pull_hit(body):
	if body == wielder:
		return  # Don't pull yourself
		
	if DEBUG:
		print("Pull hit: ", body.name)
	else:
		print("Pull hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate pull direction (toward player)
		var pull_dir = (wielder.global_position - body.global_position).normalized()
		
		# Calculate damage
		var effective_damage = weapon.calculate_damage()
		
		# Apply damage with standard knockback (this will be minimal)
		body.take_damage(effective_damage, pull_dir, 50)
		
		# Direct position manipulation for pulling
		if body is CharacterBody2D:
			# Calculate pull distance based on weapon knockback
			var pull_strength = float(get_param("knockback_force", 300.0))
			var pull_distance = pull_dir * pull_strength * 0.5  # Adjust multiplier as needed
			
			# Apply direct position change
			body.global_position += pull_distance
			
			# Optionally also set velocity for smoother motion
			if body.has_method("set_velocity"):
				body.set_velocity(pull_dir * pull_strength)
			elif "velocity" in body:
				body.velocity = pull_dir * pull_strength
		
		# Debug info
		if DEBUG:
			print(wielder.name + " pulls " + body.name + " with " + weapon.get_weapon_name())
		else:
			print(wielder.name + " pulls " + body.name + " with " + weapon.get_weapon_name())
		
		# Apply effects
		on_hit(body)
