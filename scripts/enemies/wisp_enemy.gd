# WispEnemy.gd - Using enhanced BaseEnemy with improved aggression
extends BaseEnemy
class_name WispEnemy

# --- Additional Exports Specific to Wisp ---
@export var wisp_weapon_id: String = "wisp_bolt"
@export var fire_point_offset: Vector2 = Vector2(20, 0)
@export var attack_range: float = 600.0  # Keep original attack range parameter

# --- Node References ---
@onready var visual_node = $Visual
var current_weapon: Weapon = null

# --- Constants ---
const DEBUG = true  # Keep debug mode enabled for better diagnostics

# --- Initialization ---
func _ready():
	# Explicitly call superclass ready
	super._ready()
	
	# Force floating motion mode
	motion_mode = MOTION_MODE_FLOATING
	
	# Initialize weapon
	initialize_weapon()
	if current_weapon == null:
		printerr("%s: Weapon init failed. Disabling." % name)
		set_physics_process(false)
		return

	# Setup collision layers
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	
	if DEBUG: print("%s: Initialized with collision_layer=%d, collision_mask=%d" % [name, collision_layer, collision_mask])
	
	# Group for targeting
	add_to_group("enemies")
	
	# Set initial state
	change_ai_state(AIState.IDLE)
	
	# Initialize attack timers
	attack_decision_timer = 0.0
	can_attack = true
	
	if DEBUG: print("%s Ready with Weapon '%s'." % [name, wisp_weapon_id])

# --- Weapon Initialization ---
func initialize_weapon():
	var existing_weapon = get_node_or_null("WispWeapon")
	if is_instance_valid(existing_weapon): 
		if DEBUG: print("%s: Removing existing weapon '%s'" % [name, existing_weapon.name])
		existing_weapon.queue_free()
	
	current_weapon = Weapon.new()
	current_weapon.name = "WispWeapon"
	
	if DEBUG: print("%s: Checking for weapon ID '%s' in WeaponDatabase" % [name, wisp_weapon_id])
	
	if WeaponDatabase.weapons.has(wisp_weapon_id):
		if DEBUG: print("%s: Found weapon ID in database, loading '%s'" % [name, wisp_weapon_id])
		current_weapon.load_weapon(wisp_weapon_id)
		current_weapon.initialize(self)
		add_child(current_weapon)
		
		if DEBUG: 
			print("%s: Weapon initialized and added as child" % name)
			if "weapon_data" in current_weapon:
				print("%s: Weapon data: %s" % [name, str(current_weapon.weapon_data)])
		
		if current_weapon.has_signal("cooldown_completed"):
			if not current_weapon.is_connected("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete")):
				if DEBUG: print("%s: Connecting cooldown signal" % name)
				var err = current_weapon.cooldown_completed.connect(_on_weapon_cooldown_complete)
				if err != OK: printerr("%s: Failed weapon cooldown connect! Err: %s" % [name, err])
			else:
				if DEBUG: print("%s: Cooldown signal already connected" % name)
		else: 
			print("%s: Weapon '%s' missing cooldown signal." % [name, wisp_weapon_id])
			can_attack = false
			
		# For testing: force perform an attack immediately (like in original)
		if DEBUG:
			print("%s: Testing weapon by executing attack" % name)
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(current_weapon) and current_weapon.has_method("perform_attack"):
				var test_result = current_weapon.perform_attack()
				print("%s: Test attack result: %s" % [name, "SUCCESS" if test_result else "FAILED"])
	else: 
		printerr("%s: Weapon data '%s' not found!" % [name, wisp_weapon_id])
		if is_instance_valid(current_weapon): 
			current_weapon.queue_free()
			current_weapon = null
		can_attack = false

# --- Signal Callback from Weapon ---
func _on_weapon_cooldown_complete():
	if DEBUG: print("%s: Weapon cooldown complete, can attack again" % name)
	can_attack = true

# --- Attack Timer Reset (Added debug info) ---
func reset_attack_decision_timer():
	attack_decision_timer = randf_range(0.2, 0.8)  # Use shorter attack decision times (more aggressive)
	if DEBUG: print("%s: Attack decision timer reset to %.2f seconds" % [name, attack_decision_timer])

