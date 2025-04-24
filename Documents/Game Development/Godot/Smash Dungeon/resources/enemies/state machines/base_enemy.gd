# base_enemy.gd
extends CharacterBody2D
class_name BaseEnemy

# Signals
signal defeated
signal health_changed(current, maximum)
signal attack_performed(attack_type, damage)

# --- Base Stats ---
@export_group("Base Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var acceleration: float = 10.0
@export var damping: float = 0.9

# --- Weapon System ---
@export_group("Weapon System")
@export var weapon_id: String = ""  # Default weapon ID, empty means no weapon

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
@export var chase_speed_multiplier: float = 1.2
@export var direct_chase: bool = false  
@export var chase_jump_chance: float = 0.0
@export var chase_jump_force: float = 300.0
@export var aggression_level: float = 0.5

# --- Attack Behavior Parameters ---
@export_group("Attack Behavior")
@export var attack_commitment: float = 0.5
@export var post_attack_pause: float = 0.0
@export var attack_retreat_distance: float = 0.0
@export var attack_frequency: float = 1.0
@export var attack_telegraph_enabled: bool = false
@export var attack_telegraph_time: float = 0.3

# --- Avoidance System ---
@export_group("Avoidance System")
@export var use_avoidance: bool = true
@export var avoidance_strength: float = 150.0
@export var avoidance_ray_length: float = 75.0
@export var vertical_avoidance_factor: float = 0.6

# --- Attack Definitions ---
@export_group("Attack Definitions")
@export var attack_types: Dictionary = {
	"melee": {
		"damage": 10,
		"cooldown": 1.0,
		"range": 50.0
	}
}

# --- Internal Variables ---
var current_health: int
var _is_defeated: bool = false
var target_velocity: Vector2 = Vector2.ZERO
var reposition_direction: Vector2 = Vector2.ZERO
var _target_node = null  # Reference to player or other target
var attack_cooldowns: Dictionary = {}
var can_attack: bool = true

# --- Cached Node References ---
@onready var state_machine = $StateMachine
@onready var weapon_system = $WeaponSystem
@onready var animated_sprite = $AnimatedSprite2D

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var use_gravity: bool = true

func _ready():
	current_health = max_health
	
	# Initialize attack cooldowns
	_initialize_attack_cooldowns()
	
	# Initialize weapon system if weapon ID is set
	if weapon_system and weapon_id != "":
		weapon_system.initialize(self, weapon_id)

func _physics_process(delta):
	if _is_defeated:
		return
	
	# Update cooldowns
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# Calculate avoidance if enabled
	var avoidance_vector = Vector2.ZERO
	if use_avoidance:
		avoidance_vector = calculate_avoidance()
	
	# Apply gravity if not floating
	if not is_on_floor() and use_gravity:
		velocity.y += gravity * delta
	
	# Calculate final velocity with dampening and acceleration
	velocity *= pow(damping, delta * 60.0)
	var combined_target_velocity = target_velocity + avoidance_vector
	var max_delta_velocity = acceleration * move_speed * delta
	velocity = velocity.move_toward(combined_target_velocity, max_delta_velocity)
	
	# Apply movement
	move_and_slide()
	
	# Update weapon position if available
	if weapon_system:
		weapon_system.update_position()

# --- Attack System Methods ---

func _initialize_attack_cooldowns():
	attack_cooldowns.clear()
	if attack_types:
		for attack_type_key in attack_types:
			attack_cooldowns[attack_type_key] = 0.0

func can_use_attack(attack_type: String) -> bool:
	if not attack_cooldowns.has(attack_type) or not attack_type in attack_types:
		return false
	return attack_cooldowns[attack_type] <= 0

func attack_closest_target():
	if not is_instance_valid(_target_node):
		return false
	
	var distance = global_position.distance_to(_target_node.global_position)
	var best_attack_type = ""
	
	for attack_type in attack_types:
		var attack = attack_types[attack_type]
		var attack_range = attack.get("range", 50.0)
		
		if distance <= attack_range and can_use_attack(attack_type):
			best_attack_type = attack_type
			break
	
	if best_attack_type != "":
		perform_attack(best_attack_type)
		return true
	
	return false

func perform_attack(attack_type: String) -> bool:
	if not can_use_attack(attack_type) or not _target_node:
		return false
	
	var attack = attack_types[attack_type]
	var attack_range = attack.get("range", 50.0)
	
	if get_distance_to_target() > attack_range:
		return false
	
	# Set cooldown
	var base_cooldown = attack.get("cooldown", 1.0)
	attack_cooldowns[attack_type] = base_cooldown * attack_frequency
	
	# Execute attack based on type
	match attack_type:
		"melee":
			execute_melee_attack(attack)
		"ranged":
			execute_ranged_attack(attack)
		_:
			execute_custom_attack(attack_type, attack)
	
	# Signal that attack was performed
	emit_signal("attack_performed", attack_type, attack.get("damage", 0))
	
	return true

# --- Movement and Collision Methods ---

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
			var hit_normal = result["normal"]
			var hit_distance = global_position.distance_to(result["position"])
			var avoidance_power = 1.0 - (hit_distance / avoidance_ray_length)
			
			if abs(hit_normal.y) > abs(hit_normal.x) * 1.5:
				avoidance_force += hit_normal * avoidance_power * avoidance_strength * vertical_avoidance_factor
			else:
				avoidance_force += hit_normal * avoidance_power * avoidance_strength
	
	return avoidance_force

func check_line_of_sight() -> bool:
	if not is_instance_valid(_target_node): 
		return false
	
	return check_line_of_sight_to_point(_target_node.global_position)

func check_line_of_sight_to_point(target_point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var los_collision_mask = 1
	var query = PhysicsRayQueryParameters2D.create(global_position, target_point, los_collision_mask, [self])
	var result = space_state.intersect_ray(query)
	return not result

func get_distance_to_target() -> float:
	if _target_node:
		return global_position.distance_to(_target_node.global_position)
	return 1000.0

func get_attack_direction_value() -> Vector2:
	if is_instance_valid(_target_node):
		return (_target_node.global_position - global_position).normalized()
	
	if has_node("AnimatedSprite2D"):
		var sprite = get_node("AnimatedSprite2D")
		return Vector2(1 if !sprite.flip_h else -1, 0)
	
	return Vector2.RIGHT

# --- Combat Implementation Methods ---

func execute_melee_attack(attack_data: Dictionary):
	if _target_node and _target_node.has_method("take_damage"):
		var direction = (_target_node.global_position - global_position).normalized()
		var damage = attack_data.get("damage", 10)
		var knockback = attack_data.get("knockback", 100.0)
		_target_node.take_damage(damage, direction, knockback)

func execute_ranged_attack(attack_data: Dictionary):
	var projectile_path = attack_data.get("projectile", "")
	if projectile_path.is_empty():
		return
	
	if ResourceLoader.exists(projectile_path):
		var projectile_scene = load(projectile_path)
		var projectile = projectile_scene.instantiate()
		
		projectile.global_position = global_position
		if _target_node:
			var direction = (_target_node.global_position - global_position).normalized()
			if projectile.has_method("set_direction"):
				projectile.set_direction(direction)
			if projectile.has_method("set_damage"):
				projectile.set_damage(attack_data.get("damage", 5))
			if projectile.has_method("set_source"):
				projectile.set_source(self)
		
		get_tree().get_root().add_child(projectile)

func execute_custom_attack(attack_type: String, attack_data: Dictionary):
	# Override in child classes
	pass

# --- Health and Damage ---

func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	if _is_defeated:
		return
	
	current_health -= amount
	emit_signal("health_changed", current_health, max_health)
	
	# Apply knockback
	if knockback_strength > 0 and hit_direction != Vector2.ZERO:
		velocity += hit_direction.normalized() * knockback_strength
	
	if current_health <= 0 and not _is_defeated:
		die()
	else:
		# Notify state machine of hit
		if state_machine:
			state_machine.handle_event("hit", {
				"amount": amount,
				"direction": hit_direction
			})

func die():
	current_health = 0
	_is_defeated = true
	
	emit_signal("defeated")
	
	# Play death animation or effects
	if has_node("AnimationPlayer"):
		var anim_player = get_node("AnimationPlayer")
		if anim_player.has_animation("death"):
			anim_player.play("death")
			return
	
	# No animation, just disable and queue free with delay
	disable_collision()
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)

func disable_collision():
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
