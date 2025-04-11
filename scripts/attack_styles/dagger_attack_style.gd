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
	# Initialize dagger-specific properties from JSON structure
	
	# Get range from JSON or parameters
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			attack_range = Vector2(
				float(weapon.weapon_data.range.get("x", 35)),
				float(weapon.weapon_data.range.get("y", 20))
			)
		else:
			attack_range = get_param("attack_range", Vector2(35, 20))
	else:
		attack_range = get_param("attack_range", Vector2(35, 20))
	
	# Get attack duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "attack_duration" in weapon.weapon_data.stats:
			attack_duration = float(weapon.weapon_data.stats.attack_duration)
		else:
			attack_duration = float(get_param("attack_duration", 0.15))
	else:
		attack_duration = float(get_param("attack_duration", 0.15))
		
	# Get combo multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "combo_multiplier" in weapon.weapon_data.stats:
			combo_multiplier = float(weapon.weapon_data.stats.combo_multiplier)
		else:
			combo_multiplier = float(get_param("combo_multiplier", 1.15))
	else:
		combo_multiplier = float(get_param("combo_multiplier", 1.15))
	
	# Get combo window from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "combo_window" in weapon.weapon_data.stats:
			combo_window = float(weapon.weapon_data.stats.combo_window)
		else:
			combo_window = float(get_param("combo_window", 1.0))
	else:
		combo_window = float(get_param("combo_window", 1.0))
	
	# Get max combo from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "max_combo" in weapon.weapon_data.stats:
			max_combo = int(weapon.weapon_data.stats.max_combo)
		else:
			max_combo = int(get_param("max_combo", 3))
	else:
		max_combo = int(get_param("max_combo", 3))
	
	# Get lunge distance from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "lunge_distance" in weapon.weapon_data.stats:
			lunge_distance = float(weapon.weapon_data.stats.lunge_distance)
		else:
			lunge_distance = float(get_param("lunge_distance", 40))
	else:
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
	
	# Set collision properties using CollisionUtils if available
	if "CollisionUtils" in get_script() and get_script().CollisionUtils != null:
		get_script().CollisionUtils.setup_collision_mask(hitbox, wielder, false)
	else:
		# Fallback to manual setup
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
	
	# Store weapon and wielder references for hit callback
	hitbox.set_meta("weapon", weapon)
	hitbox.set_meta("wielder", wielder)
	hitbox.set_meta("current_combo", current_combo)
	hitbox.set_meta("combo_multiplier", combo_multiplier)
	
	# Create and store a callable for the hit
	var hit_callable = func(body): _on_dagger_hit(body, hitbox)
	hitbox.set_meta("hit_callable", hit_callable)
	
	# Connect hit signal using stored callable
	hitbox.body_entered.connect(hit_callable)
	
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
	
	# Create a cleanup function
	var cleanup_func = func():
		if hitbox and is_instance_valid(hitbox):
			# Disconnect signal before destroying
			if hitbox.has_meta("hit_callable"):
				var callable = hitbox.get_meta("hit_callable")
				if hitbox.is_connected("body_entered", callable):
					hitbox.disconnect("body_entered", callable)
					
			# Remove hitbox
			hitbox.queue_free()
		
		# Clean up timer
		if timer and is_instance_valid(timer):
			timer.queue_free()
		
		# Notify attack end
		on_attack_end()
	
	# Connect timer to cleanup function
	timer.timeout.connect(cleanup_func)
	timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# Handler for dagger hit with metadata
func _on_dagger_hit(body, hitbox):
	if !is_instance_valid(hitbox) or !is_instance_valid(body):
		return
		
	# Get metadata from hitbox
	var weapon_ref = hitbox.get_meta("weapon")
	var wielder_ref = hitbox.get_meta("wielder")
	var combo_level = hitbox.get_meta("current_combo", 0)
	var combo_mult = hitbox.get_meta("combo_multiplier", 1.15)
	
	if !weapon_ref or !wielder_ref or body == wielder_ref:
		return  # Skip if missing references or hitting self
	
	# Check for friendly fire
	var is_friendly = false
	if wielder_ref and "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	
	# Get friendly_fire setting from JSON flags
	var allows_friendly_fire = false
	if "weapon_data" in weapon_ref:
		if "flags" in weapon_ref.weapon_data:
			allows_friendly_fire = weapon_ref.weapon_data.flags.get("friendly_fire", false)
		else:
			# Fallback to metadata for backward compatibility
			allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false)
	
	# Skip friendly hits if friendly fire is disabled
	if is_friendly and !allows_friendly_fire:
		if DEBUG:
			print("Friendly fire prevented in dagger attack")
		return
	
	if DEBUG:
		print("Dagger hit detected: ", body.name)
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate direction
		var hit_dir = Vector2(1, 0)
		if wielder_ref.get_node("Sprite2D").flip_h:
			hit_dir = Vector2(-1, 0)
		
		# Calculate damage with combo multiplier
		var combo_factor = 1.0 + (combo_level * (combo_mult - 1.0))
		var effective_damage = int(weapon_ref.calculate_damage() * combo_factor)
		
		# Get knockback from JSON stats
		var knockback_force = 0.0
		if "weapon_data" in weapon_ref:
			if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
				knockback_force = float(weapon_ref.weapon_data.stats.knockback_force) * 0.7  # 70% for dagger
			else:
				knockback_force = float(get_param("knockback_force", 300.0)) * 0.7
		else:
			knockback_force = float(get_param("knockback_force", 300.0)) * 0.7
		
		if DEBUG:
			print("Dagger hit with combo level ", combo_level, 
				  " factor ", combo_factor, 
				  " damage ", effective_damage)
		
		# Add hit flash effect for more feedback
		create_hit_flash(body, combo_level, slash_colors)
		
		# Apply damage with calculated values
		body.take_damage(effective_damage, hit_dir, knockback_force)
		
		print(wielder_ref.name + " hits " + body.name + " with " + 
			  weapon_ref.get_weapon_name() + " (combo level: " + str(combo_level) + ")")
		
		# Apply weapon effects
		weapon_ref.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Create flash effect on hit target for better feedback
func create_hit_flash(body, combo_level, colors):
	var hit_flash = ColorRect.new()
	hit_flash.color = colors[min(combo_level, colors.size() - 1)]
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

# Helper to create a timer
func create_timer(parent_node, wait_time, target, method, binds = []):
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	parent_node.add_child(timer)
	
	# Connect the timeout signal
	if target and method:
		if binds.size() > 0:
			timer.timeout.connect(Callable(target, method).bind(binds))
		else:
			timer.timeout.connect(Callable(target, method))
	
	timer.start()
	return timer

# Helper to remove a node
func queue_free_node(node):
	if node and is_instance_valid(node):
		node.queue_free()

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
	# First check if weapon has one
	if weapon and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")
	
	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree() and wielder.get_tree().current_scene:
		var scene = wielder.get_tree().current_scene
		if scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")
	
	return null
