# weapon.gd - Base unified weapon class with specialized attack types
class_name Weapon
extends Node2D

# Weapon properties (loaded from database)
var weapon_id: String = "sword"  # Default ID
var weapon_data: Dictionary = {}

# Visual components (can be setup in _ready or by the loading code)
var weapon_sprite: Sprite2D = null

# Current state
var cooldown_timer: Timer = null
var can_attack: bool = true
var wielder = null  # Reference to the character wielding the weapon

# Signal when weapon is used
signal weapon_used(weapon_id)

func _ready():
	# Set up cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Load the default weapon if no ID has been set yet
	if weapon_data.is_empty():
		load_weapon(weapon_id)

# Load weapon data from the database
func load_weapon(id: String):
	weapon_id = id
	weapon_data = WeaponDatabase.get_weapon(id)
	
	# Update cooldown timer - FIXED: Make sure timer exists first
	if cooldown_timer != null:
		cooldown_timer.wait_time = 1.0 / weapon_data.get("attack_speed", 1.0)
	
	# Update visuals
	update_appearance()
	
	print("Loaded weapon: " + weapon_data.get("name", "Unknown"))

# Update the weapon's visual appearance to make it visually distinct
func update_appearance():
	# Create a visual for the weapon if it doesn't exist
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		add_child(weapon_sprite)
		
		# Remove any existing children
		for child in weapon_sprite.get_children():
			child.queue_free()
		
		# Create weapon visual based on type
		var weapon_type = get_weapon_type()
		match weapon_type:
			"sword":
				# Create a sword-like rectangle
				var rect = ColorRect.new()
				rect.size = Vector2(20, 5)  # Long rectangle for sword
				rect.position = Vector2(-10, -2.5)  # Center it
				weapon_sprite.add_child(rect)
			"staff":
				# Create a staff-like shape (stick with orb)
				var stick = ColorRect.new()
				stick.size = Vector2(4, 25)  # Thin, tall rectangle for staff
				stick.position = Vector2(-2, -15)  # Center it
				weapon_sprite.add_child(stick)
				
				var orb = ColorRect.new()
				orb.size = Vector2(12, 12)  # Circle-like shape for staff top
				orb.position = Vector2(-6, -25)  # Position at top of staff
				weapon_sprite.add_child(orb)
			_:
				# Default shape
				var rect = ColorRect.new()
				rect.size = Vector2(15, 15)  # Square for unknown
				rect.position = Vector2(-7.5, -7.5)  # Center it
				weapon_sprite.add_child(rect)
	
	# Set color based on weapon type
	var base_colors = {
		"sword": Color(0.8, 0.2, 0.2),  # Red for sword
		"staff": Color(0.2, 0.2, 0.8),  # Blue for staff
	}
	
	# Get the correct color for this weapon type
	var weapon_type = weapon_data.get("weapon_type", "sword")
	var base_color = base_colors.get(weapon_type, Color(0.5, 0.5, 0.5))
	
	# Apply tier tinting
	var tier = weapon_data.get("tier", 0)
	var tier_factor = min(tier * 0.2, 0.8)  # Up to 80% gold tint for higher tiers
	var gold_color = Color(1.0, 0.8, 0.0)
	var final_color = base_color.lerp(gold_color, tier_factor)
	
	# Apply the color to all ColorRect children
	for child in weapon_sprite.get_children():
		if child is ColorRect:
			child.color = final_color
	
	# Make the sprite visible
	weapon_sprite.visible = true
	
	# Debug print the appearance
	print("Updated weapon appearance: " + get_weapon_name() + " (" + weapon_type + ")")

# Initialize this weapon with a character
func initialize(character):
	wielder = character

# Get the weapon's type
func get_weapon_type() -> String:
	return weapon_data.get("weapon_type", "sword")

# Get the weapon's name
func get_weapon_name() -> String:
	return weapon_data.get("name", "Basic Weapon")

# Perform an attack - Now with specialized behavior per weapon type
func perform_attack():
	if !can_attack:
		return false
	
	# Start cooldown
	can_attack = false
	if cooldown_timer:
		cooldown_timer.start()
	
	# Debug output
	print("Weapon performing attack: " + get_weapon_name())
	
	# Execute attack based on weapon type
	var weapon_type = get_weapon_type()
	match weapon_type:
		"sword":
			perform_sword_attack()
		"staff":
			perform_staff_attack()
		_:
			# Default fallback attack
			create_hitbox()
	
	# Emit signal
	emit_signal("weapon_used", weapon_id)
	
	return true

# Specialized sword attack (melee)
func perform_sword_attack():
	# Melee attack with sword
	create_hitbox()
	apply_attack_effects()

