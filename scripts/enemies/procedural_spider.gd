# ProceduralSpider.gd (v6.1 - Body Visual + Segmented Polygon Legs)
extends CharacterBody2D
class_name ProceduralSpider

# States
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }

# --- Exports ---
# Reference the SpiderLeg scene that uses Polygon2D
@export var leg_scene: PackedScene = preload("res://scenes/enemies/spider_leg.tscn") # CHANGE PATH

@export_group("Movement")
@export var move_speed: float = 90.0
@export var acceleration: float = 25.0
@export var turn_speed: float = 8.0 # How fast body rotates to align with surface normal
@export var gravity_scale: float = 1.5 # Needs gravity to stick!

@export_group("Leg Structure & Stepping")
@export var num_legs: int = 10
@export var leg_placement_radius: float = 25.0 # How far from center legs attach (Adjust if body added)
@export var leg_step_distance: float = 35.0   # How far a leg ideally reaches from anchor
@export var max_step_trigger_dist: float = 45.0 # If foot is further than this from ideal pos, trigger step
@export var leg_step_cooldown: float = 0.1    # Min time between steps for *different* legs (Faster stepping)
@export var leg_step_lerp_speed: float = 15.0   # How fast the foot moves to target during a step

@export_group("Leg Visuals (Segmented Polygon)")
@export var leg_num_segments: int = 6     # Points in each leg's spine (Anchor + N + Foot)
@export var leg_base_width: float = 6.0   # Width near body
@export var leg_tip_width: float = 2.0    # Width at foot
@export var leg_color: Color = Color(0.1, 0.1, 0.15)
@export var leg_follow_lerp_speed: float = 15.0 # How fast internal segments follow

@export_group("Body Visuals")
@export var body_radius: float = 15.0
@export var body_points: int = 12
@export var body_radius_variation: float = 0.2
@export var body_color: Color = Color(0.2, 0.05, 0.3) # Darker core color

# --- Internal Vars ---
var current_surface_state = SurfaceState.AIRBORNE # Start assuming airborne
var target_surface_normal: Vector2 = Vector2.UP   # The normal of the surface we want to stick to
var current_up_direction: Vector2 = Vector2.UP    # The spider's current perceived "up"
var gravity: float = 0.0

var _target_node: Node2D = null
var target_move_velocity: Vector2 = Vector2.ZERO # Desired velocity along the surface

var legs: Array[SpiderLeg] = [] # Array now holds instances of the *segmented* SpiderLeg script
var leg_step_timer: float = 0.0
var next_leg_to_step: int = 0

@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var wall_check_r: RayCast2D = $WallCheckRight
@onready var wall_check_l: RayCast2D = $WallCheckLeft
@onready var body_visual: Polygon2D = $Visuals/BodyVisual # Make sure this path is correct

# --- Initialization ---
func _ready():
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale

	# Generate body visual first
	generate_body_shape()

	# Now spawn legs (using the segmented polygon leg scene)
	spawn_legs()

	# Force initial surface check & alignment
	update_surface_state()
	# Avoid lerping from default Vector2.UP if already on a surface
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0 # Align rotation instantly

	set_physics_process(true)

func generate_body_shape():
	if not body_visual:
		print("%s: BodyVisual node not found at path $Visuals/BodyVisual." % name)
		return
	body_visual.color = body_color
	var points: PackedVector2Array = []
	for i in range(body_points):
		var angle = TAU * i / body_points
		var radius = body_radius * (1.0 + randf_range(-body_radius_variation, body_radius_variation))
		points.append(Vector2.from_angle(angle) * radius)
	body_visual.polygon = points

func spawn_legs():
	if not leg_scene:
		printerr("Leg scene not set!"); return

	# Remove existing legs if respawning
	for leg in legs:
		if is_instance_valid(leg): leg.queue_free()
	legs.clear()

	# Need to know the initial 'down' direction to place feet
	var initial_down = -current_up_direction # Use the already determined 'up'

	var angle_step = TAU / float(num_legs)
	for i in range(num_legs):
		var angle = float(i) * angle_step
		# Calculate anchor position relative to body center
		var anchor_pos_local = Vector2.from_angle(angle) * leg_placement_radius

		var leg_instance = leg_scene.instantiate() as SpiderLeg # Expecting the segmented leg script now
		if not leg_instance:
			printerr("Failed to instance leg scene or it's not of type SpiderLeg!"); continue

		add_child(leg_instance) # Add leg as child of spider body

		# --- Initial Foot Placement ---
		var initial_anchor_global = to_global(anchor_pos_local)
		var desired_foot_pos = initial_anchor_global + initial_down * leg_step_distance
		var initial_foot_pos = find_valid_step_location(desired_foot_pos, initial_anchor_global)

		# Call the setup function on the segmented leg script
		# Make sure SpiderLeg.gd has this exact setup_leg function signature
		if leg_instance.has_method("setup_leg"):
			leg_instance.setup_leg(
				self,                # body reference
				anchor_pos_local,    # anchor_local
				initial_foot_pos,    # initial_foot_global
				leg_num_segments,    # seg_count
				leg_base_width,      # base_w
				leg_tip_width,       # tip_w
				leg_color            # color
				# Pass leg_follow_lerp_speed if setup_leg accepts it
			)
			# Pass other parameters if needed (like follow lerp speed)
			if leg_instance.has_method("set_follow_lerp_speed"): # Example
				leg_instance.set_follow_lerp_speed(leg_follow_lerp_speed)

		else:
			printerr("Instantiated leg scene is missing the required setup_leg method!")
			leg_instance.global_position = initial_anchor_global # Basic fallback

		legs.append(leg_instance)

