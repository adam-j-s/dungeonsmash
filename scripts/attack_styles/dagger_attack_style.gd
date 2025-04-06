# Creates quick, short-range dagger attacks with combo potential
class_name DaggerAttackStyle
extends AttackStyle

# Configuration
var attack_range = Vector2(35, 20)  # Smaller range than sword
var combo_multiplier = 1.15  # Damage increases with consecutive hits
var combo_window = 1.0  # Seconds to land the next hit to continue combo
var max_combo = 3  # Maximum combo hits
var lunge_distance = 40  # Distance for forward lunge when pressing attack
var current_combo = 0  # Track current combo count
var last_attack_time = 0  # Track when last attack occurred
var combo_timer = null  # Timer for combo window
var min_cooldown = 0.05  # Minimum practical cooldown (50ms)

# Visual effects
var slash_colors = [
	Color(0.9, 0.9, 0.2, 0.7),  # First hit: yellow
	Color(1.0, 0.5, 0.0, 0.7),  # Second hit: orange
	Color(1.0, 0.1, 0.1, 0.7)   # Third hit: red
]

func _init_style():
	# Initialize dagger-specific properties
	var range_param = get_param("attack_range", Vector2(35, 20))
	if range_param is Vector2:
		attack_range = range_param
	
	attack_duration = float(get_param("attack_duration", 0.15))
	combo_multiplier = float(get_param("combo_multiplier", 1.15))
	combo_window = float(get_param("combo_window", 1.0))
	max_combo = int(get_param("max_combo", 3))
	lunge_distance = float(get_param("lunge_distance", 40))
	
	if DEBUG:
		print("Dagger style initialized with range: ", attack_range)

func get_style_name() -> String:
	return "DaggerAttackStyle"

# Override to provide faster attack speed with combo bonus
func calculate_cooldown_multiplier() -> float:
	# Apply combo state to cooldown (faster with higher combo)
	var combo_speed_bonus = min(current_combo * 0.1, 0.2)  # Up to 20% bonus from combo
	
	# Dagger has very fast attacks with combo bonus
	return max(0.1 - combo_speed_bonus, min_cooldown)  # Minimum of 5% of base cooldown

# Execute attack with combo potential
func execute_attack():
	if DEBUG:
		print("Executing dagger attack with weapon: ", weapon.get_weapon_name())
	
	if !wielder:
		print("Missing wielder reference - cannot execute dagger attack")
		return false
	
	# Check for combo
	var current_time = Time.get_ticks_msec() / 1000.0
	if combo_timer != null && is_instance_valid(combo_timer) && combo_timer.time_left > 0:
		# Within combo window, increment combo
		current_combo = min(current_combo + 1, max_combo)
		if DEBUG:
			print("Combo continued! Current combo: ", current_combo)
	else:
		# Reset combo
		current_combo = 0
		if DEBUG:
			print("Starting new combo")
	
	# Store time of this attack
	last_attack_time = current_time
	
	# Create immediate visual feedback
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.2 + (current_combo * 0.1))  # Brighter with higher combo
	flash.size = Vector2(50, 50)
	flash.position = Vector2(-25, -25)
	wielder.add_child(flash)

	# Quick fade out
	var flash_tween = flash.create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.08)  # Very quick fade
	flash_tween.tween_callback(flash.queue_free)
	
	# Create a hitbox for the dagger attack
	var hitbox = Area2D.new()
	hitbox.name = "DaggerHitbox"
	
	# Add a rectangular collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = attack_range
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Position in front of player
	var attack_direction = 1 if wielder.get_node("Sprite2D").flip_h else -1
	hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Set collision properties
	hitbox.collision_layer = 0
	if wielder.name == "Player1":
		hitbox.collision_mask = 4  # Detect Player 2
	else:
		hitbox.collision_mask = 2  # Detect Player 1
	
	# Add visual effect for the slash - color based on combo level
	var slash_visual = Line2D.new()
	slash_visual.width = 3 + (current_combo * 2)  # Gets wider with combo
	slash_visual.default_color = slash_colors[min(current_combo, slash_colors.size() - 1)]
	
	# Create slash pattern based on combo level
	var points = []
	match current_combo:
		0:  # Basic horizontal slash
			points = [
				Vector2(-5, -5),
				Vector2(0, 0),
				Vector2(attack_direction * attack_range.x, 0)
			]
		1:  # Diagonal slash
			points = [
				Vector2(-5, -10),
				Vector2(0, -5),
				Vector2(attack_direction * attack_range.x, 5)
			]
		_:  # Upper slash for 3rd hit
			points = [
				Vector2(-5, 10),
				Vector2(0, 0),
				Vector2(attack_direction * attack_range.x, -10)
			]
	
	# Add points to line
	for point in points:
		slash_visual.add_point(point)
	
	hitbox.add_child(slash_visual)
	
	# Add particles for more visual impact
	create_slash_particles(hitbox, attack_direction)
	
	# Connect hit detection directly without using metadata
	hitbox.body_entered.connect(_on_dagger_hit_direct)
	
	# Add to wielder
	wielder.add_child(hitbox)
	
	# Create fade effect for slash
	var tween = slash_visual.create_tween()
	tween.tween_property(slash_visual, "modulate:a", 0.0, attack_duration)
	
	# Implement lunge if player is moving forward
	var input_direction = 0
	if wielder.has_method("get_input_direction"):
		input_direction = wielder.get_input_direction().x
	
	if input_direction * attack_direction > 0 && "velocity" in wielder:
		# Apply a small forward movement
		wielder.velocity.x += attack_direction * lunge_distance
		if DEBUG:
			print("Applying lunge: ", attack_direction * lunge_distance)
	
	# Set up combo window timer
	if combo_timer != null && is_instance_valid(combo_timer):
		combo_timer.queue_free()
	
	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.wait_time = combo_window
	wielder.add_child(combo_timer)
	combo_timer.timeout.connect(func():
		if current_combo > 0:
			current_combo = 0
			if DEBUG:
				print("Combo reset due to timeout")
	)
	combo_timer.start()
	
	# Create a timer to remove the hitbox with frame synchronization
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = attack_duration
	wielder.add_child(timer)
	
	# Connect timer with deferred cleanup for frame synchronization
	timer.timeout.connect(func():
		call_deferred("cleanup_hitbox", hitbox, timer)
	)
	timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# Helper for safely cleaning up hitboxes with frame sync
