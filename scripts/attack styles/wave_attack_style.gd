# Wave attack implementation
class_name WaveAttackStyle
extends AttackStyle

func _init_style():
	pass

func get_style_name() -> String:
	return "WaveAttackStyle"

func execute_attack():
	if DEBUG:
		print("Executing wave attack with weapon: ", weapon.get_weapon_name())
	
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Similar to projectile attack but with wave properties
		var projectile = CharacterBody2D.new()
		projectile.name = "WaveProjectile_" + weapon.weapon_id
		
		# First, try to load the wave projectile script
		var script_res = load("res://scripts/projectile.gd")  # We'll use the same base script
		if !script_res:
			print("ERROR: Could not load projectile script!")
			return
			
		# Apply script BEFORE adding to scene tree
		projectile.set_script(script_res)
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 10
		collision.shape = shape
		projectile.add_child(collision)
		
		# Add visual
		var visual = ColorRect.new()
		var base_color = Color(0.3, 0.7, 0.9)  # Cyan-blue for wave
		var tier = int(get_param("tier", 0))
		var tier_factor = min(tier * 0.2, 0.8)
		var gold_color = Color(1.0, 0.8, 0.0)
		var final_color = base_color.lerp(gold_color, tier_factor)
		
		visual.color = final_color
		visual.size = Vector2(20, 20)
		visual.position = Vector2(-10, -10)
		projectile.add_child(visual)
		
		# Set collision properties
		projectile.collision_layer = 0
		if wielder.name == "Player1":
			projectile.collision_mask = 4
		else:
			projectile.collision_mask = 2
			
		# Set up hit detection
		var hitbox = Area2D.new()
		hitbox.collision_layer = 0
		hitbox.collision_mask = projectile.collision_mask
		var hitbox_collision = CollisionShape2D.new()
		hitbox_collision.shape = shape.duplicate()
		hitbox.add_child(hitbox_collision)
		projectile.add_child(hitbox)
		
		# Connect signal
		hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))
		
		# Calculate properties
		var projectile_speed = float(get_param("projectile_speed", 350))
		var projectile_lifetime = float(get_param("projectile_lifetime", 1.2))
		
		# Get wave properties from behaviors or defaults
		var wave_amplitude = 50.0
		var wave_frequency = 3.0
		
		# Check for wave parameters in behaviors
		if weapon.weapon_data.has("behaviors"):
			var behaviors = weapon.weapon_data["behaviors"]
			if behaviors is Array:
				for behavior in behaviors:
					if behavior is String and behavior.begins_with("wave:"):
						var params = behavior.split(":")
						if params.size() > 1:
							var param_parts = params[1].split(";")
							for part in param_parts:
								var kv = part.split("=")
								if kv.size() == 2:
									if kv[0] == "wave_amplitude":
										wave_amplitude = float(kv[1])
									elif kv[0] == "wave_frequency":
										wave_frequency = float(kv[1])
		
		# Store metadata
		projectile.set_meta("damage", weapon.calculate_damage())
		projectile.set_meta("knockback", float(get_param("knockback_force", 400)))
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("weapon_name", weapon.get_weapon_name())
		projectile.set_meta("is_wave", true)  # Mark as wave projectile
		projectile.set_meta("wave_amplitude", wave_amplitude)  # How high the wave goes
		projectile.set_meta("wave_frequency", wave_frequency)  # How many waves per second
		
		# Position in front of player
		var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
		projectile.global_position = spawn_position
		
		# Initialize before adding to scene
		if projectile.has_method("initialize"):
			projectile.initialize({
				"speed": projectile_speed,
				"direction": attack_direction,
				"lifetime": projectile_lifetime,
				"damage": weapon.calculate_damage(),
				"knockback": float(get_param("knockback_force", 400)),
				"is_wave": true,
				"wave_amplitude": wave_amplitude,
				"wave_frequency": wave_frequency,
				"bounce_count": int(get_param("bounce_count", 0)),
				"homing_strength": float(get_param("homing_strength", 0.0)),
				"explosion_radius": float(get_param("explosion_radius", 0)),
				"piercing": int(get_param("piercing", 0))
			})
		else:
			print("ERROR: Projectile script has no initialize method!")
			return
			
		# Add to scene
		weapon.get_tree().current_scene.add_child(projectile)
		
		# Force position update
		projectile.global_position = spawn_position
		
		# Notify the behavior system about this projectile
		if projectile and weapon:
			weapon.on_projectile_created(projectile)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")

# Handle projectile hit (reusing from projectile attack style)
func _on_projectile_hit(body, projectile):
	# Get stored values from the projectile
	var wielder_ref = projectile.get_meta("wielder")
	
	# Don't hit yourself
	if body == wielder_ref:
		return

	# Skip if already in hit targets list (for piercing)
	if projectile.has_method("has_hit_target") and projectile.has_hit_target(body):
		return
		
	if DEBUG:
		print("Wave projectile hit: ", body.name)
	else:
		print("Wave projectile hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Get more stored values from the projectile
		var damage = projectile.get_meta("damage")
		var knockback_force = projectile.get_meta("knockback")
		var direction = projectile.get_meta("direction")
		var weapon_name = projectile.get_meta("weapon_name")
		
		# Calculate knockback direction
		var knockback_dir = Vector2(direction, -0.2).normalized()
		
		# Apply damage and knockback
		body.take_damage(damage, knockback_dir, knockback_force)
		
		# Debug info
		if wielder_ref:
			if DEBUG:
				print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " wave")
			else:
				print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " wave")
		
		# Apply effects on hit
		on_hit(body)
		
		# Destroy the projectile on hit (waves don't have piercing)
		if projectile.has_method("destroy"):
			projectile.destroy()
		else:
			projectile.queue_free()
