# ProceduralSpider_Pseudo3D.gd (v1.0 - Pseudo 3D Implementation)
extends CharacterBody2D
class_name ProceduralSpider_Pseudo3D # Renamed class

# --- Physics Layer Constants (Adjust values based on your Project Settings) ---
const TERRAIN_LAYER = 1         # Bit = 1 << 0
const PLAYER_PLANE_LAYER = 10   # Bit = 1 << 9
const FOREGROUND_LAYER = 11     # Bit = 1 << 10

# States for surface interaction
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }
# States for depth plane interaction
enum DepthState { PLAYER_PLANE, FOREGROUND, TRANSITIONING }

# --- Exports ---
@export var leg_scene: PackedScene = preload("res://scenes/enemies/spider_leg_3d.tscn") # CHANGE PATH

@export_group("Movement")
@export var move_speed: float = 90.0
@export var acceleration: float = 25.0
@export var turn_speed: float = 8.0
@export var gravity_scale: float = 1.5

@export_group("Legs")
@export var num_legs: int = 10
@export var leg_placement_radius: float = 25.0
@export var leg_step_distance: float = 35.0
@export var max_step_trigger_dist: float = 45.0
@export var leg_step_cooldown: float = 0.1
@export var leg_step_lerp_speed: float = 15.0

@export_group("Leg Visuals")
@export var leg_num_segments: int = 6
@export var leg_base_width: float = 6.0
@export var leg_tip_width: float = 2.0
@export var leg_color: Color = Color(0.1, 0.1, 0.15)
@export var leg_follow_lerp_speed: float = 15.0

@export_group("Body Visuals")
@export var body_radius: float = 15.0
@export var body_points: int = 12
@export var body_radius_variation: float = 0.2
@export var body_color: Color = Color(0.2, 0.05, 0.3)

@export_group("Pseudo 3D")
@export var player_plane_scale: Vector2 = Vector2(1.0, 1.0) # Scale when "far" / on player plane
@export var foreground_scale: Vector2 = Vector2(5.0, 5.0)   # Scale when "close" / in foreground
@export var scale_lerp_speed: float = 5.0                  # How fast scaling happens
@export var foreground_trigger_distance: float = 150.0     # Distance to player to trigger move to foreground
@export var foreground_duration: float = 2.0               # How long to stay in foreground after triggering

# --- Internal Vars ---
var current_surface_state = SurfaceState.AIRBORNE
var current_depth_state = DepthState.PLAYER_PLANE # Start on player plane
var target_surface_normal: Vector2 = Vector2.UP
var current_up_direction: Vector2 = Vector2.UP
var gravity: float = 0.0

var _target_node: Node2D = null
var target_move_velocity: Vector2 = Vector2.ZERO

var legs: Array[SpiderLeg_Pseudo3D] = [] # Expecting the new leg type
var leg_step_timer: float = 0.0
var next_leg_to_step: int = 0

var foreground_timer: float = 0.0 # Timer for how long we stay in foreground
var target_scale: Vector2 = Vector2.ONE # Target scale for lerping

@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var wall_check_r: RayCast2D = $WallCheckRight
@onready var wall_check_l: RayCast2D = $WallCheckLeft
@onready var body_visual: Polygon2D = $Visuals/BodyVisual

# --- Initialization ---
func _ready():
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale
	target_scale = player_plane_scale # Start at player plane scale
	scale = player_plane_scale       # Set initial scale directly

	generate_body_shape()
	spawn_legs()
	update_surface_state()
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0

	# Set initial collision layer/mask based on starting plane
	set_collision_for_depth_state(current_depth_state)

	set_physics_process(true)

func generate_body_shape():
	if not body_visual: return
	body_visual.color = body_color
	var points: PackedVector2Array = []
	for i in range(body_points):
		var angle = TAU * i / body_points
		var radius = body_radius * (1.0 + randf_range(-body_radius_variation, body_radius_variation))
		points.append(Vector2.from_angle(angle) * radius)
	body_visual.polygon = points

