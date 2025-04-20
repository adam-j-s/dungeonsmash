# WispEnemy.gd - Direct Movement + Avoidance + Wandering for Floating Enemy
extends CharacterBody2D
class_name WispEnemy

# States
enum AIState { IDLE, CHASING, ATTACKING, REPOSITIONING }

# --- Exports ---
@export_group("Movement")
@export var move_speed: float = 300.0
@export var acceleration: float = 15.0
@export var damping: float = 0.96
@export var avoidance_strength: float = 150.0
@export var avoidance_ray_length: float = 75.0
@export_group("Wandering (Idle State)")
@export var wander_speed_multiplier: float = 0.4 # e.g., 40% of move_speed
@export var wander_interval_min: float = 1.5 # Min seconds before changing direction
@export var wander_interval_max: float = 4.0 # Max seconds before changing direction

@export_group("AI & Combat")
@export var sight_range: float = 800.0
@export var attack_range: float = 600.0
@export var preferred_attack_distance: float = 400.0
@export var wisp_weapon_id: String = "wisp_bolt"
@export var fire_point_offset: Vector2 = Vector2(20, 0)
@export var attack_decision_min_time: float = 0.5
@export var attack_decision_max_time: float = 1.5
# --- New parameters for improved movement ---
@export var combat_movement_speed_multiplier: float = 0.3 # Movement speed during combat
@export var reposition_chance: float = 0.3 # Chance to reposition after attack
@export var reposition_min_time: float = 0.8 # Min time in repositioning state
@export var reposition_max_time: float = 2.0 # Max time in repositioning state
@export var min_attack_state_duration: float = 0.3 # Minimum time to stay in attack state
@export var preferred_distance_tolerance: float = 100.0 # How close to preferred distance is acceptable

# --- Internal Variables ---
var current_ai_state = AIState.IDLE
var state_timer: float = 0.0
var _target_node: Node2D = null
var target_velocity: Vector2 = Vector2.ZERO
var can_attack: bool = true
var attack_decision_timer: float = 0.0
# --- Wandering Variables ---
var wander_timer: float = 0.0
var current_wander_direction: Vector2 = Vector2.ZERO
var attack_state_timer = 0.0
var reposition_timer: float = 0.0
var reposition_direction: Vector2 = Vector2.ZERO

# Enemy Health system
@export var max_health: int = 40
var health: int = max_health
var is_defeated: bool = false

# --- Node References ---
@onready var visual_node = $Visual
var current_weapon: Weapon = null

# --- Constants ---
const DEBUG = true

# --- Initialization ---
func _ready():
	motion_mode = MOTION_MODE_FLOATING

	# Explicitly register the defeated signal
	if DEBUG: print("%s: Has defeated signal: %s" % [name, has_signal("defeated")])

	initialize_weapon()
	if current_weapon == null:
		printerr("%s: Weapon init failed. Disabling." % name)
		set_physics_process(false)
		return

	collision_layer = 8
	collision_mask = 1 | 2 | 4
	print("%s: Initialized with collision_layer=%d, collision_mask=%d" % [name, collision_layer, collision_mask])

	add_to_group("enemies")
	# Start in Idle state, which will immediately pick a wander target
	change_ai_state(AIState.IDLE)
	reset_attack_decision_timer()

	set_physics_process(true)
	if DEBUG: print("%s Ready with Weapon '%s'." % [name, wisp_weapon_id])

# --- Weapon Initialization (Enhanced with more debug info) ---
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
			
		# For testing: force perform an attack immediately
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


# --- Attack Timer Reset (Added debug info) ---
func reset_attack_decision_timer():
	attack_decision_timer = randf_range(attack_decision_min_time, attack_decision_max_time)
	if DEBUG: print("%s: Attack decision timer reset to %.2f seconds" % [name, attack_decision_timer])


