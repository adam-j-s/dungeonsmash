# Creates quick, short-range dagger attacks with combo potential - Enhanced for safety
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

# Execute attack with combo potential - enhanced for safety
func execute_attack():
	if DEBUG:
		print("Executing dagger attack with weapon: ", weapon.get_weapon_name() if is_instance_valid(weapon) else "Invalid weapon")

	if !is_instance_valid(wielder) or !is_instance_valid(weapon):
		if DEBUG:
			print("Missing wielder or weapon reference - cannot execute dagger attack")
		return false

	# Update aim direction using our enhanced method
	update_aim_direction()
	if DEBUG:
		print("Updated aim direction for dagger attack: ", aim_direction)

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
	var attack_direction = sign(aim_direction.x)
	hitbox.position.x = attack_direction * (shape.size.x / 2)

	# Store necessary data in hitbox metadata
	hitbox.set_meta("weapon", weapon)
	hitbox.set_meta("wielder", wielder)
	hitbox.set_meta("attack_direction", attack_direction)
	hitbox.set_meta("current_combo", current_combo)
	hitbox.set_meta("combo_multiplier", combo_multiplier)

	# Set collision property using base class method
	setup_hitbox_collisions(hitbox, false)  # false = don't include world

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

	# --- Signal Connection using Lambda ---
	# Use direct connect with lambda, including the safety check:
	var err = hitbox.connect("body_entered", func(body_that_entered):
		# Add safety check: Only call if the AttackStyle instance is still valid
		if is_instance_valid(self):
			# Call the target function with arguments in the desired order
			_on_dagger_hit(hitbox, body_that_entered)
	)
	if err != OK:
		printerr("Failed to connect dagger hitbox signal using lambda. Error: ", err)
	else:
		if DEBUG: print("Connected dagger hitbox signal directly using lambda.")
	# --- End Lambda Connection ---


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

	# Connect combo timer timeout using safe helper (no binds needed here)
	connect_signal_safe(combo_timer, "timeout", self, "_on_combo_timer_timeout")
	combo_timer.start()

	# Create a timer for hitbox cleanup
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = attack_duration
	wielder.add_child(timer)

	# Connect hitbox cleanup timer using safe helper (relies on bindv)
	connect_signal_safe(timer, "timeout", self, "_on_attack_timer_timeout", [hitbox, timer])
	timer.start()

	# Apply visual effects
	weapon.apply_effects(null, "visual")

	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()

	return true

# Handler for combo timer timeout
func _on_combo_timer_timeout():
	if current_combo > 0:
		current_combo = 0
		if DEBUG:
			print("Combo reset due to timeout")
	# Clean up the timer itself after it fires
	if is_instance_valid(combo_timer):
		combo_timer.queue_free()
		combo_timer = null


# Handler for attack timer timeout
# Arguments (hitbox, timer) are passed via binds in connect_signal_safe
func _on_attack_timer_timeout(hitbox, timer):
	if DEBUG:
		print("Timer expired, safely removing hitbox")

	# Use the standardized cleanup method from base AttackStyle
	cleanup_attack(hitbox, timer)

