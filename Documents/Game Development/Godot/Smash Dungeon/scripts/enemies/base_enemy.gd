# Enhanced with improved movement, state handling, and centralized weapon system
extends CharacterBody2D
class_name BaseEnemy

# Signals
signal defeated
signal health_changed(current, maximum)
signal attack_performed(attack_type, damage)

# Enhanced State System
enum AIState { IDLE, CHASING, ATTACKING, REPOSITIONING, FLEEING, STUNNED }

# --- Base Stats ---
@export_group("Base Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var acceleration: float = 10.0
@export var damping: float = 0.9
@export_group("Physics")

# --- Weapon System ---
@export_group("Weapon System")
@export var weapon_id: String = ""  # Default weapon ID, empty means no weapon
@onready var weapon_system = $WeaponSystem

# --- Combat Parameters ---
@export_group("Combat Parameters")
@export var sight_range: float = 600.0
@export var preferred_attack_distance: float = 200.0
@export var preferred_distance_tolerance: float = 50.0
@export var combat_movement_speed_multiplier: float = 0.5
@export var reposition_chance: float = 0.3
@export var reposition_min_time: float = 0.8
@export var reposition_max_time: float = 2.0
@export var min_attack_state_duration: float = 0.5

# --- Aggression Parameters ---
@export_group("Aggression Parameters")
@export var chase_speed_multiplier: float = 1.2  # How much faster the enemy moves when chasing
@export var direct_chase: bool = false  # If true, moves directly toward player instead of orbiting
@export var chase_jump_chance: float = 0.0  # Chance per second to jump during chase
@export var chase_jump_force: float = 300.0  # Force applied when jumping during chase
@export var aggression_level: float = 0.5  # Overall aggression (0.0 - 1.0) - affects multiple behaviors

# --- Attack Behavior Parameters ---
@export_group("Attack Behavior")
@export var attack_commitment: float = 0.5  # How committed enemy is during attack (0.0-1.0)
@export var post_attack_pause: float = 0.0  # Seconds to pause after attacking
@export var attack_retreat_distance: float = 0.0  # Distance to retreat after attacking
@export var attack_frequency: float = 1.0  # Multiplier for attack cooldowns (lower = more frequent)
@export var attack_telegraph_enabled: bool = false  # Whether attacks have telegraph
@export var attack_telegraph_time: float = 0.3  # How long to telegraph attacks

# --- Avoidance System ---
@export_group("Avoidance System")
@export var use_avoidance: bool = true
@export var avoidance_strength: float = 150.0
@export var avoidance_ray_length: float = 75.0
@export var vertical_avoidance_factor: float = 0.6  # How strongly to avoid vertical obstacles

# --- Wandering Behavior ---
@export_group("Wandering Behavior")
@export var wander_speed_multiplier: float = 0.4
@export var wander_interval_min: float = 1.5
@export var wander_interval_max: float = 4.0

# --- Attack Definitions ---
@export_group("Attack Definitions")
@export var attack_types: Dictionary = {
	"melee": {
		"damage": 10,
		"cooldown": 1.0,
		"range": 50.0
	},
	"ranged": {
		"damage": 5,
		"cooldown": 2.0,
		"range": 200.0,
		"projectile": ""  # Path to projectile scene if needed
	}
	# Add more attack types as needed
}

# --- Add Config to Enemy
var config: EnemyConfig = null

# --- Internal State Tracking ---
var current_ai_state = AIState.IDLE
var previous_ai_state = AIState.IDLE
var state_timer: float = 0.0
var attack_state_timer: float = 0.0
var reposition_timer: float = 0.0
var wander_timer: float = 0.0

# --- Movement Variables ---
var target_velocity: Vector2 = Vector2.ZERO
var reposition_direction: Vector2 = Vector2.ZERO
var current_wander_direction: Vector2 = Vector2.ZERO

# --- Combat Variables ---
var _target_node = null  # Reference to player or other target
var attack_cooldowns: Dictionary = {}
var can_attack: bool = true
var attack_decision_timer: float = 0.0

# --- Health and State ---
var current_health: int
var _is_defeated: bool = false

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var use_gravity: bool = true

# --- Debugging ---
@export var debug_mode: bool = false

# Called when the node enters the scene tree for the first time
func _ready():
	current_health = max_health

	# Create weapon system if it doesn't exist
	if not has_node("WeaponSystem"):
		var new_weapon_system = EnemyWeaponSystem.new()
		new_weapon_system.name = "WeaponSystem"
		add_child(new_weapon_system)
		weapon_system = new_weapon_system
	
	# Initialize weapon system if weapon ID is set
	if weapon_system and weapon_id != "":
		weapon_system.initialize(self, weapon_id)
		
		# Connect to weapon system signals
		if not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
			weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)
	
	# Basic initialization - can be overridden by child classes
	initialize()

