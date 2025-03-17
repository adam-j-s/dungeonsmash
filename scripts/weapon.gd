# weapon.gd - Base unified weapon class
class_name Weapon
extends Node2D

# Weapon properties (loaded from database)
var weapon_id: String = "sword"  # Default ID
var weapon_data: Dictionary = {}

# Visual components (can be setup in _ready or by the loading code)
var weapon_sprite: Sprite2D = null

# Current state
var cooldown_timer: Timer
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
	
	# Update cooldown timer
	cooldown_timer.wait_time = 1.0 / weapon_data.attack_speed
	
	# Update visuals
	update_appearance()
	
	print("Loaded weapon: " + weapon_data.name)

# Update the weapon's visual appearance
func update_appearance():
	# For now just change color based on tier
	# In the future, you could load different sprites
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		add_child(weapon_sprite)
	
	# Set color based on tier
	var tier_colors = [
		Color(0.8, 0.8, 0.8),  # Common - Gray
		Color(0.0, 0.8, 0.0),  # Uncommon - Green
		Color(0.0, 0.4, 0.8),  # Rare - Blue
		Color(0.8, 0.0, 0.8),  # Epic - Purple
		Color(1.0, 0.8, 0.0)   # Legendary - Gold
	]
	
	var tier = weapon_data.get("tier", 0)
	if tier >= 0 and tier < tier_colors.size():
		weapon_sprite.modulate = tier_colors[tier]

# Initialize this weapon with a character
func initialize(character):
	wielder = character

# Get the weapon's type
func get_weapon_type() -> String:
	return weapon_data.get("weapon_type", "sword")

# Get the weapon's name
func get_weapon_name() -> String:
	return weapon_data.get("name", "Basic Weapon")

# Perform an attack
func perform_attack():
	if !can_attack:
		return false
	
	# Start cooldown
	can_attack = false
	cooldown_timer.start()
	
	# Create attack hitbox
	create_hitbox()
	
	# Weapon-specific effects
	apply_attack_effects()
	
	# Emit signal
	emit_signal("weapon_used", weapon_id)
	
	return true

# Create a hitbox for the attack
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
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties
	hitbox.collision_layer = 0
	if wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
	
	# Connect signal to detect hits
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Add to wielder
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

# Handle collision with the hitbox
func _on_hitbox_body_entered(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Weapon hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate knockback direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
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