# Specialized staff attack (projectile)
func perform_staff_attack():
	# Projectile attack for staff
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Create projectile
		var projectile = Area2D.new()
		projectile.name = "StaffProjectile"
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 10
		collision.shape = shape
		projectile.add_child(collision)
		
		# Add visual
		var visual = ColorRect.new()
		
		# Get base and tint colors
		var base_color = Color(0.2, 0.2, 0.8)  # Blue for staff
		var tier = weapon_data.get("tier", 0)
		var tier_factor = min(tier * 0.2, 0.8)
		var gold_color = Color(1.0, 0.8, 0.0)
		var final_color = base_color.lerp(gold_color, tier_factor)
		
		visual.color = final_color
		visual.size = Vector2(20, 20)
		visual.position = Vector2(-10, -10)
		projectile.add_child(visual)
		
		# Set collision properties
		projectile.collision_layer = 0
		if wielder.name == "Player1":
			projectile.collision_mask = 4  # Detect Player 2
		else:
			projectile.collision_mask = 2  # Detect Player 1
		
		# Set initial position (in front of player)
		projectile.position = Vector2(attack_direction * 30, 0)
		
		# Add to scene
		wielder.add_child(projectile)
		
		# Apply projectile movement
		var projectile_speed = 400
		var projectile_lifetime = 0.8
		
		# Store these values in the projectile for use in hit detection
		projectile.set_meta("damage", calculate_damage())
		projectile.set_meta("knockback", weapon_data.get("knockback_force", 500))
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("wielder", wielder)
		
		# Connect signal for hit detection
		projectile.body_entered.connect(_on_projectile_hit.bind(projectile))
		
		# Create a tween for movement
		var tween = create_tween()
		var end_pos = projectile.position + Vector2(attack_direction * projectile_speed * projectile_lifetime, 0)
		tween.tween_property(projectile, "position", end_pos, projectile_lifetime)
		
		# Remove after lifetime
		await get_tree().create_timer(projectile_lifetime).timeout
		if projectile and is_instance_valid(projectile):
			projectile.queue_free()
	
	# Also apply visual effects
	apply_attack_effects()

# Handle projectile hits
func _on_projectile_hit(body, projectile):
	# Get stored values from the projectile
	var wielder_ref = projectile.get_meta("wielder")
	var damage = projectile.get_meta("damage")
	var knockback_force = projectile.get_meta("knockback")
	var direction = projectile.get_meta("direction")
	
	# Don't hit yourself
	if body == wielder_ref:
		return
		
	print("Projectile hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction
		var knockback_dir = Vector2(direction, -0.2).normalized()
		
		# Apply damage and knockback
		body.take_damage(damage, knockback_dir, knockback_force)
		
		# Debug info
		if wielder_ref:
			print(wielder_ref.name + " deals " + str(damage) + " damage with " + get_weapon_name() + " projectile")
		
		# Apply effects on hit
		apply_hit_effects(body)
		
		# Remove projectile after hit
		if projectile and is_instance_valid(projectile):
			projectile.queue_free()

# Create a hitbox for the attack (for melee weapons)
func create_hitbox():
	var hitbox = Area2D.new()
	hitbox.name = "WeaponHitbox"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = weapon_data.get("attack_range", Vector2(50, 30))
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Position the hitbox in front of the wielder
	if wielder and wielder.has_node("Sprite2D"):
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties
	hitbox.collision_layer = 0
	if wielder and wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Add to wielder
	if wielder:
		wielder.add_child(hitbox)
		
		# Remove after short duration
		await get_tree().create_timer(0.2).timeout
		if hitbox and is_instance_valid(hitbox):
			hitbox.queue_free()

# Apply any special effects this weapon has
func apply_attack_effects():
	var effects = weapon_data.get("effects", [])
	
	# Process each effect
	for effect in effects:
		match effect:
			"fire":
				# Add fire visual effect
				var fire_particles = CPUParticles2D.new()
				fire_particles.amount = 20
				fire_particles.lifetime = 0.5
				fire_particles.randomness = 0.5
				fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				fire_particles.emission_sphere_radius = 10
				fire_particles.gravity = Vector2(0, -20)
				fire_particles.color = Color(1.0, 0.5, 0.0)
				add_child(fire_particles)
				
				# Remove after effect completes
				await get_tree().create_timer(0.5).timeout
				if fire_particles and is_instance_valid(fire_particles):
					fire_particles.queue_free()
			# Add more effects as needed

# Calculate damage based on weapon stats and wielder's stats
func calculate_damage() -> int:
	var base_damage = weapon_data.get("damage", 10)
	
	if wielder and wielder.has_method("get_weapon_multiplier"):
		var multiplier = wielder.get_weapon_multiplier(get_weapon_type())
		base_damage = round(base_damage * multiplier)
		
	return base_damage

# Handle collision with the hitbox (for melee attacks)
func _on_hitbox_body_entered(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Weapon hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction
		var attack_direction = 1
		if wielder and wielder.has_node("Sprite2D"):
			attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		var knockback_dir = Vector2(attack_direction, -0.3).normalized()
		
		# Calculate damage with stats
		var effective_damage = calculate_damage()
		
		# Apply damage and knockback
		body.take_damage(effective_damage, knockback_dir, weapon_data.get("knockback_force", 500.0))
		
		# Debug info
		print(wielder.name + " deals " + str(effective_damage) + " damage with " + get_weapon_name())
		
		# Apply hit effects
		apply_hit_effects(body)

# Apply any hit-specific effects
func apply_hit_effects(target):
	var effects = weapon_data.get("effects", [])
	
	# Process each effect
	for effect in effects:
		match effect:
			"fire":
				# Could apply DOT damage or other status effects here
				pass
			# Add more effects as needed

# Cooldown timer callback
func _on_cooldown_timeout():
	can_attack = true