# --- Main Update Loop ---
func _physics_process(delta: float):
	if is_defeated: return

	# Update timers
	state_timer += delta
	if attack_decision_timer > 0:
		attack_decision_timer -= delta

	# --- Handle Wander Timer if IDLE ---
	if current_ai_state == AIState.IDLE:
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_target()
			
	# --- Handle attack state timer ---
	if current_ai_state == AIState.ATTACKING:
		attack_state_timer += delta
		
	# --- Handle reposition timer ---
	if current_ai_state == AIState.REPOSITIONING:
		reposition_timer -= delta
		if reposition_timer <= 0:
			change_ai_state(AIState.CHASING)

	# --- AI State Machine (Sets target_velocity) ---
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)
		AIState.REPOSITIONING: process_repositioning_state(delta)

	# --- Calculate Avoidance Force ---
	var avoidance_vector = calculate_avoidance()

	# --- Calculate Final Velocity ---
	velocity *= pow(damping, delta * 60.0)
	var combined_target_velocity = target_velocity + avoidance_vector
	var max_delta_velocity = acceleration * move_speed * delta
	velocity = velocity.move_toward(combined_target_velocity, max_delta_velocity)

	# --- Movement ---
	move_and_slide()

	# --- Visual Rotation ---
	if is_instance_valid(_target_node): # Rotate towards target if chasing/attacking
		var aim_dir = (_target_node.global_position - global_position).normalized()
		if is_instance_valid(current_weapon): 
			current_weapon.aim_direction = aim_dir
			if DEBUG and current_ai_state == AIState.ATTACKING and fmod(state_timer, 1.0) < delta:
				print("%s: Aiming weapon at direction: %s" % [name, aim_dir])
		if is_instance_valid(visual_node):
			visual_node.rotation = lerp_angle(visual_node.rotation, aim_dir.angle(), 5.0 * delta)
	elif current_ai_state == AIState.IDLE and velocity.length_squared() > 1.0: # Rotate in wander direction if idle and moving
		if is_instance_valid(visual_node):
			visual_node.rotation = lerp_angle(visual_node.rotation, velocity.angle(), 2.0 * delta) # Slower rotation


# --- State Processing Functions ---
func process_idle_state(_delta: float):
	# Set velocity based on wandering direction
	target_velocity = current_wander_direction * move_speed * wander_speed_multiplier

	# Always check if a target becomes available
	find_target() # Check frequently when idle
	if is_instance_valid(_target_node):
		change_ai_state(AIState.CHASING)


func process_chasing_state(_delta: float):
	# Check if target is still valid
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE); return
	if "is_defeated" in _target_node and _target_node.is_defeated:
		change_ai_state(AIState.IDLE); _target_node = null; return

	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - global_position
	var distance_sq = vector_to_target.length_squared()
	var distance = sqrt(distance_sq)

	# Check if target is out of sight range
	if distance_sq > sight_range * sight_range:
		change_ai_state(AIState.IDLE); _target_node = null; return

	# Try to attack when in range - more balanced check
	if distance_sq < attack_range * attack_range:
		# Don't immediately attack - check line of sight
		if check_line_of_sight():
			if DEBUG: print("%s: In attack range, switching to ATTACKING state" % name)
			change_ai_state(AIState.ATTACKING)
			return

	# --- Direct Path Check ---
	var space_state = get_world_2d().direct_space_state
	var direction_to_target_norm = vector_to_target.normalized()
	var ray_origin = global_position
	var ray_target_pos = global_position + direction_to_target_norm * distance
	var collision_mask = 1
	var exclusions = [self, _target_node]

	var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_target_pos, collision_mask, exclusions)
	var hit_result = space_state.intersect_ray(query)
	var is_path_blocked_by_world = hit_result != null

	# --- Movement Logic Based on Preferred Distance ---
	var preferred_distance_diff = distance - preferred_attack_distance
	var move_strength = 1.0
	
	# If we're close to the preferred distance, reduce movement speed
	if abs(preferred_distance_diff) < preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / preferred_distance_tolerance

	# If path is blocked, use avoidance + general movement toward player
	if is_path_blocked_by_world:
		# Determine if target is above or below
		var player_is_above = target_pos.y < global_position.y
		
		# More balanced vertical movement
		if player_is_above:
			# Player is above, prioritize upward movement but don't overdo it
			var up_vector = Vector2(direction_to_target_norm.x * 0.6, -1.0).normalized()
			target_velocity = up_vector * move_speed * 1.2 # Reduced from 1.7
			
			if DEBUG and fmod(state_timer, 3.0) < _delta:
				print("%s: UPWARD movement toward player" % name)
		else:
			# Player is below, use more balanced downward movement
			var down_vector = Vector2(direction_to_target_norm.x * 0.6, 0.8).normalized()
			target_velocity = down_vector * move_speed
			
			if DEBUG and fmod(state_timer, 3.0) < _delta:
				print("%s: DOWNWARD movement toward player" % name)
	else:
		# Path is clear - determine direction based on preferred distance
		if abs(preferred_distance_diff) > preferred_distance_tolerance:
			if preferred_distance_diff > 0:
				# Too far, move toward player
				target_velocity = direction_to_target_norm * move_speed
				if DEBUG and fmod(state_timer, 3.0) < _delta:
					print("%s: Moving TOWARD player to reach preferred distance" % name)
			else:
				# Too close, back away from player
				target_velocity = -direction_to_target_norm * move_speed * 0.8
				if DEBUG and fmod(state_timer, 3.0) < _delta:
					print("%s: Moving AWAY from player to reach preferred distance" % name)
		else:
			# At good distance, slight orbital movement
			var orbit_dir = Vector2(-direction_to_target_norm.y, direction_to_target_norm.x)
			target_velocity = orbit_dir * move_speed * 0.5 * move_strength
			if DEBUG and fmod(state_timer, 3.0) < _delta:
				print("%s: ORBITAL movement at good distance" % name)

