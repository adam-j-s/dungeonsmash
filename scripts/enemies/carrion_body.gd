# carrion_body.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name CarrionBody

# --- Surface States ---
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }

# --- Exports ---
@export var tentacle_scene: PackedScene

# --- Tentacle Parameters ---
@export var num_tentacles: int = 8
@export var pull_force_multiplier: float = 120.0
@export var detach_distance: float = 250.0
@export var leg_follow_lerp_speed: float = 15.0
@export var leg_step_distance: float = 35.0
@export var max_step_trigger_dist: float = 45.0
@export var leg_step_cooldown: float = 0.1
@export var gravity_scale: float = 1.0
@export var body_inertia: float = 5.0

# --- Body Visuals ---
@export var body_radius: float = 15.0
@export var body_points: int = 12
@export var body_radius_variation: float = 0.2
@export var body_color: Color = Color(0.2, 0.05, 0.3)

# --- Internal Vars ---
var current_surface_state = SurfaceState.AIRBORNE
var target_surface_normal: Vector2 = Vector2.UP
var current_up_direction: Vector2 = Vector2.UP
var retarget_timer: float = 0.0
var tentacles: Array[Tentacle] = []
var retarget_interval: float = 0.4
var turn_speed: float = 6.0

# --- Node References ---
@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var wall_check_r: RayCast2D = $WallCheckRight
@onready var wall_check_l: RayCast2D = $WallCheckLeft

# --- Initialization ---
func _ready():
	# Call parent _ready
	super._ready()
	
	# Set up surface detection
	if floor_check==null or ceiling_check==null or wall_check_l==null or wall_check_r==null:
		printerr("%s: Missing RayCast2D children!" % name)
		set_physics_process(false)
		return
		
	# Spawn tentacles
	spawn_tentacles()
	
	# Initialize surface state
	update_surface_state()
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0
	
	# Set physics process
	set_physics_process(true)

# Override physics process to handle surface movement
func _physics_process(delta):
	# Skip parent _physics_process and implement custom version
	# that incorporates surface movement
	
	# Update state timers
	state_timer += delta
	retarget_timer -= delta
	
	# Update attack cooldowns from parent
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# Update surface state and orientation
	update_surface_state()
	update_orientation(delta)
	
	# Process AI state
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)
		AIState.REPOSITIONING: process_repositioning_state(delta)
		AIState.FLEEING: process_fleeing_state(delta)
		AIState.STUNNED: process_stunned_state(delta)
	
	# Apply forces from tentacles
	var external_force = calculate_forces()
	apply_forces_and_damping(external_force, delta)
	
	# Move and slide (parent functionality)
	move_and_slide()
	
	# Check tentacle detachment
	check_tentacle_detachment()

# --- Tentacle Management ---
func spawn_tentacles():
	if tentacle_scene == null:
		printerr("Tentacle scene not assigned!")
		return
		
	for t in tentacles:
		if is_instance_valid(t):
			t.queue_free()
			
	tentacles.clear()
	var angle_step: float = TAU / float(num_tentacles)
	
	for i in range(num_tentacles):
		var angle: float = float(i) * angle_step
		var anchor_pos_local: Vector2 = Vector2.from_angle(angle) * 5.0
		var tentacle_instance = tentacle_scene.instantiate() as Tentacle
		
		if tentacle_instance:
			add_child(tentacle_instance)
			tentacle_instance.position = anchor_pos_local
			tentacle_instance.setup_tentacle(self)
			
			if tentacle_instance.has_method("set_follow_lerp_speed"):
				tentacle_instance.set_follow_lerp_speed(leg_follow_lerp_speed)
				
			tentacles.append(tentacle_instance)
		else:
			printerr("Failed to instantiate Tentacle scene.")

# --- Override State Processing ---
func process_idle_state(delta):
	target_velocity = Vector2.ZERO
	
	# Check if target exists
	if is_instance_valid(_target_node):
		change_ai_state(AIState.CHASING)
		return
	
	# Randomly wiggle tentacles
	if retarget_timer <= 0:
		for tentacle in tentacles:
			if is_instance_valid(tentacle) and tentacle.can_reach() and randf() < 0.05:
				var random_dir = Vector2.from_angle(randf() * TAU)
				tentacle.reach_for(global_position + random_dir * 50.0)
		
		retarget_timer = retarget_interval * randf_range(1.0, 1.5)

func process_chasing_state(delta):
	# Check if target is still valid
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Calculate movement vector along the surface
	var vector_to_target_global = _target_node.global_position - global_position
	var surface_direction = current_up_direction.orthogonal()
	var target_dot = vector_to_target_global.normalized().dot(surface_direction)
	target_velocity = surface_direction * target_dot * move_speed
	
	# Aim tentacles periodically
	if retarget_timer <= 0:
		aim_tentacles_at_target()
		retarget_timer = retarget_interval
		
	# Check if in attack range
	var distance = global_position.distance_to(_target_node.global_position)
	if distance < preferred_attack_distance:
		change_ai_state(AIState.ATTACKING)

# --- Surface Movement Helpers ---
func update_orientation(delta: float):
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)

func calculate_forces() -> Vector2:
	var total_force : Vector2 = Vector2.ZERO
	total_force += target_surface_normal * (ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale)
	
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attached():
			var pull_dir : Vector2 = (tentacle.get_anchor_point_global() - global_position).normalized()
			total_force += pull_dir * pull_force_multiplier
			
	return total_force