# Signal callback for weapon cooldown
func _on_weapon_cooldown_complete():
	can_attack = true
	if debug_mode:
		print("%s: Weapon cooldown complete" % name)

# Call this AFTER attack_types has been set by the config
func _initialize_attack_cooldowns():
	# Clear any old cooldowns in case types were changed
	attack_cooldowns.clear()
	# Initialize cooldowns based on the CURRENT attack_types dictionary
	if attack_types: # Check if attack_types is not null
		for attack_type_key in attack_types:
			attack_cooldowns[attack_type_key] = 0.0 # Start ready
	else:
		pass

# Virtual method for child classes to override without affecting _ready
func initialize():
	pass

# Main physics process
func _physics_process(delta):
	if _is_defeated:
		return

	# Update timers
	state_timer += delta
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta

	# Update state-specific timers
	if current_ai_state == AIState.ATTACKING:
		attack_state_timer += delta
	elif current_ai_state == AIState.REPOSITIONING:
		reposition_timer -= delta
		if reposition_timer <= 0:
			change_ai_state(AIState.CHASING)
	elif current_ai_state == AIState.IDLE:
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_target()

	# Process current AI state
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)
		AIState.REPOSITIONING: process_repositioning_state(delta)
		AIState.FLEEING: process_fleeing_state(delta)
		AIState.STUNNED: process_stunned_state(delta)

	# Calculate avoidance force if enabled
	var avoidance_vector = Vector2.ZERO
	if use_avoidance:
		avoidance_vector = calculate_avoidance()

	# Apply gravity if not floating and gravity is enabled
	if not is_on_floor() and motion_mode != MOTION_MODE_FLOATING and use_gravity:
		velocity.y += gravity * delta

	# Calculate final velocity with dampening and acceleration
	velocity *= pow(damping, delta * 60.0)
	var combined_target_velocity = target_velocity + avoidance_vector
	var max_delta_velocity = acceleration * move_speed * delta
	velocity = velocity.move_toward(combined_target_velocity, max_delta_velocity)

	# Apply movement
	move_and_slide()
	
	# Update weapon position if we have a weapon system
	if weapon_system:
		weapon_system.update_position()

	# Additional logic for child classes
	perform_ai_logic(delta)

# --- State Processing Functions (Virtual) ---

# Process idle state behavior
func process_idle_state(_delta: float):
	# Set velocity based on wandering direction
	target_velocity = current_wander_direction * move_speed * wander_speed_multiplier

	# Check if a target becomes available
	find_target()