# Handler for dagger hit with enhanced safety
# Arguments (hitbox, body) are passed via the lambda connection
func _on_dagger_hit(hitbox, body):
	# --- DEBUG: Check if function is called ---
	if DEBUG: print("_on_dagger_hit called with hitbox: %s, body: %s" % [hitbox.name if is_instance_valid(hitbox) else "INVALID HITBOX", body.name if is_instance_valid(body) else "INVALID BODY"])

	# Safety checks first (using style's weapon/wielder and passed body)
	# Use 'is WispEnemy' check which we confirmed works
	if !is_instance_valid(body) or !is_instance_valid(weapon) or !is_instance_valid(wielder):
		if DEBUG: print("_on_dagger_hit: EXIT - Body, Style's Weapon, or Style's Wielder instance invalid.")
		return

	if body == wielder:
		if DEBUG: print("_on_dagger_hit: EXIT - Body is self (wielder).")
		return

	# Check the passed hitbox instance validity
	if !is_instance_valid(hitbox):
		if DEBUG: print("_on_dagger_hit: EXIT - The hitbox instance passed to the function is invalid.")
		return

	# --- DEBUG: Check if metadata exists (using the passed 'hitbox' argument) ---
	# Metadata should now be correctly set in execute_attack
	var has_weapon_meta = hitbox.has_meta("weapon")
	var has_wielder_meta = hitbox.has_meta("wielder")
	var has_combo_meta = hitbox.has_meta("current_combo")
	var has_multi_meta = hitbox.has_meta("combo_multiplier")
	var has_dir_meta = hitbox.has_meta("attack_direction")
	if DEBUG: print("_on_dagger_hit: Hitbox metadata check - weapon:%s, wielder:%s, combo:%s, multi:%s, dir:%s" % [has_weapon_meta, has_wielder_meta, has_combo_meta, has_multi_meta, has_dir_meta])

	# Get combo data from hitbox metadata (using the passed 'hitbox' argument)
	var weapon_ref = hitbox.get_meta("weapon", null)
	var wielder_ref = hitbox.get_meta("wielder", null)
	var combo_level = hitbox.get_meta("current_combo", 0)
	var combo_mult = hitbox.get_meta("combo_multiplier", 1.15)
	var attack_direction = hitbox.get_meta("attack_direction", sign(aim_direction.x)) # Fallback just in case

	# --- DEBUG: Check validity of fetched metadata ---
	if DEBUG: print("_on_dagger_hit: Fetched metadata - weapon_ref valid: %s, wielder_ref valid: %s" % [is_instance_valid(weapon_ref), is_instance_valid(wielder_ref)])

	# Additional safety checks for fetched references from metadata
	if not is_instance_valid(weapon_ref) or not is_instance_valid(wielder_ref):
		if DEBUG: print("_on_dagger_hit: EXIT - Invalid weapon or wielder reference from hitbox metadata.")
		return


	# Check for friendly fire (Using wielder_ref from metadata)
	var is_friendly = false
	# Check player_number exists before accessing
	if "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	var allows_friendly_fire = false
	# Check weapon_ref here (from metadata)
	if "weapon_data" in weapon_ref:
		if "flags" in weapon_ref.weapon_data:
			allows_friendly_fire = weapon_ref.weapon_data.flags.get("friendly_fire", false)
		else:
			allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false) # Fallback
	elif weapon_ref.has_meta("friendly_fire"): # Fallback if weapon_data missing
		allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false)

	if is_friendly and !allows_friendly_fire:
		if DEBUG: print("_on_dagger_hit: EXIT - Friendly fire prevented (IsFriendly: %s, AllowsFF: %s)." % [is_friendly, allows_friendly_fire])
		return

	# --- DEBUG: Passed all checks before take_damage ---
	if DEBUG: print("_on_dagger_hit: Passed all checks for body: %s" % body.name)

	# Check if the body can take damage
	var can_take_damage = body.has_method("take_damage")
	# --- DEBUG: Check take_damage method ---
	if DEBUG: print("_on_dagger_hit: Target '%s' has_method('take_damage'): %s" % [body.name, can_take_damage])

	if body.has_method("take_damage"):
		# Calculate direction (using attack_direction from metadata)
		var hit_dir = Vector2(attack_direction, 0)

		# Calculate damage with combo multiplier (using weapon_ref from metadata)
		var combo_factor = 1.0 + (combo_level * (combo_mult - 1.0))
		# Ensure calculate_damage exists on weapon_ref (from metadata)
		var effective_damage = 0
		if weapon_ref.has_method("calculate_damage"):
			effective_damage = int(weapon_ref.calculate_damage() * combo_factor)
		else:
			if DEBUG: print("_on_dagger_hit: WARNING - weapon_ref from metadata missing calculate_damage method!")
			effective_damage = int(10 * combo_factor) # Example fallback

		# Get knockback from JSON stats (using weapon_ref from metadata)
		var knockback_force = 0.0
		# Check structure carefully based on your JSON
		if "weapon_data" in weapon_ref and weapon_ref.weapon_data != null:
			if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
				knockback_force = float(weapon_ref.weapon_data.stats.knockback_force) * 0.7
			else: # Fallback within weapon_data if stats block missing
				knockback_force = float(get_param("knockback_force", 300.0)) * 0.7 # Using get_param from style context
		else: # Fallback if no weapon_data at all
			knockback_force = float(get_param("knockback_force", 300.0)) * 0.7 # Using get_param from style context

		# --- DEBUG: Check calculated values before applying ---
		if DEBUG: print("_on_dagger_hit: Calculated Values - Combo:%d, Factor:%.2f, Dmg:%d, KB:%.1f, Dir:%s" % [combo_level, combo_factor, effective_damage, knockback_force, str(hit_dir)])

		# Check if damage is zero, which would have no effect
		if effective_damage <= 0 and knockback_force <= 0:
			if DEBUG: print("_on_dagger_hit: Skipping take_damage call because damage and knockback are zero.")
			return

		# Add hit flash effect (as before)
		create_hit_flash(body, combo_level, slash_colors)

		# Apply damage
		if DEBUG: print("_on_dagger_hit: >>> Calling body.take_damage(%d, %s, %.1f) on %s <<<" % [effective_damage, str(hit_dir), knockback_force, body.name])
		body.take_damage(effective_damage, hit_dir, knockback_force)
		if DEBUG: print("_on_dagger_hit: --- body.take_damage() called ---")


		# Use wielder_ref and weapon_ref from metadata for the print statement
		print(wielder_ref.name + " hits " + body.name + " with " + weapon_ref.get_weapon_name() + " (combo level: " + str(combo_level) + ")")

		# Apply weapon effects (using weapon_ref from metadata)
		if weapon_ref.has_method("apply_effects"): weapon_ref.apply_effects(body, "hit")

		# Notify behaviors about hit (as before)
		notify_behaviors_on_hit(body)
	elif DEBUG:
		# Print reason if take_damage wasn't called
		print("_on_dagger_hit: EXIT - Target '%s' does not have take_damage() method." % body.name)
	# Stop execution here during debug
	# return
	# Stop execution here during debug
	# return # Uncomment this if the log spam is too much
