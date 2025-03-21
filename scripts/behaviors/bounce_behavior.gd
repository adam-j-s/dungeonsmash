# bounce_behavior.gd - Makes projectiles bounce off surfaces
class_name BounceBehavior
extends Behavior

func _init_behavior():
	pass

func get_behavior_name() -> String:
	return "BounceBehavior"

func on_projectile_created(projectile):
	# Apply bounce properties to the projectile
	var bounce_count = int(get_param("bounce_count", 3))
	
	# Set properties on the projectile
	projectile.set_meta("bounce_count", bounce_count)
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["bounce_count"] = bounce_count
		projectile.apply_config(config)
	
	if DEBUG:
		print("Applied bounce behavior to projectile with bounce count: ", bounce_count)