func process_attacking_state(_delta: float):
	# Increment attack state timer - already handled in _physics_process
	
	# Check if we've been in attack state long enough to consider a change
	if attack_state_timer >= min_attack_state_duration:
		# Check if target is still valid for attacking
		var target_still_valid = true
		if not is_instance_valid(_target_node): target_still_valid = false
		elif "is_defeated" in _target_node and _target_node.is_defeated: target_still_valid = false
		else:
			var distance_sq = global_position.distance_squared_to(_target_node.global_position)
			if distance_sq > attack_range * attack_range * 1.2:  # Slightly expanded range for better behavior
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
		if abs(preferred_distance_diff) > preferred_distance_tolerance * 1.5:
			if preferred_distance_diff < 0: # Too close
				target_velocity = -direction_to_target * move_speed * combat_movement_speed_multiplier
				if DEBUG and fmod(state_timer, 3.0) < _delta:
					print("%s: BACKING AWAY during attack" % name)
			else: # Too far
				target_velocity = direction_to_target * move_speed * combat_movement_speed_multiplier * 0.5
				if DEBUG and fmod(state_timer, 3.0) < _delta:
					print("%s: CLOSING IN during attack" % name)
		else:
			# Slight strafing movement when at good distance
			var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
			if randf() > 0.5: # Randomly reverse direction
				strafe_dir = -strafe_dir
				
			target_velocity = strafe_dir * move_speed * combat_movement_speed_multiplier * 0.7
			if DEBUG and fmod(state_timer, 3.0) < _delta:
				print("%s: STRAFING during attack" % name)
	else:
		target_velocity = Vector2.ZERO
	# --- End Movement Logic ---

	# --- Attack Logic ---
	# --- ENHANCED DEBUG PRINT FOR ATTACK CONDITIONS ---
	if DEBUG and fmod(state_timer, 0.5) < _delta: # Log twice per second to reduce spam
		print("%s: Attack Check: can_attack=%s, decision_timer=%.2f, target_in_range=%s, weapon_valid=%s" % 
			  [name, str(can_attack), attack_decision_timer, 
			   str(is_instance_valid(_target_node)), str(is_instance_valid(current_weapon))])
		
		if is_instance_valid(current_weapon):
			# Check if weapon has the perform_attack method
			if current_weapon.has_method("perform_attack"):
				print("%s: Weapon has perform_attack method" % name)
			else:
				print("%s: WARNING - Weapon is missing perform_attack method!" % name)
				
			# Check if the weapon has data
			if "weapon_data" in current_weapon:
				print("%s: Weapon has data with weapon_id: %s" % [name, current_weapon.weapon_id])
			else:
				print("%s: WARNING - Weapon is missing weapon_data!" % name)
	# --- END ENHANCED DEBUG PRINT ---

	if can_attack and (attack_decision_timer <= 0 or fmod(state_timer, 3.0) < _delta):
		if is_instance_valid(current_weapon):
			# Debug before attack
			if DEBUG: print("%s: Attempting to fire weapon" % name)
			
			# FORCE weapon to share our aim direction
			if is_instance_valid(_target_node):
				var aim_dir = (_target_node.global_position - global_position).normalized()
				current_weapon.aim_direction = aim_dir
				if DEBUG: print("%s: Set weapon aim direction to: %s" % [name, str(aim_dir)])
			
			# Aim weapon (happens in _physics_process)
			var attack_fired = current_weapon.perform_attack()
			
			# Debug after attack
			if DEBUG: print("%s: Attack result: %s" % [name, "SUCCESS" if attack_fired else "FAILED"])
			
			if attack_fired:
				can_attack = false
				reset_attack_decision_timer()
				attack_state_timer = 0.0
				
				# Consider a reposition after attack
				if randf() < reposition_chance:
					_start_repositioning()
		else:
			printerr("%s: No weapon!" % name)
			can_attack = false