# Handler for dagger hit with enhanced safety
# Arguments (hitbox, body) are passed via binds + signal emission
#func _on_dagger_hit(hitbox, body):
	## --- DEBUG: Check if function is called ---
	#if DEBUG: print("_on_dagger_hit called with hitbox: %s, body: %s" % [hitbox.name if is_instance_valid(hitbox) else "INVALID HITBOX", body.name if is_instance_valid(body) else "INVALID BODY"])
#
	## Safety checks first (using style's weapon/wielder and passed body)
	#if !is_instance_valid(body) or !is_instance_valid(weapon) or !is_instance_valid(wielder):
		#if DEBUG: print("_on_dagger_hit: EXIT - Body, Style's Weapon, or Style's Wielder instance invalid.")
		#return
#
	#if body == wielder:
		#if DEBUG: print("_on_dagger_hit: EXIT - Body is self (wielder).")
		#return
#
	## Check the passed hitbox instance validity
	#if !is_instance_valid(hitbox):
		#if DEBUG: print("_on_dagger_hit: EXIT - The hitbox instance passed to the function is invalid.")
		#return
#
	## --- DEBUG: Check if metadata exists (using the passed 'hitbox' argument) ---
	#var has_weapon_meta = hitbox.has_meta("weapon")
	#var has_wielder_meta = hitbox.has_meta("wielder")
	#var has_combo_meta = hitbox.has_meta("current_combo")
	#var has_multi_meta = hitbox.has_meta("combo_multiplier")
	#var has_dir_meta = hitbox.has_meta("attack_direction")
	#if DEBUG: print("_on_dagger_hit: Hitbox metadata check - weapon:%s, wielder:%s, combo:%s, multi:%s, dir:%s" % [has_weapon_meta, has_wielder_meta, has_combo_meta, has_multi_meta, has_dir_meta])
#
	## Get combo data from hitbox metadata (using the passed 'hitbox' argument)
	#var weapon_ref = hitbox.get_meta("weapon", null)
	#var wielder_ref = hitbox.get_meta("wielder", null)
	#var combo_level = hitbox.get_meta("current_combo", 0)
	#var combo_mult = hitbox.get_meta("combo_multiplier", 1.15)
	#var attack_direction = hitbox.get_meta("attack_direction", sign(aim_direction.x)) # Fallback just in case
#
	## --- DEBUG: Check validity of fetched metadata ---
	#if DEBUG: print("_on_dagger_hit: Fetched metadata - weapon_ref valid: %s, wielder_ref valid: %s" % [is_instance_valid(weapon_ref), is_instance_valid(wielder_ref)])
#
	## Additional safety checks for fetched references from metadata
	#if not is_instance_valid(weapon_ref) or not is_instance_valid(wielder_ref):
		#if DEBUG: print("_on_dagger_hit: EXIT - Invalid weapon or wielder reference from hitbox metadata.")
		#return
#
#
	## Check for friendly fire (Using wielder_ref from metadata)
	#var is_friendly = false
	#if "player_number" in wielder_ref and "player_number" in body:
		#is_friendly = body.player_number == wielder_ref.player_number
	#var allows_friendly_fire = false
	## Check weapon_ref here (from metadata)
	#if "weapon_data" in weapon_ref:
		#if "flags" in weapon_ref.weapon_data:
			#allows_friendly_fire = weapon_ref.weapon_data.flags.get("friendly_fire", false)
		#else:
			#allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false) # Fallback
	#elif weapon_ref.has_meta("friendly_fire"): # Fallback if weapon_data missing
		#allows_friendly_fire = weapon_ref.get_meta("friendly_fire", false)