func apply_forces_and_damping(force: Vector2, delta: float):
	var attached_count : int = 0
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attached():
			attached_count += 1
			
	var current_damping : float = damping if attached_count == 0 else pow(damping, 0.2)
	velocity *= pow(current_damping, delta * 60.0)
	
	var effective_acceleration : Vector2 = force / max(1.0, body_inertia)
	velocity += effective_acceleration * delta
	
	var surface_direction : Vector2 = current_up_direction.orthogonal()
	var target_surface_velocity_vector : Vector2 = surface_direction * target_velocity.dot(surface_direction)
	var current_surface_velocity_vector : Vector2 = velocity.slide(current_up_direction)
	var new_surface_velocity_vector : Vector2 = current_surface_velocity_vector.move_toward(target_surface_velocity_vector, acceleration * delta * 60)
	
	velocity = velocity.project(target_surface_normal) + new_surface_velocity_vector

func check_tentacle_detachment():
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attached():
			if tentacle.get_anchor_point_global().distance_squared_to(global_position) > detach_distance * detach_distance:
				tentacle.detach()

# --- Surface State Function ---
func update_surface_state():
	if not is_instance_valid(floor_check) or not is_instance_valid(ceiling_check) or \
	   not is_instance_valid(wall_check_l) or not is_instance_valid(wall_check_r):
		printerr("%s: Missing RayCast2D!" % name)
		target_surface_normal = Vector2.UP
		current_surface_state = SurfaceState.AIRBORNE
		return

	var detected_normal = Vector2.UP
	var new_state = SurfaceState.AIRBORNE
	
	floor_check.force_raycast_update()
	ceiling_check.force_raycast_update()
	wall_check_l.force_raycast_update()
	wall_check_r.force_raycast_update()

	if floor_check.is_colliding():
		detected_normal = floor_check.get_collision_normal()
		new_state = SurfaceState.ON_FLOOR
	elif ceiling_check.is_colliding():
		detected_normal = ceiling_check.get_collision_normal()
		new_state = SurfaceState.ON_CEILING
	elif wall_check_l.is_colliding():
		detected_normal = wall_check_l.get_collision_normal()
		new_state = SurfaceState.ON_WALL_L
	elif wall_check_r.is_colliding():
		detected_normal = wall_check_r.get_collision_normal()
		new_state = SurfaceState.ON_WALL_R
		
	if new_state != current_surface_state:
		current_surface_state = new_state
		
	target_surface_normal = detected_normal.normalized()

# --- Tentacle Control ---
func aim_tentacles_at_target():
	if not is_instance_valid(_target_node):
		return
		
	var target_pos = _target_node.global_position
	var body_pos = global_position
	var dir_to_target = (target_pos - body_pos).normalized()
	
	if dir_to_target == Vector2.ZERO:
		dir_to_target = Vector2.RIGHT
		
	var idle_tentacles = get_idle_tentacles()
	
	if idle_tentacles.is_empty():
		return
		
	var half_idle = ceil(idle_tentacles.size() / 2.0)
	idle_tentacles.shuffle()

	for i in range(idle_tentacles.size()):
		var tentacle = idle_tentacles[i]
		
		if not is_instance_valid(tentacle) or not tentacle.can_reach():
			continue

		if i < half_idle:
			# Aim near target
			var aim_point = target_pos + Vector2(randf_range(-30,30), randf_range(-30,30))
			var vec_to_aim = aim_point - body_pos
			var min_dist_sq = pow(body_radius * 1.5, 2)
			
			if vec_to_aim.length_squared() < min_dist_sq:
				aim_point = body_pos + vec_to_aim.normalized() * sqrt(min_dist_sq)
				
			tentacle.reach_for(aim_point)
		else:
			# Aim for surface
			var ray_start = body_pos
			var aim_dir = dir_to_target.rotated(randf_range(-PI/3, PI/3))
			var current_reach_distance = detach_distance
			
			if is_instance_valid(tentacle) and "reach_distance" in tentacle:
				current_reach_distance = tentacle.reach_distance
				
			var ray_end = body_pos + aim_dir * current_reach_distance * 1.2
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
			var result = space_state.intersect_ray(query)
			
			if result:
				tentacle.reach_for(result.position)
			else:
				tentacle.reach_for(body_pos + aim_dir * current_reach_distance * 0.8)

func get_idle_tentacles() -> Array[Tentacle]:
	var idle: Array[Tentacle] = []
	
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.current_state == Tentacle.TentacleState.IDLE:
			idle.append(tentacle)
			
	return idle

# --- Override BaseEnemy Methods ---
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Default damage handling
	super.take_damage(amount, hit_direction, knockback_strength)
	
	# Additional behavior: detach some tentacles when damaged
	var detach_count = min(2, tentacles.size())
	for i in range(detach_count):
		if tentacles.size() > i and is_instance_valid(tentacles[i]) and tentacles[i].is_attached():
			tentacles[i].detach()

# Override death handler
func play_death_effects():
	# Call parent method to handle signals
	super.play_death_effects()
	
	# Detach all tentacles
	for tentacle in tentacles:
		if is_instance_valid(tentacle):
			tentacle.detach()
			
	# Death animation
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# Queue free after fade out
	await tween.finished
	queue_free()
