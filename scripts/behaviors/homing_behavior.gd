# homing_behavior.gd - Makes projectiles track targets
class_name HomingBehavior
extends Behavior

func _init_behavior():
	# Any additional setup specific to homing
	pass

func get_behavior_name() -> String:
	return "HomingBehavior"

func on_projectile_created(projectile):
	# Apply homing properties to the projectile
	var homing_strength = float(get_param("homing_strength", 0.5))
	
	# Set properties on the projectile
	projectile.set_meta("homing_strength", homing_strength)
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["homing_strength"] = homing_strength
		projectile.apply_config(config)
	
	if DEBUG:
		print("Applied homing behavior to projectile with strength: ", homing_strength)