# --- Custom Visual Update ---
func _physics_process(delta):
	# First call parent physics process
	super._physics_process(delta)
	
	# Decrease attack decision timer (not handled in parent class)
	if attack_decision_timer > 0:
		attack_decision_timer -= delta
	
	# Update visual rotation based on target or movement direction
	if is_instance_valid(_target_node): # Rotate towards target if chasing/attacking
		var aim_dir = (_target_node.global_position - global_position).normalized()
		if is_instance_valid(current_weapon): 
			current_weapon.aim_direction = aim_dir
			if DEBUG and current_ai_state == AIState.ATTACKING and fmod(state_timer, 1.0) < delta:
				print("%s: Aiming weapon at direction: %s" % [name, aim_dir])
		if is_instance_valid(visual_node):
			visual_node.rotation = lerp_angle(visual_node.rotation, aim_dir.angle(), 5.0 * delta)
	elif velocity.length_squared() > 1.0: # Rotate in movement direction if moving
		if is_instance_valid(visual_node):
			visual_node.rotation = lerp_angle(visual_node.rotation, velocity.angle(), 2.0 * delta) # Slower rotation

# --- Specialized Find Target Implementation ---
func find_target():
	# Keep current target if already valid and in range
	if is_instance_valid(_target_node):
		if global_position.distance_squared_to(_target_node.global_position) < sight_range * sight_range and check_line_of_sight(): 
			return
			
	# Reset target and find closest
	_target_node = null
	var potential_targets = get_tree().get_nodes_in_group("players")
	var closest_target: Node2D = null
	var min_dist_sq = sight_range * sight_range
	
	for target in potential_targets:
		if is_instance_valid(target) and target != self and target is Node2D:
			if "is_defeated" in target and target.is_defeated: 
				continue
				
			var dist_sq = global_position.distance_squared_to(target.global_position)
			if dist_sq < min_dist_sq:
				if check_line_of_sight_to_point(target.global_position):
					min_dist_sq = dist_sq
					closest_target = target
					
	_target_node = closest_target
	
	if DEBUG and fmod(state_timer, 1.0) < 0.01:  # Log less frequently to reduce spam
		print("%s: Target search result: %s" % [name, _target_node.name if _target_node else "None"])
		
	if is_instance_valid(_target_node) and current_ai_state == AIState.IDLE:
		change_ai_state(AIState.CHASING)

# --- Override Attacking State to Use Wisp's Weapon ---
func process_attacking_state(delta):
	# Check if we've been in attack state long enough to consider a change
	if attack_state_timer >= min_attack_state_duration:
		# Check if target is still valid for attacking
		var target_still_valid = true
		if not is_instance_valid(_target_node): target_still_valid = false
		elif "is_defeated" in _target_node and _target_node.is_defeated: target_still_valid = false
		else:
			var distance_sq = global_position.distance_squared_to(_target_node.global_position)
			if distance_sq > attack_range * attack_range * 1.2:  # Use our specific attack range
				target_still_valid = false
				if DEBUG: print("%s: Target out of range, returning to chase" % name)

		if not target_still_valid:
			attack_state_timer = 0.0 # Reset timer
			change_ai_state(AIState.CHASING)
			return
	
	# --- Movement Logic (Allow some movement during attack) ---
	if is_instance_valid(_target_node):
		var direction_to_target = (_target_node.global_position - global_position).normalized()
		
		# Get distance to target for movement decisions
		var distance = global_position.distance_to(_target_node.global_position)
		var preferred_distance_diff = distance - preferred_attack_distance
		
		# Move to maintain preferred distance
		if abs(preferred_distance_diff) > preferred_distance_tolerance:
			# Too far from player - ALWAYS move directly toward at full speed
			target_velocity = direction_to_target * move_speed * 1.2 # Boost chase speed by 20%
			if DEBUG and fmod(state_timer, 3.0) < delta:
				print("%s: DIRECT PURSUIT toward player" % name)
		else:
			# Close enough - use more aggressive strafing for position advantage
			var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
			if randf() > 0.5: # Randomly reverse direction
				strafe_dir = -strafe_dir
	
			# Mix of strafe and forward movement instead of pure orbital
			target_velocity = (strafe_dir * 0.4 + direction_to_target * 0.6) * move_speed
			if DEBUG and fmod(state_timer, 3.0) < delta:
				print("%s: AGGRESSIVE POSITIONING at close range" % name)
	else:
		target_velocity = Vector2.ZERO
	
	# --- Attack Logic (More aggressive like original) ---
	if can_attack and (attack_decision_timer <= 0 or fmod(state_timer, 3.0) < delta):
		if is_instance_valid(current_weapon) and is_instance_valid(_target_node):
			# Debug before attack
			if DEBUG: print("%s: Attempting to fire weapon" % name)
			
			# FORCE weapon to share our aim direction
			var aim_dir = (_target_node.global_position - global_position).normalized()
			current_weapon.aim_direction = aim_dir
			if DEBUG: print("%s: Set weapon aim direction to: %s" % [name, str(aim_dir)])
			
			# Perform the attack
			var attack_fired = current_weapon.perform_attack()
			
			# Debug after attack
			if DEBUG: print("%s: Attack result: %s" % [name, "SUCCESS" if attack_fired else "FAILED"])
			
			if attack_fired:
				can_attack = false
				reset_attack_decision_timer()
				attack_state_timer = 0.0
				
				# Consider a reposition after attack (use lower chance for more aggression)
				if randf() < 0.2:  # Lower reposition chance (was 0.3)
					_start_repositioning()
		else:
			printerr("%s: No weapon or target!" % name)
			can_attack = false

