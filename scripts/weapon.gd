# weapon.gd - Base unified weapon class with specialized attack types
class_name Weapon
extends Node2D
const DEBUG = false  # Set to true only when debugging

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

# Perform an attack - Now with specialized behavior based on attack style
func perform_attack():
	if !can_attack:
		return false
	
	# Start cooldown
	can_attack = false
	if cooldown_timer:
		cooldown_timer.start()
	
	# Debug output
	print("Weapon performing attack: " + get_weapon_name())
	
	# Execute attack based on attack style
	var attack_style = weapon_data.get("weapon_style", "melee")
	print("Attack style: " + attack_style)
	
	match attack_style:
		"melee":
			print("Using melee attack")
			perform_melee_attack()
		"projectile":
			print("Using projectile attack")
			perform_projectile_attack()
		"wave":
			print("Using wave attack")
			perform_wave_attack()
		"pull":
			print("Using pull attack")
			perform_pull_attack()
		"push":
			print("Using push attack")
			perform_push_attack()
		"area":
			print("Using area attack")
			perform_area_attack()
		_:
			# Default fallback attack
			print("Using default melee attack")
			perform_melee_attack()
	
	# Emit signal
	emit_signal("weapon_used", weapon_id)
	
	return true

# Melee attack style
func perform_melee_attack():
	# Create hitbox for melee damage
	create_hitbox()
	# Apply visual effects
	apply_effects(null, "visual")

# Projectile attack style - REVISED: Changed order of operations to fix projectile movement
func perform_projectile_attack():
	# Projectile attack for staff
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# First, try to load the script
		var script_res = load("res://scripts/projectile.gd")
		if !script_res:
			print("ERROR: Could not load projectile.gd script!")
			return
		
		# Create the projectile with proper error checking
		var projectile = CharacterBody2D.new()
		projectile.name = "Projectile_" + weapon_id
		
		# Apply script BEFORE adding to scene tree
		projectile.set_script(script_res)
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 10
		collision.shape = shape
		projectile.add_child(collision)

		# Add visual
		var visual = ColorRect.new()

		# Get base and tint colors
		var base_color = Color(0.2, 0.2, 0.8)  # Default blue
		if get_weapon_type() == "sword":
			base_color = Color(0.8, 0.2, 0.2)  # Red for sword projectiles
			
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

		# Set up an Area2D for hit detection
		var hitbox = Area2D.new()
		hitbox.collision_layer = 0
		hitbox.collision_mask = projectile.collision_mask
		var hitbox_collision = CollisionShape2D.new()
		hitbox_collision.shape = shape.duplicate()
		hitbox.add_child(hitbox_collision)
		projectile.add_child(hitbox)

		# Connect signal for hit detection
		hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))

		# Calculate properties
		var projectile_speed = weapon_data.get("projectile_speed", 400)
		var projectile_lifetime = weapon_data.get("projectile_lifetime", 0.8)

		# Store metadata on the projectile
		projectile.set_meta("damage", calculate_damage())
		projectile.set_meta("knockback", weapon_data.get("knockback_force", 500))
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("effects", weapon_data.get("effects", []))
		projectile.set_meta("weapon_id", weapon_id)
		projectile.set_meta("weapon_name", get_weapon_name())

		# Initialize BEFORE adding to the scene
		if projectile.has_method("initialize"):
			projectile.initialize({
				"speed": projectile_speed,
				"direction": attack_direction,
				"lifetime": projectile_lifetime,
				"damage": calculate_damage(),
				"knockback": weapon_data.get("knockback_force", 500),
				"effects": weapon_data.get("effects", [])
			})
		else:
			print("ERROR: Projectile script has no initialize method!")
			return

		# Position the projectile (in front of player using global position)
		var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
		projectile.global_position = spawn_position
		
		# Now add to scene AFTER initialization
		get_tree().current_scene.add_child(projectile)
		
		# Force update position once more to ensure it's correct
		projectile.global_position = spawn_position
		
		print("Projectile launched at: " + str(projectile.global_position) + 
			  " with direction: " + str(attack_direction) + 
			  " and speed: " + str(projectile_speed))
	
	# Apply visual effects
	apply_effects(null, "visual")

# Add these new attack style functions after your existing attack functions