#
	#if is_friendly and !allows_friendly_fire:
		#if DEBUG: print("_on_dagger_hit: EXIT - Friendly fire prevented (IsFriendly: %s, AllowsFF: %s)." % [is_friendly, allows_friendly_fire])
		#return
#
	## --- DEBUG: Passed all checks before take_damage ---
	#if DEBUG: print("_on_dagger_hit: Passed all checks for body: %s" % body.name)
#
	## Check if the body can take damage
	#var can_take_damage = body.has_method("take_damage")
	## --- DEBUG: Check take_damage method ---
	#if DEBUG: print("_on_dagger_hit: Target '%s' has_method('take_damage'): %s" % [body.name, can_take_damage])
#
	#if body.has_method("take_damage"):
		## Calculate direction (using attack_direction from metadata)
		#var hit_dir = Vector2(attack_direction, 0)
#
		## Calculate damage with combo multiplier (using weapon_ref from metadata)
		#var combo_factor = 1.0 + (combo_level * (combo_mult - 1.0))
		## Ensure calculate_damage exists on weapon_ref (from metadata)
		#var effective_damage = 0
		#if weapon_ref.has_method("calculate_damage"):
			#effective_damage = int(weapon_ref.calculate_damage() * combo_factor)
		#else:
			#if DEBUG: print("_on_dagger_hit: WARNING - weapon_ref from metadata missing calculate_damage method!")
			#effective_damage = int(10 * combo_factor) # Example fallback
#
		## Get knockback from JSON stats (using weapon_ref from metadata)
		#var knockback_force = 0.0
		## Check structure carefully based on your JSON
		#if "weapon_data" in weapon_ref and weapon_ref.weapon_data != null:
			#if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
				#knockback_force = float(weapon_ref.weapon_data.stats.knockback_force) * 0.7
			#else: # Fallback within weapon_data if stats block missing
				#knockback_force = float(get_param("knockback_force", 300.0)) * 0.7 # Using get_param from style context
		#else: # Fallback if no weapon_data at all
			#knockback_force = float(get_param("knockback_force", 300.0)) * 0.7 # Using get_param from style context
#
		## --- DEBUG: Check calculated values before applying ---
		#if DEBUG: print("_on_dagger_hit: Calculated Values - Combo:%d, Factor:%.2f, Dmg:%d, KB:%.1f, Dir:%s" % [combo_level, combo_factor, effective_damage, knockback_force, str(hit_dir)])
#
		## Check if damage is zero, which would have no effect
		#if effective_damage <= 0 and knockback_force <= 0:
			#if DEBUG: print("_on_dagger_hit: Skipping take_damage call because damage and knockback are zero.")
			#return
#
		## Add hit flash effect (as before)
		#create_hit_flash(body, combo_level, slash_colors)
#
		## Apply damage
		#if DEBUG: print("_on_dagger_hit: >>> Calling body.take_damage(%d, %s, %.1f) on %s <<<" % [effective_damage, str(hit_dir), knockback_force, body.name])
		#body.take_damage(effective_damage, hit_dir, knockback_force)
		#if DEBUG: print("_on_dagger_hit: --- body.take_damage() called ---")
#
#
		## Use wielder_ref and weapon_ref from metadata for the print statement
		#print(wielder_ref.name + " hits " + body.name + " with " + weapon_ref.get_weapon_name() + " (combo level: " + str(combo_level) + ")")
#
		## Apply weapon effects (using weapon_ref from metadata)
		#if weapon_ref.has_method("apply_effects"): weapon_ref.apply_effects(body, "hit")
#
		## Notify behaviors about hit (as before)
		#notify_behaviors_on_hit(body)
	#elif DEBUG:
		## Print reason if take_damage wasn't called
		#print("_on_dagger_hit: EXIT - Target '%s' does not have take_damage() method." % body.name)
#HERE

# Create flash effect on hit target for better feedback
func create_hit_flash(body, combo_level, colors):
	if !is_instance_valid(body):
		return

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
	if !is_instance_valid(parent):
		return

	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 8 + (current_combo * 4)
	particles.lifetime = attack_duration

	# Particle properties
	particles.direction = Vector2(direction, 0)
	particles.spread = 30
	particles.gravity = Vector2.ZERO
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
	# First check if weapon has one
	if is_instance_valid(weapon) and weapon.has_node("BehaviorManager"):
		return weapon.get_node("BehaviorManager")

	# Try to find in scene
	if is_instance_valid(wielder) and wielder.get_tree() and wielder.get_tree().current_scene:
		var scene = wielder.get_tree().current_scene
		if is_instance_valid(scene) and scene.has_node("BehaviorManager"):
			return scene.get_node("BehaviorManager")

	return null