func spawn_legs():
	if not leg_scene: printerr("Leg scene not set!"); return
	for leg in legs: if is_instance_valid(leg): leg.queue_free()
	legs.clear()

	var initial_down = -current_up_direction
	var angle_step = TAU / float(num_legs)
	for i in range(num_legs):
		var angle = float(i) * angle_step
		var anchor_pos_local = Vector2.from_angle(angle) * leg_placement_radius
		var leg_instance = leg_scene.instantiate() as SpiderLeg_Pseudo3D
		if not leg_instance: printerr("Failed to instance leg!"); continue
		add_child(leg_instance)
		var initial_anchor_global = to_global(anchor_pos_local)
		var desired_foot_pos = initial_anchor_global + initial_down * leg_step_distance
		var initial_foot_pos = find_valid_step_location(desired_foot_pos, initial_anchor_global)

		if leg_instance.has_method("setup_leg"):
			leg_instance.setup_leg(self, anchor_pos_local, initial_foot_pos, leg_num_segments, leg_base_width, leg_tip_width, leg_color)
			# Pass lerp speed if available
			if leg_instance.has_method("set_follow_lerp_speed"):
				leg_instance.set_follow_lerp_speed(leg_follow_lerp_speed)
			# Set initial Z index based on current depth state
			if leg_instance.has_method("set_leg_z_index"):
				leg_instance.set_leg_z_index(1 if current_depth_state == DepthState.PLAYER_PLANE else 11)

		else: printerr("Leg instance missing setup_leg method!")
		legs.append(leg_instance)


# --- Physics Processing ---
func _physics_process(delta: float):
	# --- State Updates ---
	#state_timer += delta
	update_surface_state()
	update_depth_state(delta) # Manage plane transitions

	# --- Rotation & Alignment ---
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)

	# --- Scale ---
	if scale.distance_squared_to(target_scale) > 0.001:
		scale = scale.lerp(target_scale, scale_lerp_speed * delta)

	# --- Target Movement ---
	target_move_velocity = Vector2.ZERO
	if is_instance_valid(_target_node):
		var vector_to_target_global = _target_node.global_position - global_position
		var surface_direction = current_up_direction.orthogonal()
		var target_dot = vector_to_target_global.normalized().dot(surface_direction)
		# Move only if not transitioning or if allowed during transition
		if current_depth_state != DepthState.TRANSITIONING:
			target_move_velocity = surface_direction * target_dot * move_speed

	# --- Apply Forces ---
	var final_velocity = velocity
	final_velocity += target_surface_normal * gravity * delta # Relative Gravity
	var current_surface_velocity = velocity.slide(current_up_direction)
	# var target_surface_velocity = target_move_velocity.slide(current_up_direction) # Simpler: target_move_velocity is already along surface
	var new_surface_velocity = current_surface_velocity.move_toward(target_move_velocity, acceleration * delta * 60)
	final_velocity = velocity.project(target_surface_normal) + new_surface_velocity # Combine gravity influence + surface movement

	# --- Execute Movement ---
	velocity = final_velocity
	move_and_slide()

	# --- Update Legs ---
	leg_step_timer -= delta
	if leg_step_timer <= 0:
		update_leg_steps()
		leg_step_timer = leg_step_cooldown

# --- State & Movement Helpers ---

func update_surface_state():
	# (Function remains the same as previous version - finds surface normal)
	var detected_normal = Vector2.UP
	var new_state = SurfaceState.AIRBORNE
	floor_check.force_raycast_update(); ceiling_check.force_raycast_update()
	wall_check_l.force_raycast_update(); wall_check_r.force_raycast_update()
	if floor_check.is_colliding(): detected_normal = floor_check.get_collision_normal(); new_state = SurfaceState.ON_FLOOR
	elif ceiling_check.is_colliding(): detected_normal = ceiling_check.get_collision_normal(); new_state = SurfaceState.ON_CEILING
	elif wall_check_l.is_colliding(): detected_normal = wall_check_l.get_collision_normal(); new_state = SurfaceState.ON_WALL_L
	elif wall_check_r.is_colliding(): detected_normal = wall_check_r.get_collision_normal(); new_state = SurfaceState.ON_WALL_R
	if new_state != current_surface_state: current_surface_state = new_state
	target_surface_normal = detected_normal.normalized()

func update_depth_state(delta: float):
	match current_depth_state:
		DepthState.PLAYER_PLANE:
			# Check if player is close enough to trigger move to foreground
			if is_instance_valid(_target_node):
				var dist_sq = global_position.distance_squared_to(_target_node.global_position)
				if dist_sq < foreground_trigger_distance * foreground_trigger_distance:
					move_to_foreground() # Initiate transition

		DepthState.FOREGROUND:
			# Countdown timer to return to player plane
			foreground_timer -= delta
			if foreground_timer <= 0:
				move_to_player_plane() # Initiate transition back

		DepthState.TRANSITIONING:
			# Currently just waiting for scale lerp, could add more logic
			# Check if scale is close enough to target to finish transition
			if scale.distance_squared_to(target_scale) < 0.01:
				if target_scale == foreground_scale:
					current_depth_state = DepthState.FOREGROUND
					foreground_timer = foreground_duration # Start the timer
				else:
					current_depth_state = DepthState.PLAYER_PLANE
				# print("Transition complete to ", DepthState.keys()[current_depth_state]) # Debug

