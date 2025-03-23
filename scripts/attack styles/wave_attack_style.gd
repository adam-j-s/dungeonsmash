# Wave attack implementation
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
	print("Wave style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
	weapon = weapon_ref
	if weapon:
		wielder = weapon.wielder
		print("Wielder set to: ", wielder.name if wielder else "None")

func get_style_name() -> String:
	return "WaveAttackStyle"

func get_param(param_name, default_value):
	if weapon and weapon.weapon_data.has(param_name):
		return weapon.weapon_data[param_name]
	return default_value

func execute_attack():
	print("Executing wave attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference - cannot execute attack")
		return
	
	# Get direction based on sprite direction
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Similar to projectile attack but with wave properties
	var projectile = CharacterBody2D.new()
	projectile.name = "WaveProjectile_" + weapon.weapon_id
	
	# First, try to load the wave projectile script
	var script_res = load("res://scripts/projectile.gd")  # We'll use the same base script
	if !script_res:
		print("ERROR: Could not load projectile script!")
		return false
		
	# Apply script BEFORE adding to scene tree
	projectile.set_script(script_res)
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(20, 20)  # Define size once
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2  # Automatically centers based on size
	
	# Color based on tier
	var base_color = Color(0.3, 0.7, 0.9)  # Cyan-blue for wave
	var tier = int(get_param("tier", 0))
	var tier_factor = min(tier * 0.2, 0.8)
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)
	sprite.color = final_color
	
	projectile.add_child(sprite)

	# Add collision with matching size
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)
	
	# Calculate properties
	var projectile_speed = float(get_param("projectile_speed", 350))
	var projectile_lifetime = float(get_param("projectile_lifetime", 1.2))
	
	# Get wave properties from behaviors or defaults
	var wave_amplitude = 50.0
	var wave_frequency = 3.0
	
	# Check for wave parameters in behaviors
	if weapon.weapon_data.has("behaviors"):
		var behaviors = weapon.weapon_data["behaviors"]
		if behaviors is String:
			var behavior_list = behaviors.split(";")
			for behavior in behavior_list:
				if behavior.begins_with("wave:"):
					var params = behavior.split(":")
					if params.size() > 1:
						var param_parts = params[1].split(",")
						for part in param_parts:
							var kv = part.split("=")
							if kv.size() == 2:
								if kv[0] == "wave_amplitude":
									wave_amplitude = float(kv[1])
								elif kv[0] == "wave_frequency":
									wave_frequency = float(kv[1])
	
	# Set wielder reference
	projectile.wielder_ref = wielder
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("wielder_name", wielder.name)
	projectile.set_meta("weapon", weapon)
	
	# Position in front of player
	var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
	projectile.global_position = spawn_position
	
	# Create configuration
	var config = {
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
	}
	
	# Set the projectile type directly
	projectile.projectile_type = "wave"
	
	# Initialize before adding to scene
	if projectile.has_method("initialize"):
		projectile.initialize(config)
	else:
		print("ERROR: Projectile script has no initialize method!")
		return false
		
	# Add to scene
	if wielder and wielder.get_parent():
		wielder.get_parent().add_child(projectile)
		# Force position update
		projectile.global_position = spawn_position
		print("Added wave projectile at: ", projectile.global_position)
	else:
		print("ERROR: Cannot add wave projectile to scene - no parent for wielder")
		projectile.queue_free()
		return false
	
	# Notify the behavior system about this projectile
	if projectile and weapon:
		weapon.on_projectile_created(projectile)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	return true