# Wave attack - projectile that moves in a wave pattern
func perform_wave_attack():
	if wielder:
		# Get direction based on sprite direction
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		
		# Similar to projectile attack but with wave properties
		var projectile = CharacterBody2D.new()
		projectile.name = "WaveProjectile_" + weapon_id
		
		# First, try to load the wave projectile script
		var script_res = load("res://scripts/projectile.gd")  # We'll use the same base script
		if !script_res:
			print("ERROR: Could not load projectile script!")
			return
			
		# Apply script BEFORE adding to scene tree
		projectile.set_script(script_res)
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 10
		collision.shape = shape
		projectile.add_child(collision)
		
		# Add visual
		var visual = ColorRect.new()
		var base_color = Color(0.3, 0.7, 0.9)  # Cyan-blue for wave
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
			projectile.collision_mask = 4
		else:
			projectile.collision_mask = 2
			
		# Set up hit detection
		var hitbox = Area2D.new()
		hitbox.collision_layer = 0
		hitbox.collision_mask = projectile.collision_mask
		var hitbox_collision = CollisionShape2D.new()
		hitbox_collision.shape = shape.duplicate()
		hitbox.add_child(hitbox_collision)
		projectile.add_child(hitbox)
		
		# Connect signal
		hitbox.body_entered.connect(_on_projectile_hit.bind(projectile))
		
		# Calculate properties
		var projectile_speed = weapon_data.get("projectile_speed", 350)
		var projectile_lifetime = weapon_data.get("projectile_lifetime", 1.2)
		
		# Store metadata
		projectile.set_meta("damage", calculate_damage())
		projectile.set_meta("knockback", weapon_data.get("knockback_force", 400))
		projectile.set_meta("direction", attack_direction)
		projectile.set_meta("wielder", wielder)
		projectile.set_meta("weapon_name", get_weapon_name())
		projectile.set_meta("is_wave", true)  # Mark as wave projectile
		projectile.set_meta("wave_amplitude", 50.0)  # How high the wave goes
		projectile.set_meta("wave_frequency", 3.0)  # How many waves per second
		
		# Position in front of player
		var spawn_position = wielder.global_position + Vector2(attack_direction * 30, 0)
		projectile.global_position = spawn_position
		
		# Initialize before adding to scene
		if projectile.has_method("initialize"):
			projectile.initialize({
				"speed": projectile_speed,
				"direction": attack_direction,
				"lifetime": projectile_lifetime,
				"damage": calculate_damage(),
				"knockback": weapon_data.get("knockback_force", 400),
				"is_wave": true,
				"wave_amplitude": 50.0,
				"wave_frequency": 3.0
			})
		else:
			print("ERROR: Projectile script has no initialize method!")
			return
			
		# Add to scene
		get_tree().current_scene.add_child(projectile)
		
		# Force position update
		projectile.global_position = spawn_position
	
	# Apply visual effects
	apply_effects(null, "visual")

# Pull attack - pulls enemies toward the player
func perform_pull_attack():
	if wielder:
		# Creates a hitbox that pulls enemies toward the player
		var pull_hitbox = Area2D.new()
		pull_hitbox.name = "PullHitbox"
		
		# Add a larger collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = weapon_data.get("attack_range", Vector2(60, 40))  # Wider pull area
		collision.shape = shape
		pull_hitbox.add_child(collision)
		
		# Position in front of player
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		pull_hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		pull_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			pull_hitbox.collision_mask = 4
		else:
			pull_hitbox.collision_mask = 2
			
		# Connect special pull signal
		pull_hitbox.body_entered.connect(_on_pull_hit)
		
		# Add visual effect for the pull (a brief line indicating the pull)
		var pull_visual = Line2D.new()
		pull_visual.width = 5
		pull_visual.default_color = Color(0.8, 0.2, 0.8, 0.7)  # Purple for pull
		pull_visual.add_point(Vector2.ZERO)
		pull_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
		pull_hitbox.add_child(pull_visual)
		
		# Add to wielder
		if wielder:
			wielder.add_child(pull_hitbox)
			
			# Remove after short duration
			await get_tree().create_timer(0.3).timeout
			if pull_hitbox and is_instance_valid(pull_hitbox):
				pull_hitbox.queue_free()
	
	# Apply visual effects
	apply_effects(null, "visual")