func move_to_foreground():
	if current_depth_state == DepthState.FOREGROUND: return # Already there
	print("%s: Moving to Foreground Plane" % name) # Debug
	current_depth_state = DepthState.TRANSITIONING
	target_scale = foreground_scale
	set_collision_for_depth_state(DepthState.FOREGROUND)
	# Set Z-index (higher value = visually in front)
	z_index = 10
	if is_instance_valid(body_visual): body_visual.z_index = 0 # Relative to parent
	for leg in legs:
		if is_instance_valid(leg) and leg.has_method("set_leg_z_index"):
			leg.set_leg_z_index(1) # Relative to parent

func move_to_player_plane():
	if current_depth_state == DepthState.PLAYER_PLANE: return # Already there
	print("%s: Moving to Player Plane" % name) # Debug
	current_depth_state = DepthState.TRANSITIONING
	target_scale = player_plane_scale
	set_collision_for_depth_state(DepthState.PLAYER_PLANE)
	# Reset Z-index
	z_index = 0
	if is_instance_valid(body_visual): body_visual.z_index = 0
	for leg in legs:
		if is_instance_valid(leg) and leg.has_method("set_leg_z_index"):
			leg.set_leg_z_index(0)

func set_collision_for_depth_state(state: DepthState):
	# Mask should ALWAYS include terrain layer for movement casts
	var terrain_mask = 1 << (TERRAIN_LAYER - 1) # Bitmask for terrain layer
	collision_mask = terrain_mask

	if state == DepthState.PLAYER_PLANE:
		# Layer allows interaction with player plane attacks
		var layer_bit = 1 << (PLAYER_PLANE_LAYER - 1)
		collision_layer = layer_bit
	elif state == DepthState.FOREGROUND:
		# Layer prevents interaction with player plane attacks
		var layer_bit = 1 << (FOREGROUND_LAYER - 1)
		collision_layer = layer_bit
	elif state == DepthState.TRANSITIONING:
		# While transitioning, maybe be on foreground layer to avoid hits?
		var layer_bit = 1 << (FOREGROUND_LAYER - 1)
		collision_layer = layer_bit

func update_leg_steps():
	# (Function remains the same as previous version - calculates ideal pos and calls start_step)
	if legs.is_empty(): return
	var leg_index = next_leg_to_step
	if leg_index >= legs.size(): next_leg_to_step = 0; return
	var leg = legs[leg_index]
	if not is_instance_valid(leg) or leg.is_stepping: next_leg_to_step = (leg_index + 1) % num_legs; return
	var ideal_foot_global = to_global(leg.base_anchor_local) - current_up_direction * leg_step_distance
	var dist_sq = leg.current_foot_global.distance_squared_to(ideal_foot_global)
	if dist_sq > max_step_trigger_dist * max_step_trigger_dist:
		var step_target_global = find_valid_step_location(ideal_foot_global, to_global(leg.base_anchor_local))
		leg.start_step(step_target_global)
	next_leg_to_step = (leg_index + 1) % num_legs

func find_valid_step_location(ideal_pos_global: Vector2, anchor_pos_global: Vector2) -> Vector2:
	# (Function remains the same as previous version - finds surface point)
	var space_state = get_world_2d().direct_space_state
	var ray_start = ideal_pos_global + current_up_direction * 5.0
	var ray_end = ideal_pos_global - current_up_direction * (leg_step_distance * 1.5)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)
	if result: return result.position
	else: return anchor_pos_global - current_up_direction * (leg_step_distance * 0.5)

# --- Public Methods ---
func set_target(target: Node2D):
	_target_node = target

# --- Helper Functions ---
const EASE_OUT_IN = 2.0
func ease(x: float, power: float) -> float: if x<0.5: return pow(2.0*x,power)/2.0 
else: 
	return 1.0-pow(2.0*(1.0-x),power)/2.0

# --- Optional: Health, Damage, Death logic ---
# func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0): ...
# func die(): ...
# func play_death_effects(): ...
