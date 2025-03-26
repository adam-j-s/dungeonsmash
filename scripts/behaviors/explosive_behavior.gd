# minimal_explosive_behavior.gd - Simplified for stability
class_name ExplosiveBehavior
extends BehaviorBase

var explosion_radius = 60.0  # Radius of explosion

func _init_behavior():
	# Get explosion parameters with safer parsing
	var radius_param = get_param("explosion_radius", "60.0")
	if typeof(radius_param) == TYPE_STRING:
		explosion_radius = float(radius_param)
	else:
		explosion_radius = float(radius_param)
	
	if DEBUG:
		print("Initialized explosive behavior with radius: ", explosion_radius)

func get_behavior_name() -> String:
	return "ExplosiveBehavior"

func on_projectile_created(projectile):
	# Safety check
	if not is_instance_valid(projectile):
		return
	
	# Set explosion properties on the projectile
	projectile.set_meta("explosion_radius", explosion_radius)
	
	# Add simple visual indicator
	projectile.modulate = Color(1.0, 0.6, 0.2)  # Orange tint
	
	if DEBUG:
		print("Applied explosive behavior to projectile")

# Called when projectile hits something
func on_projectile_hit(projectile, target):
	# Create simple explosion effect
	create_simple_explosion(projectile)

# Called when projectile is destroyed
func on_projectile_destroyed(projectile):
	# Create explosion if not already created
	if not projectile.get_meta("explosion_created", false):
		create_simple_explosion(projectile)

# Create a simplified explosion
func create_simple_explosion(projectile):
	# Safety check
	if not is_instance_valid(projectile):
		return
		
	# Flag to prevent multiple explosions
	if projectile.get_meta("explosion_created", false):
		return
	
	projectile.set_meta("explosion_created", true)
	
	# Create visual only for testing
	var scene = projectile.get_tree().current_scene
	if scene:
		# Create a simple visual effect
		var explosion = ColorRect.new()
		explosion.color = Color(1, 0.5, 0, 0.7)
		explosion.size = Vector2(explosion_radius * 2, explosion_radius * 2)
		explosion.position = Vector2(-explosion_radius, -explosion_radius)
		
		var explosion_node = Node2D.new()
		explosion_node.position = projectile.global_position
		explosion_node.add_child(explosion)
		
		scene.add_child(explosion_node)
		
		# Add timer to remove the explosion
		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.one_shot = true
		explosion_node.add_child(timer)
		
		# Simple cleanup
		timer.timeout.connect(func(): 
			if is_instance_valid(explosion_node):
				explosion_node.queue_free()
		)
		
		timer.start()
		
		# Apply damage to nearby enemies - SKIP FOR NOW
		# This is where crashes likely happen, so just show visuals
		
		if DEBUG:
			print("Created simple explosion at ", projectile.global_position)