# Push attack - pushes enemies away from the player
func perform_push_attack():
	if wielder:
		# Similar to pull but with opposite effect
		var push_hitbox = Area2D.new()
		push_hitbox.name = "PushHitbox"
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = weapon_data.get("attack_range", Vector2(60, 40))
		collision.shape = shape
		push_hitbox.add_child(collision)
		
		# Position in front of player
		var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
		push_hitbox.position.x = attack_direction * (shape.size.x / 2)
		
		# Set collision properties
		push_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			push_hitbox.collision_mask = 4
		else:
			push_hitbox.collision_mask = 2
			
		# Connect special push signal
		push_hitbox.body_entered.connect(_on_push_hit)
		
		# Add visual effect
		var push_visual = Line2D.new()
		push_visual.width = 5
		push_visual.default_color = Color(0.2, 0.8, 0.2, 0.7)  # Green for push
		push_visual.add_point(Vector2.ZERO)
		push_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
		push_hitbox.add_child(push_visual)
		
		# Add to wielder
		if wielder:
			wielder.add_child(push_hitbox)
			
			# Remove after short duration
			await get_tree().create_timer(0.3).timeout
			if push_hitbox and is_instance_valid(push_hitbox):
				push_hitbox.queue_free()
	
	# Apply visual effects
	apply_effects(null, "visual")

# Area attack - damages enemies in a larger area
func perform_area_attack():
	if wielder:
		# Create a circular hitbox for area damage
		var area_hitbox = Area2D.new()
		area_hitbox.name = "AreaHitbox"
		
		# Add circular collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = weapon_data.get("attack_range", Vector2(50, 50)).x / 2  # Use X as radius
		collision.shape = shape
		area_hitbox.add_child(collision)
		
		# Position around player
		area_hitbox.position = Vector2.ZERO  # Centered on player
		
		# Set collision properties
		area_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			area_hitbox.collision_mask = 4
		else:
			area_hitbox.collision_mask = 2
			
		# Connect hit signal
		area_hitbox.body_entered.connect(_on_area_hit)
		
		# Add visual effect (circle expanding outward)
		var circle = ColorRect.new()
		circle.color = Color(0.9, 0.3, 0.1, 0.5)  # Orange for area attack
		var size = shape.radius * 2
		circle.size = Vector2(size, size)
		circle.position = Vector2(-size/2, -size/2)  # Center the rect
		area_hitbox.add_child(circle)
		
		# Animation to show area expanding
		var tween = create_tween()
		circle.scale = Vector2(0.1, 0.1)
		tween.tween_property(circle, "scale", Vector2(1, 1), 0.2)
		
		# Add to wielder
		if wielder:
			wielder.add_child(area_hitbox)
			
			# Remove after short duration
			await get_tree().create_timer(0.3).timeout
			if area_hitbox and is_instance_valid(area_hitbox):
				area_hitbox.queue_free()
	
	# Apply visual effects
	apply_effects(null, "visual")