# Process chasing state behavior
func process_chasing_state(_delta: float):
	# Skip if no target
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return

	# Get target position and calculate distance
	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - global_position
	var distance_sq = vector_to_target.length_squared()
	var distance = sqrt(distance_sq)

	# Direction to target
	var direction_to_target = vector_to_target.normalized()

	# Calculate preferred distance difference
	var preferred_distance_diff = distance - preferred_attack_distance
	var move_strength = 1.0

	# If we're close to the preferred distance, reduce movement speed
	if abs(preferred_distance_diff) < preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / preferred_distance_tolerance

	# Decide movement strategy based on aggression parameters and distance
	if direct_chase or abs(preferred_distance_diff) > preferred_distance_tolerance * (2.0 - aggression_level):
		# Direct approach or retreat based on preferred distance
		if preferred_distance_diff > 0:
			# Too far, move directly toward player (more aggressively with higher aggression)
			var approach_speed = move_speed * chase_speed_multiplier * (1.0 + aggression_level * 0.5)
			target_velocity = direction_to_target * approach_speed
			if debug_mode and fmod(state_timer, 3.0) < _delta:
				print("%s: Moving TOWARD target with aggression level %.1f" % [name, aggression_level])
		else:
			# Too close, back away from player (less strongly with higher aggression)
			var retreat_factor = max(0.2, 1.0 - aggression_level * 0.8)
			target_velocity = -direction_to_target * move_speed * 0.8 * retreat_factor
			if debug_mode and fmod(state_timer, 3.0) < _delta:
				print("%s: Moving AWAY from target (retreat factor: %.2f)" % [name, retreat_factor])
	else:
		# At good distance, orbital movement (less pronounced with higher aggression)
		var orbit_factor = max(0.2, 1.0 - aggression_level * 0.7)
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x)
		target_velocity = orbit_dir * move_speed * 0.5 * move_strength * orbit_factor
		if debug_mode and fmod(state_timer, 3.0) < _delta:
			print("%s: ORBITAL movement at good distance (orbit factor: %.2f)" % [name, orbit_factor])

	# Random jumps during chase if enabled
	if is_on_floor() and randf() < chase_jump_chance * _delta:
		velocity.y = -chase_jump_force
		if debug_mode:
			print("%s: Performed chase jump with force %.1f" % [name, chase_jump_force])

	# Check if within attack range
	# First check with the weapon system if available
	if weapon_system and is_instance_valid(_target_node):
		var weapon_range = weapon_system.get_attack_range()
		if distance <= weapon_range and check_line_of_sight() and weapon_system.can_attack():
			if debug_mode:
				print("%s: In weapon range for attack: %.1f" % [name, weapon_range])
			change_ai_state(AIState.ATTACKING)
			return
	
	# Fallback to attack_types if no weapon system
	for attack_type in attack_types:
		var attack = attack_types[attack_type]
		var attack_range = attack.get("range", 50.0)

		# More aggressive enemies will attack from further away
		var effective_attack_range = attack_range * (1.0 + aggression_level * 0.3)

		if distance <= effective_attack_range and check_line_of_sight():
			if debug_mode:
				print("%s: Attacking from range %.1f (base range %.1f)" % [name, effective_attack_range, attack_range])
			# Ensure the attack type exists before trying to use it
			if can_use_attack(attack_type): # Check cooldown here before changing state
				change_ai_state(AIState.ATTACKING)
				break # Only initiate one attack type check per frame

