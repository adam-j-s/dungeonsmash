# Carrion_body.gd (v1.5 - Target Set Externally)
extends CharacterBody2D
class_name CarrionBody_AI

# --- States ---
enum AIState { IDLE, CHASING }
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }

# --- Exports ---
@export var tentacle_scene: PackedScene # Assign Tentacle.tscn

@export_group("AI & Movement")
@export var move_speed: float = 150.0
@export var acceleration: float = 10.0
@export var body_inertia: float = 5.0
@export var damping: float = 0.95
@export var gravity_scale: float = 1.0
# @export var sight_range: float = 600.0 # Less critical if target is set externally
@export var retarget_interval: float = 0.4
@export var turn_speed: float = 6.0

@export_group("Tentacles")
@export var num_tentacles: int = 8
@export var pull_force_multiplier: float = 120.0
@export var detach_distance: float = 250.0
@export var leg_follow_lerp_speed: float = 15.0
@export var leg_step_distance: float = 35.0
@export var max_step_trigger_dist: float = 45.0
@export var leg_step_cooldown: float = 0.1

@export_group("Body Visuals")
@export var body_radius: float = 15.0
@export var body_points: int = 12
@export var body_radius_variation: float = 0.2
@export var body_color: Color = Color(0.2, 0.05, 0.3)

# --- Internal Vars ---
var current_ai_state = AIState.IDLE
var current_surface_state = SurfaceState.AIRBORNE
var target_surface_normal: Vector2 = Vector2.UP
var current_up_direction: Vector2 = Vector2.UP
var state_timer: float = 0.0
var retarget_timer: float = 0.0
var gravity: float = 0.0
var tentacles: Array[Tentacle] = []
var _target_node: Node2D = null # Target is now primarily set via set_target()
var target_move_velocity: Vector2 = Vector2.ZERO

# --- Node References ---
@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var wall_check_r: RayCast2D = $WallCheckRight
@onready var wall_check_l: RayCast2D = $WallCheckLeft
# @onready var body_visual: Polygon2D = $Visuals/BodyVisual # Optional

# --- Initialization ---
func _ready():
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale

	if floor_check==null or ceiling_check==null or wall_check_l==null or wall_check_r==null:
		printerr("%s: Missing RayCast2D children!" % name); set_physics_process(false); return

	# if body_visual: generate_body_shape() # Optional

	spawn_tentacles()
	update_surface_state()
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0

	# Don't immediately change state, wait for set_target or find_target
	# change_ai_state(AIState.IDLE)
	set_physics_process(true)

# --- Spawn Tentacles ---
func spawn_tentacles():
	if tentacle_scene == null: printerr("Tentacle scene not assigned!"); return
	for t in tentacles: if is_instance_valid(t): t.queue_free()
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
		else: printerr("Failed to instantiate Tentacle scene.")

# --- Main Update Loop ---
func _physics_process(delta: float):
	state_timer += delta
	retarget_timer -= delta

	update_surface_state()
	update_orientation(delta)

	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)

	var external_force : Vector2 = calculate_forces()
	apply_forces_and_damping(external_force, delta)

	move_and_slide()
	check_tentacle_detachment()

# --- State & Movement Helpers ---
func update_orientation(delta: float):
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)

func calculate_forces() -> Vector2:
	var total_force : Vector2 = Vector2.ZERO
	total_force += target_surface_normal * gravity
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attached():
			var pull_dir : Vector2 = (tentacle.get_anchor_point_global() - global_position).normalized()
			total_force += pull_dir * pull_force_multiplier
	return total_force

func apply_forces_and_damping(force: Vector2, delta: float):
	var attached_count : int = 0
	for tentacle in tentacles: if is_instance_valid(tentacle) and tentacle.is_attached(): attached_count += 1
	var current_damping : float = damping if attached_count == 0 else pow(damping, 0.2)
	velocity *= pow(current_damping, delta * 60.0)
	var effective_acceleration : Vector2 = force / max(1.0, body_inertia)
	velocity += effective_acceleration * delta
	var surface_direction : Vector2 = current_up_direction.orthogonal()
	var target_surface_velocity_vector : Vector2 = surface_direction * target_move_velocity.dot(surface_direction)
	var current_surface_velocity_vector : Vector2 = velocity.slide(current_up_direction)
	var new_surface_velocity_vector : Vector2 = current_surface_velocity_vector.move_toward(target_surface_velocity_vector, acceleration * delta * 60)
	velocity = velocity.project(target_surface_normal) + new_surface_velocity_vector

func check_tentacle_detachment():
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attached():
			if tentacle.get_anchor_point_global().distance_squared_to(global_position) > detach_distance * detach_distance:
				tentacle.detach()

# --- AI State Functions ---
func process_idle_state(_delta: float):
	target_move_velocity = Vector2.ZERO
	# If a target was assigned externally, switch state
	if _target_node:
		change_ai_state(AIState.CHASING)
		return
	# Optional: Add find_target() here as a backup if set_target might fail
	# if state_timer > 1.0: find_target(); state_timer = 0.0

	# Randomly wiggle
	if retarget_timer <= 0:
		for tentacle in tentacles:
			if is_instance_valid(tentacle) and tentacle.can_reach() and randf() < 0.05:
				var random_dir = Vector2.from_angle(randf() * TAU)
				tentacle.reach_for(global_position + random_dir * 50.0)
		retarget_timer = retarget_interval * randf_range(1.0, 1.5)

