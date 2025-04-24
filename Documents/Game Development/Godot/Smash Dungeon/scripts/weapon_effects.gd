# weapon_effects.gd - Handles visual effects and weapon effects
extends Node

# References
var weapon = null  # Reference to parent weapon
var wielder = null  # Direct reference to wielder for convenience

const DEBUG = false  # Set to true only when debugging

# Unified effects system
func apply_effects(target, effect_type="hit"):
	var effects = weapon.weapon_data.get("effects", [])
	
	for effect in effects:
		# Add a check to make sure effect is a string
		if typeof(effect) != TYPE_STRING:
			print("WARNING: Non-string effect found in weapon effects array")
			continue
			
		var effect_data = WeaponDatabase.get_effect(effect)
		
		# More robust error handling
		if effect_data == null or (typeof(effect_data) == TYPE_DICTIONARY and effect_data.is_empty()):
			print("WARNING: Effect '" + effect + "' not found in database")
			continue
		
		match effect_type:
			"hit":
				# Apply hit effects (damage, status, etc)
				if target and target.has_method("apply_status_effect"):
					target.apply_status_effect(effect, effect_data)
			"visual":
				# Apply visual effects (particles, etc)
				create_visual_effect(effect, effect_data)

# Create visual effect helper function
func create_visual_effect(effect_name: String, effect_data: Dictionary):
	# Default effect color
	var effect_color = effect_data.get("visual_color", Color(1.0, 1.0, 1.0))
	
	match effect_name:
		"fire":
			# Add fire visual effect
			var fire_particles = CPUParticles2D.new()
			fire_particles.amount = 20
			fire_particles.lifetime = 0.5
			fire_particles.randomness = 0.5
			fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			fire_particles.emission_sphere_radius = 10
			fire_particles.gravity = Vector2(0, -20)
			fire_particles.color = effect_color if effect_color else Color(1.0, 0.5, 0.0)
			weapon.add_child(fire_particles)
			
			# Remove after effect completes
			await weapon.get_tree().create_timer(0.5).timeout
			if fire_particles and is_instance_valid(fire_particles):
				fire_particles.queue_free()
		"ice":
			# Ice effect - blue particles falling down
			var ice_particles = CPUParticles2D.new()
			ice_particles.amount = 15
			ice_particles.lifetime = 0.6
			ice_particles.randomness = 0.3
			ice_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			ice_particles.emission_sphere_radius = 8
			ice_particles.gravity = Vector2(0, 40)
			ice_particles.color = effect_color if effect_color else Color(0.5, 0.8, 1.0)
			weapon.add_child(ice_particles)
			
			# Remove after effect completes
			await weapon.get_tree().create_timer(0.6).timeout
			if ice_particles and is_instance_valid(ice_particles):
				ice_particles.queue_free()
		"lightning":
			# Lightning effect - zigzag particles
			var lightning_particles = CPUParticles2D.new()
			lightning_particles.amount = 30
			lightning_particles.lifetime = 0.4
			lightning_particles.randomness = 0.7
			lightning_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			lightning_particles.emission_sphere_radius = 15
			lightning_particles.direction = Vector2(0, -1)
			lightning_particles.spread = 180
			lightning_particles.initial_velocity_min = 50
			lightning_particles.initial_velocity_max = 100
			lightning_particles.color = effect_color if effect_color else Color(0.7, 0.7, 1.0)
			weapon.add_child(lightning_particles)
			
			# Remove after effect completes
			await weapon.get_tree().create_timer(0.4).timeout
			if lightning_particles and is_instance_valid(lightning_particles):
				lightning_particles.queue_free()
		"poison":
			# Poison effect - green bubbles
			var poison_particles = CPUParticles2D.new()
			poison_particles.amount = 15
			poison_particles.lifetime = 0.8
			poison_particles.randomness = 0.4
			poison_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			poison_particles.emission_sphere_radius = 12
			poison_particles.gravity = Vector2(0, -10)
			poison_particles.scale_amount_min = 0.5
			poison_particles.scale_amount_max = 1.5
			poison_particles.color = effect_color if effect_color else Color(0.4, 0.8, 0.4)
			weapon.add_child(poison_particles)
			
			# Remove after effect completes
			await weapon.get_tree().create_timer(0.8).timeout
			if poison_particles and is_instance_valid(poison_particles):
				poison_particles.queue_free()
		# Add more effects as needed