# Process attacking state behavior
func process_attacking_state(_delta: float):
	# Check if we've been in attack state long enough
	if attack_state_timer >= min_attack_state_duration:
		# Check if target is still valid
		if not is_instance_valid(_target_node):
			attack_state_timer = 0.0
			change_ai_state(AIState.CHASING)
			return

		# Check if target is still in range
		var still_in_range = false
		var closest_attack_range = 1000.0
		
		# Check weapon system range if available
		if weapon_system:
			var weapon_range = weapon_system.get_attack_range()
			closest_attack_range = weapon_range
			if global_position.distance_to(_target_node.global_position) <= weapon_range:
				still_in_range = true
		
		# Fallback to attack_types if not in weapon range
		if not still_in_range:
			for attack_type in attack_types:
				var attack = attack_types[attack_type]
				var attack_range = attack.get("range", 50.0)

				# Track the closest range for movement calculation
				if attack_range < closest_attack_range:
					closest_attack_range = attack_range

				# Check if we're in range of any attack
				if global_position.distance_to(_target_node.global_position) <= attack_range:
					still_in_range = true
					break

		if not still_in_range:
			attack_state_timer = 0.0
			change_ai_state(AIState.CHASING)
			return

	# Move based on aggression level during combat
	if is_instance_valid(_target_node):
		var direction_to_target = (_target_node.global_position - global_position).normalized()

		# Get distance to target
		var distance = global_position.distance_to(_target_node.global_position)

		# High aggression = keep moving toward target during attacks
		if aggression_level > 0.7:
			# Continue moving toward target, just slightly slower
			target_velocity = direction_to_target * move_speed * combat_movement_speed_multiplier * 1.3
			if debug_mode:
				print("%s: AGGRESSIVE approach during attack" % name)
		# Medium aggression = maintain slight distance
		elif aggression_level > 0.3:
			# Strafe with forward tendency
			var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
			if randf() > 0.5: # Randomly reverse direction
				strafe_dir = -strafe_dir

			# Mix strafing with forward movement
			target_velocity = (strafe_dir * 0.7 + direction_to_target * 0.3) * move_speed * combat_movement_speed_multiplier
			if debug_mode:
				print("%s: MOBILE combat positioning" % name)
		# Low aggression = back off after attacking
		else:
			var preferred_distance_diff = distance - preferred_attack_distance

			if preferred_distance_diff < 0: # Too close
				target_velocity = -direction_to_target * move_speed * combat_movement_speed_multiplier
			else: # Good distance or too far
				# Strafe at the right distance
				var strafe_dir = Vector2(-direction_to_target.y, direction_to_target.x)
				if randf() > 0.5: # Randomly reverse direction
					strafe_dir = -strafe_dir

				target_velocity = strafe_dir * move_speed * combat_movement_speed_multiplier * 0.7
	else:
		target_velocity = Vector2.ZERO

	# Try to perform an attack
	# First try with weapon system if available
	if can_attack and weapon_system and weapon_system.can_attack() and is_instance_valid(_target_node):
		var attack_result = weapon_system.perform_attack()
		if attack_result:
			can_attack = false
			attack_state_timer = 0.0
			
			# Handle post-attack behavior
			handle_post_attack_behavior()
			return
	
	# Fallback to traditional attack system
	attack_closest_target()

# Process repositioning state behavior
func process_repositioning_state(_delta: float):
	# Move in the repositioning direction
	target_velocity = reposition_direction * move_speed

	# Continue checking if target is still valid during repositioning
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return

# Process fleeing state behavior
func process_fleeing_state(_delta: float):
	# If we have a target, move away from it
	if is_instance_valid(_target_node):
		var direction = (global_position - _target_node.global_position).normalized()
		target_velocity = direction * move_speed
	else:
		change_ai_state(AIState.IDLE)

# Process stunned state behavior
func process_stunned_state(_delta: float):
	# Can't move while stunned
	target_velocity = Vector2.ZERO

# --- Combat Functions ---

# Attack the closest valid target
func attack_closest_target():
	if not is_instance_valid(_target_node):
		return false

	# Determine best attack to use based on distance
	var distance = global_position.distance_to(_target_node.global_position)
	var best_attack_type = ""

	for attack_type in attack_types:
		var attack = attack_types[attack_type]
		var attack_range = attack.get("range", 50.0)

		if distance <= attack_range and can_use_attack(attack_type):
			best_attack_type = attack_type
			break

	if best_attack_type != "":
		# Call perform_attack directly without returning its result
		# This avoids the async call error
		var attack_result = perform_attack(best_attack_type)
		return attack_result

	return false

# Check if attack is available
func can_use_attack(attack_type: String) -> bool:
	# Check if the key exists before trying to access it
	if not attack_cooldowns.has(attack_type):
		push_error("Enemy %s tried to check cooldown for undefined attack type: %s (Cooldowns: %s)" % [name, attack_type, str(attack_cooldowns)])
		return false
	# Original check if key exists
	if not attack_type in attack_types:
		push_error("Enemy tried to use undefined attack type: " + attack_type)
		return false

	return attack_cooldowns[attack_type] <= 0

