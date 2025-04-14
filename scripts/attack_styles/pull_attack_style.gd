# Creates attacks that pull enemies toward the wielder - Enhanced for safety
class_name PullAttackStyle
extends AttackStyle

var pull_range = Vector2(60, 40)
var pull_duration = 0.3
var pull_strength_multiplier = 0.5  # Pull attacks deal less damage but have utility
var damage_reduction = 0.7  # Pull attacks deal less damage but have utility
# Import CollisionUtils
const CollisionUtils = preload("res://scripts/collision_utils.gd")

func _init_style():
	# Initialize pull-specific properties from JSON structure
	
	# Get range from JSON or parameters
	if weapon and "weapon_data" in weapon:
		if "range" in weapon.weapon_data:
			pull_range = Vector2(
				float(weapon.weapon_data.range.get("x", 60)),
				float(weapon.weapon_data.range.get("y", 40))
			)
		else:
			pull_range = get_param("attack_range", Vector2(60, 40))
	else:
		pull_range = get_param("attack_range", Vector2(60, 40))
	
	# Get pull duration from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "pull_duration" in weapon.weapon_data.stats:
			pull_duration = float(weapon.weapon_data.stats.pull_duration)
		else:
			pull_duration = float(get_param("pull_duration", 0.3))
	else:
		pull_duration = float(get_param("pull_duration", 0.3))
		
	# Get pull strength multiplier from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "pull_strength" in weapon.weapon_data.stats:
			pull_strength_multiplier = float(weapon.weapon_data.stats.pull_strength)
		else:
			pull_strength_multiplier = float(get_param("pull_strength", 0.5))
	else:
		pull_strength_multiplier = float(get_param("pull_strength", 0.5))
	
	# Get damage reduction from JSON stats if available
	if weapon and "weapon_data" in weapon:
		if "stats" in weapon.weapon_data and "damage_reduction" in weapon.weapon_data.stats:
			damage_reduction = float(weapon.weapon_data.stats.damage_reduction)
		else:
			damage_reduction = float(get_param("damage_reduction", 0.7))
	else:
		damage_reduction = float(get_param("damage_reduction", 0.7))
	
	if DEBUG:
		print("Pull style initialized with range: ", pull_range)
	
func get_style_name() -> String:
	return "PullAttackStyle"

# Execute attack with proper signal handling - enhanced for safety
func execute_attack():
	if DEBUG:
		print("Executing pull attack with weapon: ", weapon.get_weapon_name() if is_instance_valid(weapon) else "Invalid weapon")
	
	if !is_instance_valid(wielder) or !is_instance_valid(weapon):
		print("Missing wielder or weapon reference - cannot execute pull attack")
		return false
	
	# Update aim direction using our enhanced method
	update_aim_direction()
	
	# Creates a hitbox that pulls enemies toward the player
	var pull_hitbox = Area2D.new()
	pull_hitbox.name = "PullHitbox"
	
	# Add a larger collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = pull_range
	collision.shape = shape
	pull_hitbox.add_child(collision)
	
	# Position in front of player
	var attack_direction = sign(aim_direction.x)
	pull_hitbox.position.x = attack_direction * (shape.size.x / 2)
	
	# Store attack direction in hitbox metadata
	pull_hitbox.set_meta("attack_direction", attack_direction)
	
	# Store weapon and wielder reference for hit callback
	pull_hitbox.set_meta("weapon", weapon)
	pull_hitbox.set_meta("wielder", wielder)
	
	# Set up collision - use CollisionUtils if available
	if CollisionUtils != null:
		CollisionUtils.setup_collision_mask(pull_hitbox, wielder, false)
	else:
		# Manual setup
		pull_hitbox.collision_layer = 0
		if wielder.name == "Player1":
			pull_hitbox.collision_mask = 4  # Detect Player 2
		else:
			pull_hitbox.collision_mask = 2  # Detect Player 1
	
	# Use our safe signal connection method
	connect_signal_safe(pull_hitbox, "body_entered", self, "_on_pull_hit")
	
	# Add visual effect for the pull (a brief line indicating the pull)
	var pull_visual = Line2D.new()
	pull_visual.width = 5
	pull_visual.default_color = Color(0.8, 0.2, 0.8, 0.7)  # Purple for pull
	pull_visual.add_point(Vector2.ZERO)
	pull_visual.add_point(Vector2(attack_direction * shape.size.x, 0))
	pull_hitbox.add_child(pull_visual)
	
	# Add particles for more visual impact
	create_pull_particles(pull_hitbox, attack_direction)
	
	# Add to wielder
	wielder.add_child(pull_hitbox)
	
	# Create a timer for cleanup
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = pull_duration
	wielder.add_child(timer)
	
	# Connect timer using our safe method
	connect_signal_safe(timer, "timeout", self, "_on_attack_timer_timeout", [pull_hitbox, timer])
	timer.start()
	
	# Apply visual effects
	weapon.apply_effects(null, "visual")
	
	# Notify behaviors that attack was executed
	notify_behaviors_on_attack()
	
	return true

# New handler for attack timer
func _on_attack_timer_timeout(hitbox, timer):
	# Use our enhanced cleanup method
	cleanup_hitbox_safe(hitbox, timer)

