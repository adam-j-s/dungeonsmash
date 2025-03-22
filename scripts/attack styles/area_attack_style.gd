# Push attack implementation
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	print("Push style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")

func get_style_name() -> String:
	return "PushAttackStyle"

# Add the get_param function directly in this script
func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value

func execute_attack():
	print("Executing push attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Similar to pull but with opposite effect
		var push_hitbox = Area2D.new()
		push_hitbox.name = "PushHitbox"
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = get_param("attack_range", Vector2(60, 40))
		collision.shape = shape
		push_hitbox.add_child(collision)
		
		# Position in front of player
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		push_hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		push_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			push_hitbox.collision_mask = 4
		else:
			push_hitbox.collision_mask = 2
			
		# Connect special push signal
		push_hitbox.body_entered.connect(_on_push_hit)
		
		# Add visual effect
		var push_visual = Line2D.new()
		push_visual.width = 5
		push_visual.default_color = Color(0.2, 0.8, 0.2, 0.7)  # Green for push
		push_visual.add_point(Vector2.ZERO)
		push_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
		push_hitbox.add_child(push_visual)
		
		# Add to wielder
		if wielder:
			wielder.add_child(push_hitbox)
			
			# Remove after short duration
			var tree = wielder.get_tree()
			await tree.create_timer(0.3).timeout
			if push_hitbox and is_instance_valid(push_hitbox):
				push_hitbox.queue_free()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	if weapon:
		weapon.on_attack_end()

func _on_push_hit(body):
	if body == wielder:
		return  # Don't push yourself
		
	print("Push hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate push direction (away from player)
		var push_dir = (body.global_position - wielder.global_position).normalized()
		
		# Calculate damage
		var effective_damage = weapon.calculate_damage()
		
		# Apply damage and extra strong knockback
		body.take_damage(effective_damage, push_dir, float(get_param("knockback_force", 300.0)) * 1.5)
		
		print(wielder.name + " pushes " + body.name + " with " + weapon.get_weapon_name())
			
		# Apply hit effects
		if weapon:
			weapon.apply_effects(body, "hit")
