# WispEnemy.gd - Revised to better integrate with weapon system
extends CharacterBody2D
class_name WispEnemy

# States
enum AIState { IDLE, CHASING, ATTACKING }

# --- Exports ---
@export_group("Movement")
@export var move_speed: float = 300.0
@export var acceleration: float = 15.0   # How quickly velocity changes towards target
@export var damping: float = 0.96       # Air friction

@export_group("AI & Combat")
@export var sight_range: float = 600.0
@export var attack_range: float = 400.0
@export var preferred_attack_distance: float = 300.0 # Tries to stay around this distance
@export var wisp_weapon_id: String = "wisp_bolt" # ID for the weapon data to load
@export var fire_point_offset: Vector2 = Vector2(20, 0) # Relative to visual rotation

# AI decision timing - separate from weapon cooldown
@export var attack_decision_min_time: float = 0.5  # Minimum seconds between deciding to attack
@export var attack_decision_max_time: float = 1.5  # Maximum seconds between deciding to attack

# --- Internal Variables ---
var current_ai_state = AIState.IDLE
var state_timer: float = 0.0
var _target_node: Node2D = null
var target_velocity: Vector2 = Vector2.ZERO # Desired velocity based on AI state
var can_attack: bool = true
var attack_decision_timer: float = 0.0  # Time until AI decides to attack again

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
	# --- Setup Weapon FIRST ---
	initialize_weapon()
	if current_weapon == null:
		printerr("%s: Weapon init failed. Disabling." % name)
		set_physics_process(false)
		return

	# Collision Layer
	collision_layer = 8  # Set to ENEMY_LAYER (8)
	collision_mask = 1 | 2 | 4  # Collide with world (1) and players (2 & 4)
	print("%s: Initialized with collision_layer=%d, collision_mask=%d" % [name, collision_layer, collision_mask])
	
	# Add enemy to enemy group for tracking
	add_to_group("enemies")

	# Start in Idle state
	change_ai_state(AIState.IDLE)
	
	# Initialize attack decision timer
	reset_attack_decision_timer()
	
	set_physics_process(true)
	if DEBUG: print("%s Ready with Weapon '%s'." % [name, wisp_weapon_id])

func initialize_weapon():
	var existing_weapon = get_node_or_null("WispWeapon")
	if is_instance_valid(existing_weapon): existing_weapon.queue_free()
	
	current_weapon = Weapon.new()
	current_weapon.name = "WispWeapon"
	
	if WeaponDatabase.weapons.has(wisp_weapon_id):
		current_weapon.load_weapon(wisp_weapon_id)
		current_weapon.initialize(self)
		add_child(current_weapon)
		
		if current_weapon.has_signal("cooldown_completed"):
			if not current_weapon.is_connected("cooldown_completed", Callable(self, "_on_weapon_cooldown_complete")):
				var err = current_weapon.cooldown_completed.connect(_on_weapon_cooldown_complete)
				if err != OK: printerr("%s: Failed weapon cooldown connect! Err: %s" % [name, err])
		else: 
			print("%s: Weapon '%s' missing cooldown signal." % [name, wisp_weapon_id])
			can_attack = false
	else:
		printerr("%s: Weapon data '%s' not found!" % [name, wisp_weapon_id])
		if is_instance_valid(current_weapon): current_weapon.queue_free()
		current_weapon = null
		can_attack = false

func reset_attack_decision_timer():
	# Set a random time between min and max for AI to make next attack decision
	attack_decision_timer = randf_range(attack_decision_min_time, attack_decision_max_time)
	if DEBUG: print("%s: Attack decision timer reset to %.2f seconds" % [name, attack_decision_timer])

# --- Main Update Loop ---
func _physics_process(delta: float):
	# Skip if defeated
	if is_defeated:
		return
		
	# Update timers
	state_timer += delta
	if attack_decision_timer > 0:
		attack_decision_timer -= delta

	# --- AI State Machine (This part sets target_velocity) ---
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)

	# --- Calculate Final Velocity ---
	var avoidance_vector = calculate_avoidance()

	# Apply damping (air friction)
	velocity *= pow(damping, delta * 60.0)

	# Calculate the final desired velocity including AI target and avoidance
	var combined_target_velocity = target_velocity + avoidance_vector

	# --- Apply Acceleration using move_toward ---
	# Calculate the maximum change in velocity this frame based on acceleration
	# Note: We scale by move_speed here to make acceleration feel more like "time to reach max speed"
	var max_delta_velocity = acceleration * move_speed * delta
	# Move the current velocity towards the combined target velocity
	velocity = velocity.move_toward(combined_target_velocity, max_delta_velocity)

	# --- Movement ---
	move_and_slide() # Use the calculated velocity

	# --- Visual Rotation / Weapon Aim Update ---
	if is_instance_valid(_target_node):
		var aim_dir = (_target_node.global_position - global_position).normalized()
		if is_instance_valid(current_weapon): current_weapon.aim_direction = aim_dir
		if is_instance_valid(visual_node):
			visual_node.rotation = lerp_angle(visual_node.rotation, aim_dir.angle(), 3.0 * delta)