# Perform an attack of the specified type
func perform_attack(attack_type: String) -> bool:
	if not can_use_attack(attack_type):
		return false

	if not _target_node:
		return false

	# Get attack properties
	# Ensure attack_type exists in attack_types before proceeding
	if not attack_types.has(attack_type):
		push_error("Enemy %s cannot perform attack: Type '%s' not found in attack_types %s" % [name, attack_type, str(attack_types)])
		return false
	var attack = attack_types[attack_type]
	var attack_range = attack.get("range", 50.0)

	# Check if target is in range
	if get_distance_to_target() > attack_range:
		return false

	# Set the cooldown
	var base_cooldown = attack.get("cooldown", 1.0)
	attack_cooldowns[attack_type] = base_cooldown * attack_frequency

	# Execute the attack based on type
	match attack_type:
		"melee":
			execute_melee_attack(attack)
		"ranged":
			execute_ranged_attack(attack)
		_:
			# Custom attack handler for other types
			execute_custom_attack(attack_type, attack)

	# Signal that attack was performed
	emit_signal("attack_performed", attack_type, attack.get("damage", 0))

	# Reset attack state timer
	attack_state_timer = 0.0

	# Handle post-attack behavior based on commitment and retreat settings
	handle_post_attack_behavior()

	return true

# New function to handle post-attack behavior
func handle_post_attack_behavior():
	# Skip if no target
	if not is_instance_valid(_target_node):
		return

	# Calculate retreat based on attack_commitment (inverse relationship)
	var retreat_chance_mod = 1.0 - attack_commitment
	var should_retreat = randf() < (reposition_chance * retreat_chance_mod)

	# If pause time is set, create a timer to pause
	if post_attack_pause > 0.0:
		var pause_timer = Timer.new()
		pause_timer.one_shot = true
		pause_timer.wait_time = post_attack_pause
		add_child(pause_timer)

		# During pause, slow down or stop movement
		var pause_velocity_factor = attack_commitment * 0.5 # Higher commitment = less slowing
		target_velocity *= pause_velocity_factor

		# After pause, determine next action
		pause_timer.timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(_target_node) and current_ai_state == AIState.ATTACKING: # Added self check
				if should_retreat:
					start_repositioning()
				else:
					# High commitment enemies go back to chasing
					if attack_commitment > 0.7:
						change_ai_state(AIState.CHASING)
			if is_instance_valid(pause_timer): pause_timer.queue_free() # Added timer check
		)
		pause_timer.start()
	else:
		# No pause, decide immediately
		if should_retreat:
			start_repositioning()
		elif attack_commitment > 0.7 and current_ai_state == AIState.ATTACKING:
			# High commitment enemies go right back to chasing
			change_ai_state(AIState.CHASING)

	# If retreat distance is set, apply immediate repositioning
	if attack_retreat_distance > 0.0 and is_instance_valid(_target_node):
		var retreat_dir = (global_position - _target_node.global_position).normalized()
		# Start repositioning away from player
		reposition_direction = retreat_dir
		reposition_timer = randf_range(reposition_min_time, reposition_max_time)
		change_ai_state(AIState.REPOSITIONING)

# Handle melee attack
func execute_melee_attack(attack_data: Dictionary):
	# Basic implementation - child classes can override for custom behavior
	if _target_node and _target_node.has_method("take_damage"):
		var direction = (_target_node.global_position - global_position).normalized()
		var damage = attack_data.get("damage", 10)
		var knockback = attack_data.get("knockback", 100.0)
		_target_node.take_damage(damage, direction, knockback)