# Fixed handler for pull hit with enhanced safety
func _on_pull_hit(body):
	# Safety checks first
	if !is_instance_valid(body):
		return
	
	# Get the hitbox that triggered this callback
	var pull_hitbox = body.get_parent().get_node_or_null("PullHitbox")
	if !is_instance_valid(pull_hitbox):
		return
	
	# Get metadata from hitbox
	var weapon_ref = null
	var wielder_ref = null
	
	if pull_hitbox.has_meta("weapon"):
		weapon_ref = pull_hitbox.get_meta("weapon")
	
	if pull_hitbox.has_meta("wielder"):
		wielder_ref = pull_hitbox.get_meta("wielder")
	
	if !is_instance_valid(weapon_ref) or !is_instance_valid(wielder_ref):
		return  # Skip if missing references
	
	# Skip self hit
	if body == wielder_ref:
		return
	
	if DEBUG:
		print("Pull hit detected: ", body.name)
	
	# Check for friendly fire
	var is_friendly = false
	if "player_number" in wielder_ref and "player_number" in body:
		is_friendly = body.player_number == wielder_ref.player_number
	
	# Get friendly fire setting from JSON flags
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
			print("Friendly fire prevented in pull attack")
		return
	
	# Check if the body can take damage
	if body.has_method("take_damage"):
		# Calculate pull direction (toward player)
		var pull_dir = (wielder_ref.global_position - body.global_position).normalized()
		
		# Calculate reduced damage
		var effective_damage = int(weapon_ref.calculate_damage() * damage_reduction)
		
		# Apply minimal damage with low knockback
		body.take_damage(effective_damage, pull_dir, 50)
		
		# Direct position manipulation for pulling
		if body is CharacterBody2D:
			# Calculate pull distance based on weapon knockback
			var pull_strength = 0.0
			if "weapon_data" in weapon_ref:
				if "stats" in weapon_ref.weapon_data and "knockback_force" in weapon_ref.weapon_data.stats:
					pull_strength = float(weapon_ref.weapon_data.stats.knockback_force)
				else:
					pull_strength = float(get_param("knockback_force", 300.0))
			else:
				pull_strength = float(get_param("knockback_force", 300.0))
			
			var pull_distance = pull_dir * pull_strength * pull_strength_multiplier
			
			# Create a visual trail effect for the pull
			create_pull_trail(body, wielder_ref)
			
			# Apply direct position change
			body.global_position += pull_distance
			
			# Set velocity for smoother motion
			if "velocity" in body:
				body.velocity = pull_dir * pull_strength
			
			# Add stun effect
			create_stun_effect(body, 0.2)
		
		if DEBUG:
			print(wielder_ref.name + " pulls " + body.name + " with " + weapon_ref.get_weapon_name())
		
		# Apply hit effects
		weapon_ref.apply_effects(body, "hit")
		
		# Notify behaviors about hit
		notify_behaviors_on_hit(body)

# Create particle effects for pull visualization
func create_pull_particles(parent, direction):
	if !is_instance_valid(parent):
		return
		
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = pull_duration
	particles.explosiveness = 0.2
	particles.direction = Vector2(-direction, 0)
	particles.spread = 20
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 2.0
	particles.color = Color(0.8, 0.2, 0.8)  # Purple
	particles.position = Vector2(direction * pull_range.x, 0)
	
	parent.add_child(particles)
	particles.emitting = true

# Create a visual trail effect for the pull
func create_pull_trail(target, destination):
	if !is_instance_valid(target) or !is_instance_valid(destination):
		return
		
	# Create a trail of particles connecting the target to the destination
	var trail = Line2D.new()
	trail.default_color = Color(0.8, 0.2, 0.8, 0.5)  # Translucent purple
	trail.width = 3
	trail.add_point(target.global_position)
	trail.add_point(destination.global_position)
	
	# Add to scene
	var scene = target.get_tree().current_scene
	if is_instance_valid(scene):
		scene.add_child(trail)
		
		# Fade out
		var tween = trail.create_tween()
		tween.tween_property(trail, "modulate:a", 0.0, 0.2)
		
		# Remove after effect completes
		create_timer(
			trail,
			0.2,
			self,
			"remove_effect",
			[trail]
		)

# Create a brief stun effect on the target
func create_stun_effect(target, duration):
	if !is_instance_valid(target):
		return
		
	# Visual indicator for stun
	var stun_indicator = Sprite2D.new()
	
	# Use a simple ColorRect if no texture
	var rect = ColorRect.new()
	rect.color = Color(1, 1, 0, 0.7)  # Yellow
	rect.size = Vector2(10, 10)
	rect.position = Vector2(-5, -20)  # Above head
	stun_indicator.add_child(rect)
	
	# Add to target
	target.add_child(stun_indicator)
	
	# Create animation
	var tween = stun_indicator.create_tween()
	tween.tween_property(stun_indicator, "rotation", 2 * PI, duration)
	
	# Remove after duration
	create_timer(
		target,
		duration,
		self,
		"remove_effect",
		[stun_indicator]
	)
	
	# Apply stun effect on movement if possible
	if "velocity" in target:
		var original_velocity = target.velocity
		target.velocity = Vector2.ZERO
		
		# Restore movement after duration
		create_timer(
			target,
			duration,
			self,
			"restore_velocity",
			[target, original_velocity]
		)

# Restore velocity after stun
func restore_velocity(target, original_velocity):
	if target and is_instance_valid(target) and "velocity" in target:
		target.velocity = original_velocity * 0.5  # Reduced momentum after stun

# Remove an effect node
func remove_effect(effect):
	if effect and is_instance_valid(effect):
		effect.queue_free()

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
