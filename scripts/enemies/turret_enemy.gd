# turret_enemy.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name TurretEnemy

# Turret-specific exports
@export var rotation_speed: float = 3.0
@export var firing_arc: float = 270.0  # Degrees
@export var aim_time: float = 0.5
@export var shot_spread: float = 5.0  # Degrees
@export var detection_range: float = 600.0

# Node references
@onready var base_sprite = $BaseSprite
@onready var turret_sprite = $TurretSprite
@onready var muzzle = $Muzzle
@onready var detection_area = $DetectionArea
@onready var laser_sight = $LaserSight
@onready var attack_timer = $AttackTimer

# State tracking
var is_aiming: bool = false
var aim_timer: float = 0.0
var target_rotation: float = 0.0
var initial_rotation: float = 0.0

func _ready():
	# Call parent _ready
	super._ready()
	
	# Configure as stationary
	move_speed = 0.0
	
	# Initialize turret angle
	if turret_sprite:
		initial_rotation = turret_sprite.rotation
	
	# Set up laser sight if present
	if laser_sight:
		laser_sight.visible = false

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to turret
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1  # World layer only - turret doesn't move

# Override physics process to handle turret-specific behavior
func _physics_process(delta):
	# Skip normal movement processing since turrets are stationary
	# We'll handle AI logic ourselves
	
	# Update timers
	state_timer += delta
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# Handle aiming
	if is_aiming:
		aim_timer += delta
		if aim_timer >= aim_time:
			is_aiming = false
			fire_at_target()
	
	# Process current AI state
	match current_ai_state:
		AIState.IDLE:
			process_idle_state(delta)
		AIState.ATTACKING:
			process_turret_attack_state(delta)
		AIState.STUNNED:
			process_stunned_state(delta)
	
	# Rotate turret toward target if we have one
	if is_instance_valid(_target_node) and turret_sprite:
		var target_dir = (_target_node.global_position - global_position).normalized()
		target_rotation = target_dir.angle()
		
		# Smoothly rotate toward target
		turret_sprite.rotation = lerp_angle(turret_sprite.rotation, target_rotation, rotation_speed * delta)
		
		# Update laser sight if present
		if laser_sight:
			laser_sight.rotation = turret_sprite.rotation
			laser_sight.visible = is_aiming
			
			if is_aiming:
				# Adjust laser length based on distance to target
				var distance = global_position.distance_to(_target_node.global_position)
				laser_sight.scale.x = min(distance / 10.0, 50.0)  # Limit max length

# Override process_idle_state for turret
func process_idle_state(_delta):
	# Check for targets in detection range
	find_target()
	
	# If we found a target, start attacking
	if is_instance_valid(_target_node):
		change_ai_state(AIState.ATTACKING)

# Custom attack state for turret
func process_turret_attack_state(_delta):
	# Skip if no target
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Check if target still in range
	var distance = global_position.distance_to(_target_node.global_position)
	if distance > detection_range:
		change_ai_state(AIState.IDLE)
		_target_node = null
		return
	
	# Check if we can see target
	if not check_line_of_sight():
		# Lost line of sight, but keep tracking for a short time
		if state_timer > 3.0:
			change_ai_state(AIState.IDLE)
			_target_node = null
		return
	
	# Reset state timer since we can see the target
	state_timer = 0.0
	
	# Check if we can fire
	if not is_aiming and can_use_attack("ranged") and is_target_in_firing_arc():
		# Start aiming
		start_aiming()

# Check if target is within the turret's firing arc
func is_target_in_firing_arc() -> bool:
	if not is_instance_valid(_target_node) or not turret_sprite:
		return false
	
	var target_dir = (_target_node.global_position - global_position).normalized()
	var target_angle = target_dir.angle()
	var turret_angle = turret_sprite.rotation
	
	# Calculate angle difference in degrees
	var angle_diff = abs(rad_to_deg(wrapf(target_angle - turret_angle, -PI, PI)))
	
	# Check if within half the firing arc
	return angle_diff <= firing_arc / 2.0

# Start the aiming process before firing
func start_aiming():
	is_aiming = true
	aim_timer = 0.0
	
	# Show laser sight if present
	if laser_sight:
		laser_sight.visible = true
	
	# Play charging animation or effect here if needed

# Fire at the current target
func fire_at_target():
	if not is_instance_valid(_target_node):
		return
	
	# Hide laser sight after firing
	if laser_sight:
		laser_sight.visible = false
	
	# Fire the weapon
	var attack_data = attack_types["ranged"]
	
	# Add some random spread to the shot
	var direction = (_target_node.global_position - global_position).normalized()
	var spread_angle = randf_range(-shot_spread, shot_spread) * (PI / 180.0)
	direction = direction.rotated(spread_angle)
	
	# Set up projectile data
	var projectile_path = attack_data.get("projectile", "")
	if projectile_path.is_empty():
		push_error("Turret tried to use ranged attack with no projectile defined")
		return
		
	# Spawn projectile
	if ResourceLoader.exists(projectile_path):
		var projectile_scene = load(projectile_path)
		var projectile = projectile_scene.instantiate()
		
		# Set projectile position at muzzle
		var spawn_pos = global_position
		if muzzle:
			spawn_pos = muzzle.global_position
		
		projectile.global_position = spawn_pos
		
		# Set projectile properties
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
		
		# Start cooldown
		attack_cooldowns["ranged"] = attack_data.get("cooldown", 1.5)
		
		# Emit attack signal
		emit_signal("attack_performed", "ranged", attack_data.get("damage", 5))
	else:
		push_error("Turret projectile scene not found: " + projectile_path)

# Enhanced find_target for turret with angle constraints
func find_target():
	_target_node = null
	
	var potential_targets = get_tree().get_nodes_in_group("players")
	var closest_target = null
	var min_dist_sq = detection_range * detection_range
	
	for target in potential_targets:
		if is_instance_valid(target) and target != self and target is Node2D:
			if "is_defeated" in target and target.is_defeated:
				continue
				
			var dist_sq = global_position.distance_squared_to(target.global_position)
			if dist_sq < min_dist_sq and check_line_of_sight_to_point(target.global_position):
				min_dist_sq = dist_sq
				closest_target = target
	
	_target_node = closest_target
	if debug_mode and _target_node:
		print("%s: Found target: %s at distance: %f" % [name, _target_node.name, sqrt(min_dist_sq)])

# Override death handler
func play_death_effects():
	# Call parent method to handle signals and cleanup
	super.play_death_effects()
	
	# Hide laser sight
	if laser_sight:
		laser_sight.visible = false
	
	# Disable collisions
	disable_collision()
	
	# Play death animation or particles here
	
	# Drooping/falling animation for turret
	if turret_sprite:
		var tween = create_tween()
		tween.tween_property(turret_sprite, "rotation", turret_sprite.rotation + PI/4, 0.5)
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# Queue free after fade out
	await fade_tween.finished
	queue_free()
