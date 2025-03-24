# projectile_system_adapter.gd - Adapter to bridge old projectile system with new refactored system
class_name ProjectileSystemAdapter
extends Node

# Debug flag
const DEBUG = false

# Supported projectile types
enum ProjectileType {
	STANDARD,
	HOMING,
	BOUNCING,
	EXPLOSIVE,
	WAVE,
	SINGULARITY
}

# Create appropriate projectile based on configuration
static func create_projectile(config: Dictionary, wielder):
	if DEBUG:
		print("ProjectileSystemAdapter creating projectile with config: ", config)
	
	# Check if we're using legacy or new projectile system
	var use_new_system = ProjectSettings.get_setting("game/use_new_projectile_system", false)
	
	if use_new_system:
		# Use the new projectile factory
		return ProjectileFactory.create_projectile(config, wielder)
	else:
		# Use legacy system - create a basic projectile and configure it
		return create_legacy_projectile(config, wielder)

# Create a projectile using the legacy system
static func create_legacy_projectile(config: Dictionary, wielder):
	# Create a basic projectile
	var projectile = CharacterBody2D.new()
	projectile.name = "Projectile_" + str(randi())
	
	# Apply the legacy projectile script
	var script = load("res://scripts/projectile.gd")
	if script:
		projectile.set_script(script)
	else:
		print("ERROR: Could not load legacy projectile script!")
		return null
	
	# Set the wielder reference
	projectile.wielder_ref = wielder
	projectile.set_meta("wielder", wielder)
	
	# Initialize the projectile with config
	if projectile.has_method("initialize"):
		projectile.initialize(config)
	
	return projectile

# Convert a new projectile type to the legacy system
static func convert_projectile_to_legacy(projectile):
	# Get configuration from the new projectile
	var config = extract_config_from_projectile(projectile)
	
	# Create a legacy projectile
	var legacy_projectile = create_legacy_projectile(config, projectile.wielder_ref)
	
	# Copy position and velocity
	legacy_projectile.global_position = projectile.global_position
	legacy_projectile.velocity = projectile.velocity
	
	# Remove the original
	projectile.queue_free()
	
	return legacy_projectile

# Extract configuration from a projectile
static func extract_config_from_projectile(projectile):
	var config = {}
	
	# Extract basic properties
	if "speed" in projectile:
		config["speed"] = projectile.speed
	if "direction" in projectile:
		config["direction"] = projectile.direction
	if "lifetime" in projectile:
		config["lifetime"] = projectile.lifetime
	if "damage" in projectile:
		config["damage"] = projectile.damage
	if "knockback" in projectile:
		config["knockback"] = projectile.knockback
	
	# Extract special properties based on projectile type
	if projectile is HomingProjectile:
		config["homing_strength"] = projectile.homing_strength
		config["projectile_type"] = "homing"
	elif projectile is BouncingProjectile:
		config["bounce_count"] = projectile.bounce_count
		config["projectile_type"] = "bouncing"
	elif projectile is ExplosiveProjectile:
		config["explosion_radius"] = projectile.explosion_radius
		config["projectile_type"] = "explosive"
	elif projectile is WaveProjectile:
		config["is_wave"] = true
		config["wave_amplitude"] = projectile.wave_amplitude
		config["wave_frequency"] = projectile.wave_frequency
		config["projectile_type"] = "wave"
	elif projectile is SingularityProjectile:
		config["is_singularity"] = true
		config["pull_radius"] = projectile.pull_radius
		config["pull_strength"] = projectile.pull_strength
		config["projectile_type"] = "singularity"
	
	# Extract metadata
	for meta_key in projectile.get_meta_list():
		config[meta_key] = projectile.get_meta(meta_key)
	
	return config

# Get appropriate projectile class based on type
static func get_projectile_class(projectile_type):
	match projectile_type:
		ProjectileType.STANDARD:
			return StandardProjectile
		ProjectileType.HOMING:
			return HomingProjectile
		ProjectileType.BOUNCING:
			return BouncingProjectile
		ProjectileType.EXPLOSIVE:
			return ExplosiveProjectile
		ProjectileType.WAVE:
			return WaveProjectile
		ProjectileType.SINGULARITY:
			return SingularityProjectile
		_:
			return StandardProjectile

# Convert string type to enum
static func get_projectile_type_from_string(type_string: String):
	match type_string.to_lower():
		"standard":
			return ProjectileType.STANDARD
		"homing":
			return ProjectileType.HOMING
		"bouncing":
			return ProjectileType.BOUNCING
		"explosive":
			return ProjectileType.EXPLOSIVE
		"wave":
			return ProjectileType.WAVE
		"singularity":
			return ProjectileType.SINGULARITY
		_:
			return ProjectileType.STANDARD