# --- State Processing Functions (Keep logic setting target_velocity) ---
func process_idle_state(_delta: float):
	target_velocity = Vector2.ZERO # Desire to stop
	if is_instance_valid(_target_node): change_ai_state(AIState.CHASING)
	elif state_timer > 1.0: find_target(); state_timer = 0.0

func process_chasing_state(_delta: float):
	if DEBUG: print("%s: In CHASING. Target Node: %s, Is Valid: %s" % [name, str(_target_node), is_instance_valid(_target_node)])
	if not is_instance_valid(_target_node):
		if DEBUG: print("%s: Target lost! Returning to IDLE." % name)
		change_ai_state(AIState.IDLE)
		_target_node = null
		target_velocity = Vector2.ZERO
		return
		
	# Check if target is defeated
	if "is_defeated" in _target_node and _target_node.is_defeated:
		change_ai_state(AIState.IDLE)
		_target_node = null
		target_velocity = Vector2.ZERO
		return
		
	if global_position.distance_squared_to(_target_node.global_position) > sight_range * sight_range:
		change_ai_state(AIState.IDLE)
		_target_node = null
		target_velocity = Vector2.ZERO
		return

	var target_pos = _target_node.global_position
	var current_pos = global_position
	var vector_to_target = target_pos - current_pos
	var distance_sq = vector_to_target.length_squared()
	var direction = vector_to_target.normalized()

	# Set the desired velocity based on distance
	if distance_sq > (preferred_attack_distance * 1.1) * (preferred_attack_distance * 1.1):
		target_velocity = direction * move_speed # Move towards
	elif distance_sq < (preferred_attack_distance * 0.9) * (preferred_attack_distance * 0.9):
		target_velocity = -direction * move_speed * 0.5 # Move away slowly
	else:
		target_velocity = Vector2.ZERO # Try to hover (damping will slow)

	# Check attack conditions
	if distance_sq < attack_range * attack_range and check_line_of_sight():
		change_ai_state(AIState.ATTACKING)

func process_attacking_state(_delta: float):
	# Validate target
	var target_still_valid = true
	if not is_instance_valid(_target_node): 
		target_still_valid = false
	else:
		# Check if target is defeated
		if "is_defeated" in _target_node and _target_node.is_defeated:
			target_still_valid = false
		else:
			var distance_sq = global_position.distance_squared_to(_target_node.global_position)
			if distance_sq > attack_range * attack_range * 1.1 or not check_line_of_sight():
				target_still_valid = false
				
	if not target_still_valid: 
		change_ai_state(AIState.CHASING)
		return

	# Desire to stop while attacking
	target_velocity = Vector2.ZERO 

	# Only attempt to fire if:
	# 1. The weapon cooldown is complete (can_attack = true)
	# 2. The AI decision timer has reached zero
	if can_attack and attack_decision_timer <= 0:
		if is_instance_valid(current_weapon):
			var attack_fired = current_weapon.perform_attack()
			if attack_fired:
				# Attack succeeded - weapon system handles its own cooldown
				can_attack = false
				
				# Reset AI decision timer for next attack
				reset_attack_decision_timer()
		else:
			printerr("%s: No weapon!" % name)
			can_attack = false

# Add a take_damage method
func take_damage(damage, knockback_dir, knockback_force):
	# Reduce health
	health -= damage
	print("%s took %d damage! Health: %d/%d" % [name, damage, health, max_health])
	
	# Visual feedback - flash red
	modulate = Color(1, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# Apply knockback
	velocity = knockback_dir * knockback_force * 0.5  # Reduced effect for enemy
	
	# Check if defeated
	if health <= 0 and !is_defeated:
		defeated()

# Add defeated method
func defeated():
	is_defeated = true
	print("%s defeated!" % name)
	
	# Disable AI
	set_physics_process(false)
	
	# Visual indication
	modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# Create a death effect
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
	
	# Remove after short delay
	await get_tree().create_timer(0.8).timeout
	queue_free()
	
# --- Obstacle Avoidance ---
func calculate_avoidance() -> Vector2:
	# Cast rays in several directions to detect obstacles
	var avoidance_force = Vector2.ZERO
	var ray_length = 60.0  # Length of detection rays
	var ray_directions = [
		Vector2(1, 0), Vector2(-1, 0),  # Horizontal
		Vector2(0, 1), Vector2(0, -1),  # Vertical
		Vector2(1, 1).normalized(), Vector2(-1, -1).normalized(),  # Diagonals
		Vector2(-1, 1).normalized(), Vector2(1, -1).normalized()
	]
	
	var space_state = get_world_2d().direct_space_state
	
	for direction in ray_directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + direction * ray_length,
			1,  # Just check world layer
			[self]  # Exclude self
		)
		
		var result = space_state.intersect_ray(query)
		if result:
			# Calculate how close the obstacle is
			var hit_distance = global_position.distance_to(result.position)
			var avoidance_power = 1.0 - (hit_distance / ray_length)  # Closer = stronger
			
			# Add force away from obstacle
			avoidance_force -= direction * avoidance_power * 150.0
	
	return avoidance_force

