# piercing_behavior.gd - Makes projectiles pass through multiple targets
class_name PiercingBehavior
extends Behavior

var remaining_pierces = 0
var damage_decay_factor = 0.8  # Damage decreases by 20% for each enemy pierced

func _init_behavior():
	# Any additional setup specific to piercing
	pass

func get_behavior_name() -> String:
	return "PiercingBehavior"

func on_projectile_created(projectile):
	# Apply piercing properties to the projectile
	remaining_pierces = int(get_param("piercing", 1))
	
	# Set properties on the projectile
	projectile.piercing = remaining_pierces
	projectile.set_meta("piercing", remaining_pierces)
	projectile.projectile_type = "piercing"
	
	# If the projectile has a config property, update it
	if projectile.has_method("apply_config"):
		var config = projectile.config_params.duplicate() if "config_params" in projectile else {}
		config["piercing"] = remaining_pierces
		config["projectile_type"] = "piercing"
		projectile.apply_config(config)
	
	# Add this behavior directly to the projectile for callbacks
	if projectile.has_method("add_behavior"):
		projectile.add_behavior(self)
	
	if DEBUG:
		print("Applied piercing behavior to projectile with count: ", remaining_pierces)

# Process function - piercing uses standard movement
func on_projectile_process(projectile, delta):
	# Let the projectile handle normal movement
	return false

# Physics process - piercing uses standard physics
func on_projectile_physics_process(projectile, delta):
	# Let the projectile handle standard physics
	return false

# Called when projectile hits something
func on_projectile_hit(projectile, target):
	# Only care about hits with characters, not walls
	if !target.has_method("take_damage"):
		return
	
	if DEBUG:
		print("Piercing projectile hit target: ", target.name, " remaining: ", remaining_pierces)
	
	# Decrement pierce counter
	remaining_pierces -= 1
	projectile.piercing = remaining_pierces
	
	# Apply visual feedback - trail effect
	create_hit_effect(projectile, target)
	
	# Reduce damage for subsequent hits
	if projectile.has_method("apply_config") and "damage" in projectile.config_params:
		var config = projectile.config_params.duplicate()
		config["damage"] = int(config["damage"] * damage_decay_factor)
		projectile.apply_config(config)
	
	# If no pierces left, destroy the projectile
	if remaining_pierces <= 0:
		if projectile.has_method("destroy"):
			# Schedule destruction on next frame to allow hit to complete
			projectile.get_tree().create_timer(0.01).timeout.connect(func():
				if is_instance_valid(projectile):
					projectile.destroy()
			)
	
	# Return true to indicate we've handled the hit
	return true

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	if DEBUG:
		print("Piercing projectile destroyed with ", remaining_pierces, " pierces remaining")

# Create a visual effect at hit location
func create_hit_effect(projectile, target):
	# Create a brief flash effect
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.7, 0.3, 0.7)  # Yellow-orange
	flash.size = Vector2(20, 20)
	flash.position = Vector2(-10, -10)  # Center
	
	# Create effect at hit position
	var effect = Node2D.new()
	effect.name = "PierceEffect"
	effect.global_position = target.global_position
	effect.add_child(flash)
	
	# Add to scene
	projectile.get_tree().current_scene.add_child(effect)
	
	# Create fade out effect
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	
	# Remove after effect completes
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.one_shot = true
	effect.add_child(timer)
	timer.timeout.connect(func():
		if effect and is_instance_valid(effect):
			effect.queue_free()
	)
	timer.start()
