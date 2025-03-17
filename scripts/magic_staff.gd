extends Weapon
@export var projectile_speed = 500.0
@export var projectile_range = 300.0  # How far the projectile travels
@export var projectile_lingering = true  # Whether it stays after reaching max range
@export var lingering_time = 2.0  # How long a lingering projectile stays in seconds
@export var linger_forever = true  # If true, stays until it hits something or scene changes

func _ready():
	super._ready()
	weapon_name = "Magic Staff"
	damage = 10
	knockback_force = 400.0
	attack_speed = 1.5
	attack_range = Vector2(30, 30)

func perform_attack():
	if !can_attack:
		return false
		
	# Start cooldown
	can_attack = false
	cooldown_timer.start()
	
	# Instead of a hitbox, create a projectile
	fire_projectile()
	
	# Staff effects
	attack_effects()
	
	return true

func fire_projectile():
	# Create a magic projectile
	var projectile = Area2D.new()
	projectile.name = "MagicProjectile"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)
	
	# Create sprite
	var sprite = ColorRect.new()
	sprite.color = Color(0.5, 0.2, 1.0, 0.8)  # Purple magic
	sprite.size = Vector2(20, 20)
	sprite.position = Vector2(-10, -10)
	projectile.add_child(sprite)
	
	# Position and direction
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	projectile.position = wielder.position + Vector2(attack_direction * 30, 0)
	
	# Add to scene
	wielder.get_parent().add_child(projectile)
	
	# Set collision properties
	projectile.collision_layer = 0
	if wielder.name == "Player1":
		projectile.collision_mask = 4  # Detect Player 2
	else:
		projectile.collision_mask = 2  # Detect Player 1
	
	# Connect signal to detect hits
	projectile.body_entered.connect(func(body): _on_projectile_hit(body, projectile))
	
	# Calculate travel time based on distance and speed
	var travel_time = projectile_range / projectile_speed
	
	# Movement logic
	var tween = projectile.create_tween()
	tween.tween_property(projectile, "position", 
		projectile.position + Vector2(attack_direction * projectile_range, 0), 
		travel_time)
	
	# Handle projectile lifetime
	await tween.finished
	
	if not projectile_lingering:
		# Standard projectile: destroy when reaching max range
		if projectile and is_instance_valid(projectile):
			projectile.queue_free()
	else:
		# Lingering projectile logic
		if linger_forever:
			# Stay until hit or scene changes
			pass
		else:
			# Stay for specified time
			await get_tree().create_timer(lingering_time).timeout
			if projectile and is_instance_valid(projectile):
				projectile.queue_free()

func _on_projectile_hit(body, projectile):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Staff projectile hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction from projectile to body
		var knockback_dir = (body.global_position - projectile.global_position).normalized()
		
		# Apply damage and knockback
		body.take_damage(damage, knockback_dir, knockback_force)
		
		# Weapon hit effects
		on_hit_effects(body)
	
	# Remove projectile on hit
	projectile.queue_free()

func attack_effects():
	# Play staff casting animation/sound
	print("Staff cast!")
