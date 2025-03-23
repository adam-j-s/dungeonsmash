# melee_attack_style.gd
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	print("Melee style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")

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
	
	return true

# Create a hitbox for the attack
func create_hitbox():
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 30)
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
		
		# Create timer to remove hitbox after delay
		var timer = Timer.new()
		timer.wait_time = 0.2
		timer.one_shot = true
		wielder.add_child(timer)
		timer.timeout.connect(func():
			if hitbox and is_instance_valid(hitbox):
				hitbox.queue_free()
			timer.queue_free()
		)
		timer.start()
	
	# Notify when attack ends
	if weapon:
		weapon.on_attack_end()

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
		body.take_damage(effective_damage, knockback_dir, float(weapon.weapon_data.get("knockback_force", 500.0)))
		
		print(wielder.name + " deals " + str(effective_damage) + " damage with " + weapon.get_weapon_name())
		
		# Apply hit effects
		if weapon:
			weapon.apply_effects(body, "hit")
