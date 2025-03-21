# piercing_behavior.gd - Makes projectiles pass through multiple targets
class_name PiercingBehavior
extends Behavior

func _init_behavior():
	pass

func get_behavior_name() -> String:
	return "PiercingBehavior"

func on_projectile_created(projectile):
	# Apply piercing properties to the projectile
	var piercing_count = int(get_param("piercing", 1))
	
	# Set properties on the projectile
	projectile.set_meta("piercing", piercing_count)
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["piercing"] = piercing_count
		projectile.apply_config(config)
	
	if DEBUG:
		print("Applied piercing behavior to projectile with count: ", piercing_count)