# --- New function for repositioning behavior ---
func process_repositioning_state(_delta: float):
	# During repositioning, move in the reposition direction and check if target is still valid
	target_velocity = reposition_direction * move_speed
	
	# Continue checking if target is valid during repositioning
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	if "is_defeated" in _target_node and _target_node.is_defeated:
		change_ai_state(AIState.IDLE)
		_target_node = null
		return
		
	# Timer handling is in _physics_process

# --- Helper to start repositioning ---
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
		
		# Set timer
		reposition_timer = randf_range(reposition_min_time, reposition_max_time)
		
		if DEBUG: print("%s: REPOSITIONING for %.2f seconds in direction %s" % [name, reposition_timer, reposition_direction])
		change_ai_state(AIState.REPOSITIONING)

# --- Health and Defeat (Enhanced with more debug) ---
func take_damage(damage, knockback_dir, knockback_force):
	if is_defeated: return
	health -= damage
	print("%s took %d damage! Health: %d/%d" % [name, damage, health, max_health])
	modulate = Color(1, 0.3, 0.3, 1.0)
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	velocity += knockback_dir * knockback_force * 0.5
	if health <= 0 and !is_defeated: defeated()

func defeated():
	is_defeated = true
	print("%s defeated!" % name)
	emit_signal("defeated")
	print("%s: Emitted 'defeated' signal" % name)
	set_physics_process(false)
	# No nav agent signals to disconnect now
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
	await get_tree().create_timer(explosion.lifetime).timeout
	queue_free()


# --- Obstacle Avoidance ---
func calculate_avoidance() -> Vector2:
	var avoidance_force = Vector2.ZERO
	var current_avoidance_ray_length = avoidance_ray_length
	var current_avoidance_strength = avoidance_strength

	var ray_directions = [
		Vector2.RIGHT.rotated(rotation), Vector2.LEFT.rotated(rotation),
		Vector2.UP.rotated(rotation), Vector2.DOWN.rotated(rotation),
		(Vector2.RIGHT + Vector2.UP).normalized().rotated(rotation),
		(Vector2.LEFT + Vector2.DOWN).normalized().rotated(rotation),
		(Vector2.LEFT + Vector2.UP).normalized().rotated(rotation),
		(Vector2.RIGHT + Vector2.DOWN).normalized().rotated(rotation)
	]

	var space_state = get_world_2d().direct_space_state
	var avoidance_mask = 1 # World layer

	for direction in ray_directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + direction * current_avoidance_ray_length,
			avoidance_mask,
			[self]
		)
		var result = space_state.intersect_ray(query)

		if result:
			if "normal" in result and "position" in result:
				var hit_normal : Vector2 = result["normal"]
				var hit_distance = global_position.distance_to(result["position"])
				var avoidance_power = 1.0 - (hit_distance / current_avoidance_ray_length)

				# --- IMPROVED: More balanced vertical/horizontal avoidance ---
				# Check if the hit normal is primarily vertical
				if abs(hit_normal.y) > abs(hit_normal.x) * 1.5: # If normal is mostly up/down
					# Apply more force for vertical avoidance to prevent getting stuck
					avoidance_force += hit_normal * avoidance_power * current_avoidance_strength * 0.6 # Increased from 0.3
				else:
					# Apply full force for horizontal avoidance
					avoidance_force += hit_normal * avoidance_power * current_avoidance_strength
				# --- END Vertical Improvement ---

			else:
				printerr("%s: Avoidance ray hit, but result invalid! Dict: %s. Pushing opposite ray." % [name, result])
				avoidance_force -= direction * current_avoidance_strength * 0.5 # Fallback push

	return avoidance_force

