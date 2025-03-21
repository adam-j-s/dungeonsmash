# explosive_behavior.gd - Makes projectiles explode on impact
class_name ExplosiveBehavior
extends Behavior

func _init_behavior():
	pass

func get_behavior_name() -> String:
	return "ExplosiveBehavior"

func on_projectile_created(projectile):
	# Apply explosive properties to the projectile
	var explosion_radius = float(get_param("explosion_radius", 60.0))
	
	# Set properties on the projectile
	projectile.set_meta("explosion_radius", explosion_radius)
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["explosion_radius"] = explosion_radius
		projectile.apply_config(config)
	
	if DEBUG:
		print("Applied explosive behavior to projectile with radius: ", explosion_radius)
