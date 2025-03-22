# melee_attack_style.gd - Melee attack implementation
class_name MeleeAttackStyle
extends AttackStyle

func _init_style():
	pass

func get_style_name() -> String:
	return "MeleeAttackStyle"

func execute_attack():
	if DEBUG:
		print("MeleeAttackStyle executing attack for weapon: ", weapon.get_weapon_name() if weapon else "None")
		print("Wielder reference: ", wielder.name if wielder else "None")
	
	# [... rest of the function ...]
	
	# Create hitbox for melee damage
	create_hitbox()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Create a hitbox for the attack
func create_hitbox():
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = get_param("attack_range", Vector2(50, 30))
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
	
	# Add to wielder
	if wielder:
		wielder.add_child(hitbox)
		
		# Remove after short duration
		var tree = wielder.get_tree()
		await tree.create_timer(0.2).timeout
		if hitbox and is_instance_valid(hitbox):
			hitbox.queue_free()
	
	# Notify when attack ends
	if weapon:
		weapon.on_attack_end()

# Handle collision with the hitbox
func _on_hitbox_body_entered(body):
	if body == wielder:
		return  # Don't hit yourself
		
	if DEBUG:
		print("Weapon hit: ", body.name)
	else:
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
		
		# Debug info
		if DEBUG:
			print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
		else:
			print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
		
		# Apply hit effects
		on_hit(body)
