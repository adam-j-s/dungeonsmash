# Area attack implementation
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	print("Area style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")

func get_style_name() -> String:
	return "AreaAttackStyle"

# Add the get_param function directly in this script
func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value

func execute_attack():
	print("Executing area attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Create a circular hitbox for area damage
		var area_hitbox = Area2D.new()
		area_hitbox.name = "AreaHitbox"
		
		# Add circular collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		var attack_range = get_param("attack_range", Vector2(50, 50))
		if attack_range is Vector2:
			shape.radius = attack_range.x / 2  # Use X as radius
		else:
			shape.radius = 25  # Default fallback
		collision.shape = shape
		area_hitbox.add_child(collision)
		
		# Position around player
		area_hitbox.position = Vector2.ZERO  # Centered on player
		
		# Set collision properties
		area_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			area_hitbox.collision_mask = 4
		else:
			area_hitbox.collision_mask = 2
			
		# Connect hit signal
		area_hitbox.body_entered.connect(_on_area_hit)
		
		# Add visual effect (circle expanding outward)
		var circle = ColorRect.new()
		circle.color = Color(0.9, 0.3, 0.1, 0.5)  # Orange for area attack
		var size = shape.radius * 2
		circle.size = Vector2(size, size)
		circle.position = Vector2(-size/2, -size/2)  # Center the rect
		circle.scale = Vector2(0.1, 0.1)  # Start small
		area_hitbox.add_child(circle)
		
		# Add to wielder FIRST
		if wielder:
			wielder.add_child(area_hitbox)
			
			# NOW create the tween after adding to scene
			var tween = circle.create_tween()
			tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
			
			# Create timer to remove hitbox after delay
			var timer = Timer.new()
			timer.wait_time = 0.3
			timer.one_shot = true
			wielder.add_child(timer)
			timer.timeout.connect(func():
				if area_hitbox and is_instance_valid(area_hitbox):
					area_hitbox.queue_free()
				timer.queue_free()
			)
			timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify when attack ends
	if weapon:
		weapon.on_attack_end()
	
	return true

func _on_area_hit(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Area hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction (away from player)
		var hit_dir = (body.global_position - wielder.global_position).normalized()
		
		# Calculate damage with a small area damage bonus
		var effective_damage = int(weapon.calculate_damage() * 1.2)
		
		# Apply damage and knockback
		body.take_damage(effective_damage, hit_dir, float(get_param("knockback_force", 300.0)))
		
		print(wielder.name + " hits " + body.name + " with area attack from " + weapon.get_weapon_name())
		
		# Apply hit effects
		if weapon:
			weapon.apply_effects(body, "hit")