# --- Signal Callback from Weapon ---
func _on_weapon_cooldown_complete():
	can_attack = true
	if DEBUG: print("%s: Weapon cooldown complete." % name)

# --- Other Helpers ---
func check_line_of_sight() -> bool:
	# Cannot check LOS if there is no valid target
	if not is_instance_valid(_target_node):
		return false # No target means no LOS

	var space_state = get_world_2d().direct_space_state
	var target_point = _target_node.global_position
	# Use center if possible for more accurate check against larger targets
	if _target_node.has_method("get_center"):
		target_point = _target_node.get_center()

	# Define collision mask for LOS check (only check terrain)
	var los_collision_mask = 1  # World layer only

	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self]) # Exclude self
	var result = space_state.intersect_ray(query)

	# If ray hits nothing, LOS is clear
	if not result:
		return true

	# If the ray hit something, LOS is blocked
	return false
	
func change_ai_state(new_state: AIState):
	if DEBUG and current_ai_state != new_state: 
		print("%s: AI State -> %s" % [name, AIState.keys()[new_state]])
	current_ai_state = new_state
	state_timer = 0.0

func find_target():
	if is_instance_valid(_target_node) and global_position.distance_squared_to(_target_node.global_position) < sight_range * sight_range:
		if DEBUG: print("%s: Keeping existing target %s (in range)" % [name, _target_node.name if _target_node else "None"])
		return
		
	_target_node = null
	var potential_targets = get_tree().get_nodes_in_group("players")
	
	if DEBUG: print("%s: Looking for targets, found %d player(s) in group" % [name, potential_targets.size()])
	
	var closest_target: Node2D = null
	var min_dist_sq = sight_range * sight_range
	
	for target in potential_targets:
		if is_instance_valid(target) and target != self and target is Node2D:
			# Skip defeated targets
			if "is_defeated" in target and target.is_defeated:
				continue
				
			var target_pos = target.global_position
			var dist_sq = global_position.distance_squared_to(target_pos)
			
			if dist_sq < min_dist_sq:
				var has_los = check_line_of_sight_to_point(target_pos)
				if DEBUG: print("%s: Checking player %s, dist: %.1f, LOS: %s" % [name, target.name, sqrt(dist_sq), has_los])
				
				if has_los:
					min_dist_sq = dist_sq
					closest_target = target
	
	_target_node = closest_target
	if DEBUG: print("%s: Target search result: %s" % [name, _target_node.name if _target_node else "None"])
	
	if is_instance_valid(_target_node) and current_ai_state == AIState.IDLE:
		change_ai_state(AIState.CHASING)

func check_line_of_sight_to_point(target_point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	
	# Only check world layer (layer 1) for LOS blocking
	var los_collision_mask = 1  # World layer only - ignore characters
	
	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self])
	var result = space_state.intersect_ray(query)
	
	if DEBUG and result:
		print("%s: LOS check - Hit object: %s at distance %.1f" % [name, result.collider.name if result.collider else "Unknown", global_position.distance_to(result.position)])
	
	# If no collision with world, LOS is clear
	if not result:
		return true
	
	return false

func set_target(target: Node2D):
	if is_instance_valid(target):
		if DEBUG: print("%s: Target set to %s" % [name, target.name])
		_target_node = target
		if current_ai_state == AIState.IDLE: 
			change_ai_state(AIState.CHASING)
	else:
		if DEBUG: print("%s: Target set null." % name)
		_target_node = null
		if current_ai_state != AIState.IDLE: 
			change_ai_state(AIState.IDLE)

func get_wielder(): return self

func get_attack_direction_value() -> Vector2:
	if is_instance_valid(_target_node): 
		return (_target_node.global_position - global_position).normalized()
	else: 
		return Vector2.RIGHT.rotated(visual_node.rotation if is_instance_valid(visual_node) else rotation)
