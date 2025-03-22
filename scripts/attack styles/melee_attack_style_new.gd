# melee_attack_style.gd - Simplified melee attack
extends Resource

var weapon = null
var wielder = null

func initialize(weapon_ref):
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
	print("Melee style initialized")

func get_style_name():
	return "SimpleMeleeStyle"

func execute_attack():
	print("Executing simple melee attack")
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference")
		return
	
	# Create a simple hitbox for melee
	var hitbox = Area2D.new()
	hitbox.name = "SimpleMeleeHitbox"
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 30)
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Setup collision
	hitbox.collision_layer = 0
	if wielder.name == "Player1":
		hitbox.collision_mask = 4
	else:
		hitbox.collision_mask = 2
	
	# Position
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	hitbox.position.x = attack_direction * 30
	
	# Connect hit detection
	hitbox.body_entered.connect(_on_hit)
	
	# Add to wielder
	wielder.add_child(hitbox)
	
	# Remove after delay
	var tree = wielder.get_tree()
	await tree.create_timer(0.2).timeout
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_hit(body):
	if body == wielder:
		return
	print("Melee hit: ", body.name)
	if body.has_method("take_damage"):
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		var dmg = weapon.calculate_damage()
		var kdir = Vector2(attack_direction, -0.2).normalized()
		var kforce = float(weapon.weapon_data.get("knockback_force", 500))
		body.take_damage(dmg, kdir, kforce)
		
		# Apply hit effects
		if weapon:
			weapon.apply_effects(body, "hit")