func process_chasing_state(_delta: float):
	# Check if target is lost (e.g., destroyed)
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		_target_node = null
		for tentacle in tentacles: if is_instance_valid(tentacle): tentacle.retract()
		return
	# Optional: Check distance again if you want it to lose aggro
	# if global_position.distance_squared_to(_target_node.global_position) > sight_range * sight_range * 1.2: # Hysteresis
	#    change_ai_state(AIState.IDLE) ...

	# Set target velocity towards player along the surface
	var vector_to_target_global = _target_node.global_position - global_position
	var surface_direction = current_up_direction.orthogonal()
	var target_dot = vector_to_target_global.normalized().dot(surface_direction)
	target_move_velocity = surface_direction * target_dot * move_speed

	# Aim tentacles periodically
	if retarget_timer <= 0:
		aim_tentacles_at_target()
		retarget_timer = retarget_interval

func aim_tentacles_at_target():
	if not _target_node: return
	var target_pos = _target_node.global_position; var body_pos = global_position
	var dir_to_target = (target_pos - body_pos).normalized(); if dir_to_target == Vector2.ZERO: dir_to_target = Vector2.RIGHT
	var idle_tentacles = get_idle_tentacles(); if idle_tentacles.is_empty(): return

	var half_idle = ceil(idle_tentacles.size() / 2.0)
	idle_tentacles.shuffle()

	for i in range(idle_tentacles.size()):
		var tentacle = idle_tentacles[i]
		if not is_instance_valid(tentacle) or not tentacle.can_reach(): continue

		if i < half_idle: # Aim near target
			var aim_point = target_pos + Vector2(randf_range(-30,30), randf_range(-30,30))
			var vec_to_aim = aim_point - body_pos
			var min_dist_sq = pow(self.body_radius * 1.5, 2) # Use self. for member var
			if vec_to_aim.length_squared() < min_dist_sq:
				aim_point = body_pos + vec_to_aim.normalized() * sqrt(min_dist_sq)
			tentacle.reach_for(aim_point)
		else: # Aim for surface
			var ray_start = body_pos
			var aim_dir = dir_to_target.rotated(randf_range(-PI/3, PI/3))
			var current_reach_distance = detach_distance
			if is_instance_valid(tentacle) and "reach_distance" in tentacle:
				current_reach_distance = tentacle.reach_distance
			var ray_end = body_pos + aim_dir * current_reach_distance * 1.2
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
			var result = space_state.intersect_ray(query)
			if result: tentacle.reach_for(result.position)
			else: tentacle.reach_for(body_pos + aim_dir * current_reach_distance * 0.8)


func get_idle_tentacles() -> Array[Tentacle]:
	var idle: Array[Tentacle] = [];
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and tentacle.current_state == Tentacle.TentacleState.IDLE:
			idle.append(tentacle)
	return idle

func change_ai_state(new_state):
	current_ai_state = new_state; state_timer = 0.0; retarget_timer = 0.0


# --- Target Finding (Now primarily a fallback if needed) ---
# func find_target(): ... (Keep or remove this depending on if you need a backup)


# --- Surface State Function ---
func update_surface_state():
	if not is_instance_valid(floor_check) or not is_instance_valid(ceiling_check) or \
	   not is_instance_valid(wall_check_l) or not is_instance_valid(wall_check_r):
		printerr("%s: Missing RayCast2D!" % name); target_surface_normal=Vector2.UP; current_surface_state=SurfaceState.AIRBORNE; return

	var detected_normal = Vector2.UP; var new_state = SurfaceState.AIRBORNE
	floor_check.force_raycast_update(); ceiling_check.force_raycast_update()
	wall_check_l.force_raycast_update(); wall_check_r.force_raycast_update()

	if floor_check.is_colliding(): detected_normal=floor_check.get_collision_normal(); new_state=SurfaceState.ON_FLOOR
	elif ceiling_check.is_colliding(): detected_normal=ceiling_check.get_collision_normal(); new_state=SurfaceState.ON_CEILING
	elif wall_check_l.is_colliding(): detected_normal=wall_check_l.get_collision_normal(); new_state=SurfaceState.ON_WALL_L
	elif wall_check_r.is_colliding(): detected_normal=wall_check_r.get_collision_normal(); new_state=SurfaceState.ON_WALL_R
	if new_state != current_surface_state: current_surface_state = new_state
	target_surface_normal = detected_normal.normalized()

# --- Step Location Function ---
func find_valid_step_location(ideal_pos_global: Vector2, anchor_pos_global: Vector2) -> Vector2:
	if not is_inside_tree(): return ideal_pos_global

	var space_state = get_world_2d().direct_space_state
	var ray_start = ideal_pos_global + self.current_up_direction * 5.0
	# Use self.leg_step_distance which is an export var
	var ray_end = ideal_pos_global - self.current_up_direction * (self.leg_step_distance * 1.5)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)

	if result: return result.position
	else: return anchor_pos_global - self.current_up_direction * (self.leg_step_distance * 0.5)

# --- Public Methods ---
func set_target(target: Node2D): # This is now the primary way to start chasing
	if not is_instance_valid(target):
		print("%s: set_target called with invalid target." % name)
		_target_node = null
		if current_ai_state == AIState.CHASING:
			change_ai_state(AIState.IDLE) # Revert to idle if target becomes invalid
		return

	print("%s: Target set externally to %s" % [name, target.name])
	_target_node = target
	# Always switch to chasing when a valid target is set
	if current_ai_state == AIState.IDLE:
		change_ai_state(AIState.CHASING)
