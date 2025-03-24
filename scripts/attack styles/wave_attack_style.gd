# wave_attack_style.gd - Creates projectiles that move in a wave pattern
class_name WaveAttackStyle
extends AttackStyle

var wave_amplitude = 50.0
var wave_frequency = 3.0

func _init_style():
	# Initialize wave-specific properties
	wave_amplitude = float(get_param("wave_amplitude", 50.0))
	wave_frequency = float(get_param("wave_frequency", 3.0))
	
	# Check for wave parameters in behaviors
	if weapon and weapon.weapon_data.has("behaviors"):
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
	
	if DEBUG:
		print("Wave style initialized with amplitude: ", wave_amplitude, ", frequency: ", wave_frequency)

func get_style_name() -> String:
	return "WaveAttackStyle"

func execute_attack():
	print("Executing wave attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder or !weapon:
		print("Missing wielder or weapon reference - cannot execute attack")
		return false
	
	# Get direction based on sprite direction
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	
	# Create wave projectile
	var projectile = CharacterBody2D.new()
	projectile.name = "WaveProjectile_" + weapon.weapon_id
	
	# First, try to load the wave projectile script
	var script_res = load("res://scripts/projectile.gd")
	if !script_res:
		print("ERROR: Could not load projectile script!")
		return false
		
	# Apply script BEFORE adding to scene tree
	projectile.set_script(script_res)
	
	# Set references
	projectile.wielder_ref = wielder
	projectile.set_meta("wielder", wielder)
	projectile.set_meta("wielder_name", wielder.name)
	projectile.set_meta("weapon", weapon)
	projectile.set_meta("weapon_id", weapon.weapon_id)
	
	# Add sprite with automatic centering
	var sprite = ColorRect.new()
	var sprite_size = Vector2(20, 20)
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2
	
	# Color based on tier and visual style
	var base_color = Color(0.3, 0.7, 0.9)  # Cyan-blue for wave
	var tier = int(get_param("tier", 0))
	var tier_factor = min(tier * 0.2, 0.8)
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)
	sprite.color = final_color
	
	projectile.add_child(sprite)
	
	# Add wave visual trail for better effect
	add_wave_trail(projectile)

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)
	
	# Calculate properties
	var projectile_speed = float(get_param("projectile_speed", 350))
	var projectile_lifetime = float(get_param("projectile_lifetime", 1.2))
	
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
		"piercing": int(get_param("piercing", 0)),
		"projectile_type": "wave",
		"weapon_id": weapon.weapon_id
	}
	
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
	
	# Find the behavior manager to attach behaviors
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.apply_behaviors_to_projectile(projectile)
	
	# Notify the behavior system about this projectile
	if weapon:
		weapon.on_projectile_created(projectile)
		
		# Trigger on_projectile_created for any behaviors on the weapon
		if weapon.has_node("BehaviorManager"):
			var weapon_behavior_manager = weapon.get_node("BehaviorManager")
			if weapon_behavior_manager:
				for behavior in weapon_behavior_manager.behaviors:
					if behavior.has_method("on_projectile_created"):
						behavior.on_projectile_created(projectile)
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	# Notify when attack ends
	on_attack_end()
	
	return true

# Add visual trail to wave projectile for better wave visualization
func add_wave_trail(projectile):
	# Create a trail effect node
	var trail = Line2D.new()
	trail.name = "WaveTrail"
	trail.default_color = Color(0.3, 0.7, 0.9, 0.5)  # Matching wave color but transparent
	trail.width = 5
	trail.set_meta("max_points", 12)  # Number of points to keep in trail
	
	# Add update function to maintain trail
	var trail_script = GDScript.new()
	trail_script.source_code = """extends Line2D

var parent_projectile
var max_points = 12

func _ready():
	parent_projectile = get_parent()
	max_points = get_meta("max_points", 12)

func _process(delta):
	if parent_projectile:
		# Add current position to front of line
		add_point(Vector2.ZERO)
		
		# Remove old points if too many
		while get_point_count() > max_points:
			remove_point(0)
"""
	trail_script.reload()
	trail.set_script(trail_script)
	
	# Add to projectile
	projectile.add_child(trail)

# Create wave visual patterns (water ripple effect)
func create_wave_particles(projectile):
	# Add water-like particles behind projectile
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.5
	particles.explosiveness = 0.1
	particles.direction = Vector2(-1, 0)  # Trailing behind
	particles.spread = 30
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 30
	particles.scale_amount = 2
	particles.color = Color(0.3, 0.7, 0.9, 0.5)  # Matching wave color
	
	projectile.add_child(particles)

# Notify behaviors about attack execution
func notify_behaviors_on_attack():
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_attack_executed(get_style_name())

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