# Handle ranged attack
func execute_ranged_attack(attack_data: Dictionary):
	# Check if we have a projectile defined
	var projectile_path = attack_data.get("projectile", "")
	if projectile_path.is_empty():
		push_error("Enemy tried to use ranged attack with no projectile defined")
		return

	# Spawn projectile
	if ResourceLoader.exists(projectile_path):
		var projectile_scene = load(projectile_path)
		var projectile = projectile_scene.instantiate()

		# Set projectile properties
		projectile.global_position = global_position
		if _target_node:
			var direction = (_target_node.global_position - global_position).normalized()
			if projectile.has_method("set_direction"):
				projectile.set_direction(direction)
			if projectile.has_method("set_damage"):
				projectile.set_damage(attack_data.get("damage", 5))
			if projectile.has_method("set_source"):
				projectile.set_source(self)
			else:
				# Last resort - use metadata like projectile_factory does
				projectile.set_meta("wielder", self)
				projectile.set_meta("wielder_name", self.name)

		# Add projectile to scene
		get_tree().get_root().add_child(projectile)
	else:
		push_error("Enemy projectile scene not found: " + projectile_path)

# Handle custom attack types defined by child classes
func execute_custom_attack(attack_type: String, attack_data: Dictionary):
	# Base implementation does nothing - child classes should override
	push_error("Enemy tried to use custom attack type with no implementation: " + attack_type)

# --- Movement Helper Functions ---

# Start repositioning behavior
func start_repositioning():
	# Pick a direction to reposition
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

		if debug_mode: print("%s: REPOSITIONING for %.2f seconds in direction %s" % [name, reposition_timer, reposition_direction])
		change_ai_state(AIState.REPOSITIONING)

# Calculate the avoidance vector based on obstacles
func calculate_avoidance() -> Vector2:
	var avoidance_force = Vector2.ZERO

	var ray_directions = [
		Vector2.RIGHT, Vector2.LEFT,
		Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()
	]

	var space_state = get_world_2d().direct_space_state
	var avoidance_mask = 1 # World layer

	for direction in ray_directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + direction * avoidance_ray_length,
			avoidance_mask,
			[self]
		)
		var result = space_state.intersect_ray(query)

		if result:
			if "normal" in result and "position" in result:
				var hit_normal : Vector2 = result["normal"]
				var hit_distance = global_position.distance_to(result["position"])
				var avoidance_power = 1.0 - (hit_distance / avoidance_ray_length)

				# Apply different strength for vertical vs horizontal avoidance
				if abs(hit_normal.y) > abs(hit_normal.x) * 1.5: # If normal is mostly up/down
					avoidance_force += hit_normal * avoidance_power * avoidance_strength * vertical_avoidance_factor
				else:
					avoidance_force += hit_normal * avoidance_power * avoidance_strength

	return avoidance_force

# Generate a new random wandering direction
func _pick_new_wander_target():
	var random_angle = randf_range(0, TAU) # TAU is 2 * PI
	current_wander_direction = Vector2.RIGHT.rotated(random_angle)
	wander_timer = randf_range(wander_interval_min, wander_interval_max)
	if debug_mode: print("%s: Picked new wander direction: %s for %.2f seconds" % [name, current_wander_direction.round(), wander_timer])

# --- Line of Sight & Target Detection ---

# Check if we have line of sight to our target
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

# Check line of sight to any point
func check_line_of_sight_to_point(target_point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var los_collision_mask = 1
	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self])
	var result = space_state.intersect_ray(query)
	return not result