# Signal handlers for the new attack types
func _on_pull_hit(body):
	if body == wielder:
		return  # Don't pull yourself
		
	print("Pull hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate pull direction (toward player)
		var pull_dir = (wielder.global_position - body.global_position).normalized()
		
		# Calculate damage
		var effective_damage = calculate_damage()
		
		# Apply damage with standard knockback (this will be minimal)
		body.take_damage(effective_damage, pull_dir, 50)
		
		# Direct position manipulation for pulling
		if body is CharacterBody2D:
			# Calculate pull distance based on weapon knockback
			var pull_strength = weapon_data.get("knockback_force", 300.0)
			var pull_distance = pull_dir * pull_strength * 0.5  # Adjust multiplier as needed
			
			# Apply direct position change
			body.global_position += pull_distance
			
			# Optionally also set velocity for smoother motion
			if body.has_method("set_velocity"):
				body.set_velocity(pull_dir * pull_strength)
			elif "velocity" in body:
				body.velocity = pull_dir * pull_strength
		
		# Debug info
		print(wielder.name + " pulls " + body.name + " with " + get_weapon_name())
		
		# Apply effects
		apply_effects(body, "hit")

func _on_push_hit(body):
	if body == wielder:
		return  # Don't push yourself
		
	print("Push hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate push direction (away from player)
		var push_dir = (body.global_position - wielder.global_position).normalized()
		
		# Calculate damage
		var effective_damage = calculate_damage()
		
		# Apply damage and extra strong knockback
		body.take_damage(effective_damage, push_dir, weapon_data.get("knockback_force", 300.0) * 1.5)
		
		# Debug info
		print(wielder.name + " pushes " + body.name + " with " + get_weapon_name())
		
		# Apply effects
		apply_effects(body, "hit")

func _on_area_hit(body):
	if body == wielder:
		return  # Don't hit yourself
		
	print("Area hit: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction (away from player)
		var hit_dir = (body.global_position - wielder.global_position).normalized()
		
		# Calculate damage with a small area damage bonus
		var effective_damage = int(calculate_damage() * 1.2)
		
		# Apply damage and knockback
		body.take_damage(effective_damage, hit_dir, weapon_data.get("knockback_force", 300.0))
		
		# Debug info
		print(wielder.name + " hits " + body.name + " with area attack from " + get_weapon_name())
		
		# Apply effects
		apply_effects(body, "hit")

# Handle projectile hits
func _on_projectile_hit(body, projectile):
	# Get stored values from the projectile
	var wielder_ref = projectile.get_meta("wielder")
	var damage = projectile.get_meta("damage")
	var knockback_force = projectile.get_meta("knockback")
	var direction = projectile.get_meta("direction")
	var weapon_name = projectile.get_meta("weapon_name")
	
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
			print(wielder_ref.name + " deals " + str(damage) + " damage with " + weapon_name + " projectile")
		
		# Apply effects on hit
		apply_effects(body, "hit")
		
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

# Unified effects system
func apply_effects(target, effect_type="hit"):
	var effects = weapon_data.get("effects", [])
	
	for effect in effects:
		# Add a check to make sure effect is a string
		if typeof(effect) != TYPE_STRING:
			print("WARNING: Non-string effect found in weapon effects array")
			continue
			
		var effect_data = WeaponDatabase.get_effect(effect)
		
		# More robust error handling
		if effect_data == null or (typeof(effect_data) == TYPE_DICTIONARY and effect_data.is_empty()):
			print("WARNING: Effect '" + effect + "' not found in database")
			continue
		
		match effect_type:
			"hit":
				# Apply hit effects (damage, status, etc)
				if target and target.has_method("apply_status_effect"):
					target.apply_status_effect(effect, effect_data)
			"visual":
				# Apply visual effects (particles, etc)
				create_visual_effect(effect, effect_data)

# Create visual effect helper function
func create_visual_effect(effect_name: String, effect_data: Dictionary):
	# Default effect color
	var effect_color = effect_data.get("visual_color", Color(1.0, 1.0, 1.0))
	
	match effect_name:
		"fire":
			# Add fire visual effect
			var fire_particles = CPUParticles2D.new()
			fire_particles.amount = 20
			fire_particles.lifetime = 0.5
			fire_particles.randomness = 0.5
			fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			fire_particles.emission_sphere_radius = 10
			fire_particles.gravity = Vector2(0, -20)
			fire_particles.color = effect_color if effect_color else Color(1.0, 0.5, 0.0)
			add_child(fire_particles)
			
			# Remove after effect completes
			await get_tree().create_timer(0.5).timeout
			if fire_particles and is_instance_valid(fire_particles):
				fire_particles.queue_free()
		"ice":
			# Ice effect - blue particles falling down
			var ice_particles = CPUParticles2D.new()
			ice_particles.amount = 15
			ice_particles.lifetime = 0.6
			ice_particles.randomness = 0.3
			ice_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			ice_particles.emission_sphere_radius = 8
			ice_particles.gravity = Vector2(0, 40)
			ice_particles.color = effect_color if effect_color else Color(0.5, 0.8, 1.0)
			add_child(ice_particles)
			
			# Remove after effect completes
			await get_tree().create_timer(0.6).timeout
			if ice_particles and is_instance_valid(ice_particles):
				ice_particles.queue_free()
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
		apply_effects(body, "hit")

# Cooldown timer callback
func _on_cooldown_timeout():
	can_attack = true