# --- Physics Processing ---
func _physics_process(delta: float):
	# 1. Determine Target Surface and Up Direction
	update_surface_state()
	# Smoothly rotate body's perceived UP towards the target surface normal's opposite
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	# Rotate the physics body itself
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)

	# 2. Calculate Target Movement Velocity (relative to surface)
	target_move_velocity = Vector2.ZERO
	if is_instance_valid(_target_node):
		var vector_to_target_global = _target_node.global_position - global_position
		var surface_direction = current_up_direction.orthogonal() # Direction along the surface
		var target_dot = vector_to_target_global.normalized().dot(surface_direction)
		target_move_velocity = surface_direction * target_dot * move_speed

	# 3. Apply Forces (Gravity + Movement)
	var final_velocity = velocity
	# Apply gravity pulling towards the surface
	final_velocity += target_surface_normal * gravity * delta
	# Apply surface movement acceleration
	var current_surface_velocity = velocity.slide(current_up_direction)
	var target_surface_velocity = target_move_velocity # Already calculated along surface dir
	var new_surface_velocity = current_surface_velocity.move_toward(target_surface_velocity, acceleration * delta * 60)
	# Reconstruct velocity: component towards surface + component along surface
	final_velocity = velocity.project(target_surface_normal) + new_surface_velocity # Project onto normal for gravity part

	# 4. Execute Movement
	velocity = final_velocity
	move_and_slide()

	# 5. Update Legs Periodically
	leg_step_timer -= delta
	if leg_step_timer <= 0:
		update_leg_steps()
		leg_step_timer = leg_step_cooldown # Reset timer

# --- State & Movement Helpers ---
func update_surface_state():
	# Prioritize detection: Floor > Ceiling > Walls > Airborne
	var detected_normal = Vector2.UP # Default: gravity pulls down
	var new_state = SurfaceState.AIRBORNE

	floor_check.force_raycast_update()
	ceiling_check.force_raycast_update()
	wall_check_l.force_raycast_update()
	wall_check_r.force_raycast_update()

	# Check collision results and assign normal/state
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

	# Update state if changed
	if new_state != current_surface_state:
		# print("Surface State Change: ", SurfaceState.keys()[current_surface_state], " -> ", SurfaceState.keys()[new_state] ) # Debug
		current_surface_state = new_state

	# Target normal drives gravity direction
	target_surface_normal = detected_normal.normalized() # Ensure it's normalized

func update_leg_steps():
	if legs.is_empty(): return

	# Cycle through legs to step one at a time
	var leg_index = next_leg_to_step
	# Ensure index is valid (safety check)
	if leg_index >= legs.size():
		next_leg_to_step = 0
		return

	var leg = legs[leg_index]
	if not is_instance_valid(leg) or leg.is_stepping:
		next_leg_to_step = (leg_index + 1) % num_legs # Try next leg next time
		return

	# Calculate the ideal position for this foot relative to the body's current orientation
	# Note: leg.base_anchor_local is relative to spider body origin
	var ideal_foot_global = to_global(leg.base_anchor_local) - current_up_direction * leg_step_distance

	# Check distance from the leg's *current actual foot position* to the ideal spot
	var dist_sq = leg.current_foot_global.distance_squared_to(ideal_foot_global)

	# If foot is too far from its ideal spot, find a new valid surface point and start stepping
	if dist_sq > max_step_trigger_dist * max_step_trigger_dist:
		var step_target_global = find_valid_step_location(ideal_foot_global, to_global(leg.base_anchor_local))
		leg.start_step(step_target_global) # Tell the leg to move its foot towards the target

	# Move to the next leg for the subsequent step check cycle
	next_leg_to_step = (leg_index + 1) % num_legs

func find_valid_step_location(ideal_pos_global: Vector2, anchor_pos_global: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	# Ray starts slightly 'above' ideal pos (relative to spider up)
	var ray_start = ideal_pos_global + current_up_direction * 5.0
	# Cast 'down' (relative to spider up)
	var ray_end = ideal_pos_global - current_up_direction * (leg_step_distance * 1.5)

	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)

	if result:
		return result.position # Found surface
	else:
		# No surface found, fallback towards anchor point to prevent overstretching
		return anchor_pos_global - current_up_direction * (leg_step_distance * 0.5)

# --- Public Methods ---
func set_target(target: Node2D):
	_target_node = target

# --- Helper Functions ---
const EASE_OUT_IN = 2.0
func ease(x: float, power: float) -> float:
	if x < 0.5: return pow(2.0 * x, power) / 2.0
	else: return 1.0 - pow(2.0 * (1.0 - x), power) / 2.0

# --- Optional: Health, Damage, Death logic ---
# func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0): ...
# func die(): ...
# func play_death_effects(): ...