# --- Signal Callback from Weapon (Enhanced with debug) ---
func _on_weapon_cooldown_complete():
	if DEBUG: print("%s: Weapon cooldown complete, can attack again" % name)
	can_attack = true

# --- Other Helpers ---
func check_line_of_sight() -> bool:
	if not is_instance_valid(_target_node): return false
	var space_state = get_world_2d().direct_space_state
	var target_point = _target_node.global_position
	if _target_node.has_method("get_center"): target_point = _target_node.get_center()
	elif _target_node.has_node("CollisionShape2D"):
		var shape_node = _target_node.get_node("CollisionShape2D")
		if is_instance_valid(shape_node): target_point = shape_node.global_position
	var los_collision_mask = 1
	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self])
	var result = space_state.intersect_ray(query)
	return not result

func change_ai_state(new_state: AIState):
	if DEBUG and current_ai_state != new_state:
		print("%s: AI State -> %s" % [name, AIState.keys()[new_state]])
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
		AIState.CHASING:
			# No specific initialization needed
			pass
		AIState.REPOSITIONING:
			# Initialization happens in _start_repositioning
			pass

func find_target():
	if is_instance_valid(_target_node):
		if global_position.distance_squared_to(_target_node.global_position) < sight_range * sight_range and check_line_of_sight(): return
	_target_node = null
	var potential_targets = get_tree().get_nodes_in_group("players")
	var closest_target: Node2D = null
	var min_dist_sq = sight_range * sight_range
	for target in potential_targets:
		if is_instance_valid(target) and target != self and target is Node2D:
			if "is_defeated" in target and target.is_defeated: continue
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

func check_line_of_sight_to_point(target_point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var los_collision_mask = 1
	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self])
	var result = space_state.intersect_ray(query)
	return not result

func set_target(target: Node2D):
	if is_instance_valid(target) and target != _target_node:
		if DEBUG: print("%s: Target set to %s" % [name, target.name])
		_target_node = target
		if current_ai_state == AIState.IDLE: change_ai_state(AIState.CHASING)
	elif not is_instance_valid(target) and is_instance_valid(_target_node):
		if DEBUG: print("%s: Target set null." % name)
		_target_node = null
		if current_ai_state != AIState.IDLE: change_ai_state(AIState.IDLE)

func get_wielder(): return self

func get_attack_direction_value() -> Vector2:
	if is_instance_valid(_target_node): return (_target_node.global_position - global_position).normalized()
	elif is_instance_valid(visual_node): return Vector2.RIGHT.rotated(visual_node.rotation)
	else: return Vector2.RIGHT.rotated(rotation)

# --- ADDED: Helper function for wandering ---
func _pick_new_wander_target():
	var random_angle = randf_range(0, TAU) # TAU is 2 * PI
	current_wander_direction = Vector2.RIGHT.rotated(random_angle)
	wander_timer = randf_range(wander_interval_min, wander_interval_max)
	if DEBUG: print("%s: Picked new wander direction: %s for %.2f seconds" % [name, current_wander_direction.round(), wander_timer])
