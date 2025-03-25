# Makes projectiles pass through multiple targets
class_name PiercingBehavior
extends BehaviorBase

var piercing_count = 1  # How many targets to pierce through
var damage_decay_factor = 0.8  # Damage decreases by 20% for each pierce

func _init_behavior():
	# Get piercing parameters
	piercing_count = int(get_param("piercing", 1))
	damage_decay_factor = float(get_param("damage_decay_factor", 0.8))
	
	if DEBUG:
		print("Initialized piercing behavior with count: ", piercing_count)

func get_behavior_name() -> String:
	return "PiercingBehavior"

func on_projectile_created(projectile):
	# Set piercing properties on the projectile
	projectile.set_meta("piercing", piercing_count)
	projectile.set_meta("damage_decay_factor", damage_decay_factor)
	
	# Add piercing visual effect
	var blue_trail = create_piercing_trail(projectile)
	if blue_trail:
		projectile.add_child(blue_trail)
	
	if DEBUG:
		print("Applied piercing behavior to projectile with count: ", piercing_count)

# Create visual trail effect for piercing
func create_piercing_trail(projectile):
	# Create a line trail effect
	var trail = Line2D.new()
	trail.name = "PiercingTrail"
	trail.default_color = Color(0.2, 0.6, 1.0, 0.6)  # Blue trail
	trail.width = 4
	
	# Create script to update trail
	var script = GDScript.new()
	script.source_code = """
	extends Line2D
	
	var max_points = 10
	
	func _process(delta):
		# Add current position to front of line
		add_point(Vector2.ZERO)
		
		# Remove old points if too many
		while get_point_count() > max_points:
			remove_point(0)
	"""
	script.reload()
	trail.set_script(script)
	
	return trail

# Handle piercing hit logic
func on_projectile_hit(projectile, target):
	# Skip if no piercing remains
	if piercing_count <= 0:
		return
	
	# Decrement piercing counter
	piercing_count -= 1
	projectile.set_meta("piercing", piercing_count)
	
	# Create hit effect
	create_piercing_hit_effect(projectile, target)
	
	# Reduce damage for next hit
	if "damage" in projectile:
		projectile.damage = int(projectile.damage * damage_decay_factor)
	
	# If we have piercing left, prevent destruction
	if piercing_count > 0:
		# Cancel destruction after impact
		projectile.set_meta("cancel_destruction", true)
	
	if DEBUG:
		print("Piercing: ", piercing_count, " remaining")

# Create a visual hit effect for piercing
func create_piercing_hit_effect(projectile, target):
	# Create a brief flash
	var flash = ColorRect.new()
	flash.color = Color(0.2, 0.6, 1.0, 0.7)  # Blue flash
	flash.size = Vector2(20, 20)
	flash.position = Vector2(-10, -10)  # Center the rect
	
	# Create effect at hit position
	var effect = Node2D.new()
	effect.name = "PierceHitEffect"
	effect.global_position = target.global_position
	effect.add_child(flash)
	
	# Add to scene
	projectile.get_tree().current_scene.add_child(effect)
	
	# Fade out
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	
	# Remove after effect completes
	await effect.get_tree().create_timer(0.2).timeout
	if effect and is_instance_valid(effect):
		effect.queue_free()
