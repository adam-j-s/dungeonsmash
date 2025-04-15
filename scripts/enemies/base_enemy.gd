# base_enemy.gd - Updated for attack handling
extends CharacterBody2D
class_name BaseEnemy

# Signals
signal defeated
signal health_changed(current, maximum)
signal attack_performed(attack_type, damage)

# Stats
@export var max_health: int = 100
@export var move_speed: float = 100.0

# Attack definitions
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

# Current attack cooldowns
var attack_cooldowns: Dictionary = {}

# State
var current_health: int
var _is_defeated: bool = false
var _target_node = null  # Reference to player or other target

# Physics
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Called when the node enters the scene tree for the first time
func _ready():
	current_health = max_health
	
	# Initialize cooldowns for all attack types
	for attack_type in attack_types:
		attack_cooldowns[attack_type] = 0.0
	
	# Basic initialization - can be overridden by child classes
	initialize()
	
# Virtual method for child classes to override without affecting _ready
func initialize():
	pass
	
# Physics process - basic implementation
func _physics_process(delta):
	# Update attack cooldowns
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Basic AI movement logic can go here or in child classes
	perform_ai_logic(delta)
	
	# Apply movement
	move_and_slide()
	
# Virtual method for child classes to implement AI behavior
func perform_ai_logic(_delta):
	pass
	
# Damage handling
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	if _is_defeated:
		return
		
	current_health -= amount
	emit_signal("health_changed", current_health, max_health)
	
	print(name + " took " + str(amount) + " damage. Health: " + str(current_health) + "/" + str(max_health))
	
	if current_health <= 0 and not _is_defeated:
		die()
		
# Check if attack is available
func can_use_attack(attack_type: String) -> bool:
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
	var attack = attack_types[attack_type]
	var attack_range = attack.get("range", 50.0)
	
	# Check if target is in range
	if get_distance_to_target() > attack_range:
		return false
		
	# Set the cooldown
	attack_cooldowns[attack_type] = attack.get("cooldown", 1.0)
	
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
	return true
	
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
			# Change this line:
			if projectile.has_method("set_source"):  # Was "set_owner"
				projectile.set_source(self)  # Was "set_owner"
				
		# Add projectile to scene
		get_tree().get_root().add_child(projectile)
	else:
		push_error("Enemy projectile scene not found: " + projectile_path)
		
# Handle custom attack types defined by child classes        
func execute_custom_attack(attack_type: String, attack_data: Dictionary):
	# Base implementation does nothing - child classes should override
	push_error("Enemy tried to use custom attack type with no implementation: " + attack_type)
	
# Death handling
func die():
	current_health = 0
	_is_defeated = true
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
	else:
		# If no animation, just queue_free after a short delay
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): queue_free())
	
# Disable collision
func disable_collision():
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	
# Set the enemy's target (usually a player)
func set_target(target_node):
	_target_node = target_node
	
# Get distance to target
func get_distance_to_target() -> float:
	if _target_node:
		return global_position.distance_to(_target_node.global_position)
	return 1000.0  # Large default value if no target