# --- Override Process Chasing to Use Custom Attack Range ---
func process_chasing_state(delta):
	# Check if target is still valid
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
		
	if "is_defeated" in _target_node and _target_node.is_defeated:
		change_ai_state(AIState.IDLE)
		_target_node = null
		return

	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - global_position
	var distance_sq = vector_to_target.length_squared()
	var distance = sqrt(distance_sq)

	# Check if target is out of sight range
	if distance_sq > sight_range * sight_range:
		change_ai_state(AIState.IDLE)
		_target_node = null
		return

	# Try to attack when in range - using our custom attack range
	if distance_sq < attack_range * attack_range:
		# Check line of sight
		if check_line_of_sight():
			if DEBUG: print("%s: In attack range, switching to ATTACKING state" % name)
			change_ai_state(AIState.ATTACKING)
			return

	# Movement behavior from parent class
	super.process_chasing_state(delta)

# --- Repositioning Helper ---
func _start_repositioning():
	# Pick a direction to reposition (perpendicular to player direction + random element)
	if is_instance_valid(_target_node):
		var dir_to_target = (_target_node.global_position - global_position).normalized()
		
		# Create perpendicular vector (orbit direction)
		var perp = Vector2(-dir_to_target.y, dir_to_target.x)
		
		# Randomly choose clockwise or counter-clockwise
		if randf() > 0.5:
			perp = -perp
			
		# Add a slight angle variation
		var angle_offset = randf_range(-PI/4, PI/4)
		reposition_direction = perp.rotated(angle_offset)
		
		# Set timer - shorter repositioning for more aggression
		reposition_timer = randf_range(0.5, 1.2)
		
		if DEBUG: print("%s: REPOSITIONING for %.2f seconds in direction %s" % [name, reposition_timer, reposition_direction])
		change_ai_state(AIState.REPOSITIONING)

# --- Custom Death Effects ---
func play_death_effects():
	# First call the parent method
	super.play_death_effects()
	
	# Add custom death effects for wisp
	modulate = Color(0.5, 0.5, 0.5, 0.7)
	var explosion = CPUParticles2D.new()
	explosion.amount = 30
	explosion.lifetime = 0.7
	explosion.explosiveness = 0.9
	explosion.direction = Vector2(0, -1)
	explosion.spread = 180
	explosion.initial_velocity_min = 50
	explosion.initial_velocity_max = 150
	explosion.scale_amount_min = 2.0
	explosion.scale_amount_max = 4.0
	explosion.color = Color(0.9, 0.4, 1.0)
	add_child(explosion)
	explosion.emitting = true

# --- Override State Change to Force Immediate Attack ---
func change_ai_state(new_state: AIState):
	if DEBUG and current_ai_state != new_state:
		print("%s: AI State -> %s" % [name, AIState.keys()[new_state]])
	
	previous_ai_state = current_ai_state
	current_ai_state = new_state
	state_timer = 0.0
	
	# State-specific initialization
	match new_state:
		AIState.IDLE:
			_pick_new_wander_target()
		AIState.ATTACKING:
			attack_state_timer = 0.0  # Reset attack state timer
			attack_decision_timer = 0.0  # Force immediate attack decision
			if DEBUG: print("%s: Reset attack timer for immediate attack attempt" % name)
		AIState.REPOSITIONING:
			# Handled in _start_repositioning
			pass
		AIState.CHASING:
			# No specific initialization needed
			pass
		AIState.STUNNED:
			# Stop movement immediately when stunned
			target_velocity = Vector2.ZERO
			velocity = Vector2.ZERO

# --- Helper Methods ---
func get_wielder():
	return self

func get_attack_direction_value() -> Vector2:
	if is_instance_valid(_target_node): 
		return (_target_node.global_position - global_position).normalized()
	elif is_instance_valid(visual_node): 
		return Vector2.RIGHT.rotated(visual_node.rotation)
	else: 
		return Vector2.RIGHT.rotated(rotation)