func cleanup_hitbox(hitbox: Variant, timer: Variant = null) -> Variant:
	# Remove hitbox when timer expires
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	if timer != null and is_instance_valid(timer):
		timer.queue_free()
	# Notify when attack ends
	on_attack_end()
	return null  # Return null to match Variant return type
# Direct hit handler that doesn't rely on metadata
func _on_dagger_hit_direct(body):
	if DEBUG:
		print("Dagger hit detected: ", body.name)
	
	# Skip if not valid target or hitting self
	if !is_instance_valid(body) or body == wielder:
		return
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction
		var hit_dir = Vector2(1, 0)
		if wielder.get_node("Sprite2D").flip_h:
			hit_dir = Vector2(-1, 0)
		
		# Calculate damage with combo multiplier
		var combo_factor = 1.0 + (current_combo * (combo_multiplier - 1.0))
		var effective_damage = int(weapon.calculate_damage() * combo_factor)
		
		# Use knockback from weapon but reduce it for dagger
		var knockback_force = float(get_param("knockback_force", 300.0)) * 0.7
		
		if DEBUG:
			print("Dagger hit with combo level ", current_combo, 
				  " factor ", combo_factor, 
				  " damage ", effective_damage)
		
		# Add hit flash effect for more feedback
		create_hit_flash(body)
		
		# Apply damage with calculated values
		body.take_damage(effective_damage, hit_dir, knockback_force)
		
		print(wielder.name + " hits " + body.name + " with " + 
			  weapon.get_weapon_name() + " (combo level: " + str(current_combo) + ")")
		
		# Apply weapon effects
		weapon.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Create flash effect on hit target for better feedback
func create_hit_flash(body):
	var hit_flash = ColorRect.new()
	hit_flash.color = slash_colors[min(current_combo, slash_colors.size() - 1)]
	hit_flash.color.a = 0.4
	hit_flash.size = Vector2(40, 40)
	hit_flash.position = Vector2(-20, -20)
	body.add_child(hit_flash)
	
	# Quick fade out
	var tween = hit_flash.create_tween()
	tween.tween_property(hit_flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(hit_flash.queue_free)

# Create particle effects for the slash
func create_slash_particles(parent, direction):
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 8 + (current_combo * 4)  # More particles with higher combo
	particles.lifetime = attack_duration
	
	# Particle properties
	particles.direction = Vector2(direction, 0)
	particles.spread = 30
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 50
	particles.scale_amount_min = 1.0 + (current_combo * 0.5)
	particles.scale_amount_max = 2.0 + (current_combo * 0.5)
	
	# Color based on combo
	particles.color = slash_colors[min(current_combo, slash_colors.size() - 1)]
	
	parent.add_child(particles)

# Notify behaviors about attack execution
func notify_behaviors_on_attack():
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_attack_executed(get_style_name())

# Notify behaviors about hit
func notify_behaviors_on_hit(target):
	var behavior_manager = find_behavior_manager()
	if behavior_manager:
		behavior_manager.on_hit(target)

# Find a behavior manager to use
func find_behavior_manager():
	# Safety check - is the weapon still valid?
	if is_instance_valid(weapon) and weapon != null:
		# First check if weapon has one
		if weapon.has_node("BehaviorManager"):
			return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree() and wielder.get_tree().current_scene:
		var scene = wielder.get_tree().current_scene
		if scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")
	
	return null