# Find a potential target
func find_target():
	# Look for players as potential targets
	if is_instance_valid(_target_node):
		if global_position.distance_squared_to(_target_node.global_position) < sight_range * sight_range and check_line_of_sight():
			return

	_target_node = null
	var potential_targets = get_tree().get_nodes_in_group("players")
	var closest_target: Node2D = null
	var min_dist_sq = sight_range * sight_range

	for target in potential_targets:
		if is_instance_valid(target) and target != self and target is Node2D:
			# Check if target is defeated using its own state if possible
			var target_is_defeated = false
			if target.has_method("is_defeated"): target_is_defeated = target.is_defeated()
			elif "is_defeated" in target: target_is_defeated = target.is_defeated # Fallback
			if target_is_defeated: continue

			var dist_sq = global_position.distance_squared_to(target.global_position)
			if dist_sq < min_dist_sq:
				# Check LOS using the target's actual position
				var target_check_pos = target.global_position
				# Try to get a better center point if available
				if target.has_method("get_center"): target_check_pos = target.get_center()
				elif target.has_node("CollisionShape2D"):
					var shape_node = target.get_node("CollisionShape2D")
					if is_instance_valid(shape_node): target_check_pos = shape_node.global_position

				if check_line_of_sight_to_point(target_check_pos):
					min_dist_sq = dist_sq
					closest_target = target

	_target_node = closest_target
	if debug_mode and fmod(state_timer, 1.0) < 0.01:  # Log less frequently to reduce spam
		print("%s: Target search result: %s" % [name, _target_node.name if _target_node else "None"])

	if is_instance_valid(_target_node) and current_ai_state == AIState.IDLE:
		change_ai_state(AIState.CHASING)

# Get distance to the current target
func get_distance_to_target() -> float:
	if _target_node:
		return global_position.distance_to(_target_node.global_position)
	return 1000.0  # Large default value if no target

# --- State Management ---

# Change AI state
func change_ai_state(new_state: AIState):
	if debug_mode and current_ai_state != new_state:
		print("%s: AI State -> %s" % [name, AIState.keys()[new_state]])

	previous_ai_state = current_ai_state
	current_ai_state = new_state
	state_timer = 0.0

	# State-specific initialization
	match new_state:
		AIState.IDLE:
			_pick_new_wander_target()
		AIState.ATTACKING:
			attack_state_timer = 0.0
		AIState.REPOSITIONING:
			# Initialization happens in start_repositioning
			pass
		AIState.STUNNED:
			# Stop movement immediately when stunned
			target_velocity = Vector2.ZERO
			velocity = Vector2.ZERO

# --- Health and Damage Handling ---

# Take damage from some source
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	#print("!!! TAKE DAMAGE !!!")
	if _is_defeated:
		return

	current_health -= amount
	emit_signal("health_changed", current_health, max_health)

	if debug_mode:
		print(name + " took " + str(amount) + " damage. Health: " + str(current_health) + "/" + str(max_health))

	# Apply knockback
	if knockback_strength > 0 and hit_direction != Vector2.ZERO:
		velocity += hit_direction.normalized() * knockback_strength

	if current_health <= 0 and not _is_defeated:
		die()

# Handle death
func die():
	current_health = 0
	_is_defeated = true
	if debug_mode:
		print(name + " has been defeated!")

	# Emit signal before visual effects in case listeners need to react
	emit_signal("defeated")

	# Visual and gameplay effects of death
	play_death_effects()

# Visual effects on death - can be overridden by child classes
func play_death_effects():
	# Default implementation could play a simple animation
	# If there's an AnimationPlayer, play a "death" animation
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
	
	# Disable collision immediately
	disable_collision()

	# Default cleanup timer if no animation handled it
	if not (anim_player and anim_player.has_animation("death")):
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(queue_free)

# Disable collision
func disable_collision():
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

# --- Virtual method for child classes to implement custom AI behavior ---
func perform_ai_logic(_delta):
	pass

# --- Target Management ---

# Set the enemy's target (usually a player)
func set_target(target_node):
	_target_node = target_node
	if is_instance_valid(_target_node) and current_ai_state == AIState.IDLE:
		change_ai_state(AIState.CHASING)

# Helper function for weapons system and derived classes
func get_wielder():
	return self

# Get the attack direction - useful for weapons/projectiles
func get_attack_direction_value() -> Vector2:
	if is_instance_valid(_target_node):
		return (_target_node.global_position - global_position).normalized()
	
	# Default direction based on sprite orientation
	if has_node("AnimatedSprite2D"):
		var sprite = get_node("AnimatedSprite2D")
		return Vector2(1 if !sprite.flip_h else -1, 0)
		
	return Vector2.RIGHT # Default direction
