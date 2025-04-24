# Tentacle.gd (v6.0 - Clean baseline for Carrion AI)
extends Node2D
class_name Tentacle

# --- Exports ---
@export_group("Structure & Movement")
@export var num_segments: int = 8         # Points defining the leg's curve (Anchor + N points + Foot)
@export var reach_distance: float = 180.0 # How far the tip can reach from the anchor
@export var attach_check_radius: float = 10.0 # How close target needs to be to surface for successful attach
@export var pull_stiffness: float = 8.0   # How strongly it resists stretching when attached (Visual only for now)
@export var retraction_speed: float = 15.0# Speed when tip returns to body
@export var reach_lerp_speed: float = 18.0 # Speed when tip moves towards target
@export var follow_lerp_speed: float = 15.0# How quickly internal segments follow
@export var reach_cooldown: float = 0.2   # Min time between new reach attempts

@export_group("Visuals")
@export var base_width: float = 10.0      # Width near body
@export var tip_width: float = 3.0        # Width at foot/tip
@export var color: Color = Color(0.5, 0.1, 0.7) # Default color

# --- State ---
enum TentacleState { IDLE, REACHING, ATTACHED, RETRACTING }
var current_state = TentacleState.IDLE
var state_timer: float = 0.0 # Generic timer if needed by states
var reach_cooldown_timer: float = 0.0

# --- References & Positions ---
var body_node: CharacterBody2D = null       # Reference to the main CarrionBody
var attached_point_global: Vector2 = Vector2.ZERO # World position where tip is stuck
var target_reach_global: Vector2 = Vector2.ZERO   # World position the tip is trying to reach

# --- Internal Spine ---
var spine_points: Array[Vector2] = []       # Stores GLOBAL positions of the tentacle spine points
@onready var visual_polygon: Polygon2D = $TentacleVisual # Reference to the child Polygon2D

# --- Initialization ---
func _ready():
	# Validate child node
	if visual_polygon == null:
		printerr("%s: Missing TentacleVisual child node (Polygon2D)!" % name)
		set_process(false)
		set_physics_process(false)
		return

	# Initialize the points array - Size must be at least 2 (anchor + tip)
	if num_segments < 2:
		printerr("%s: num_segments must be at least 2!" % name)
		num_segments = 2
	spine_points.resize(num_segments)
	if spine_points.size() != num_segments:
		printerr("%s: Failed to resize spine_points array!" % name)
		set_process(false)
		set_physics_process(false)
		return

	# Set initial visual properties
	visual_polygon.color = color

	# Use _process for visual updates which might not need physics precision
	set_process(true)
	# Enable physics process ONLY if needed for specific state logic (currently not)
	# set_physics_process(false)

func _process(delta: float):
	# Check if body reference is valid
	if not is_instance_valid(body_node) or spine_points.size() < 2:
		# Body might have been destroyed, or initialization failed
		queue_free() # Remove self if body is gone
		return

	# Update timers
	state_timer += delta
	if reach_cooldown_timer > 0:
		reach_cooldown_timer -= delta

	# --- 1. Update Anchor Point (Point 0) ---
	# The base of the tentacle always matches the global position of this node
	spine_points[0] = global_position # This node *is* the anchor

	# --- 2. Update Tip Position based on State ---
	var foot_index = spine_points.size() - 1
	match current_state:
		TentacleState.IDLE:
			# Retract tip smoothly towards the body anchor
			var target_pos = spine_points[0] # Retract fully to anchor
			spine_points[foot_index] = spine_points[foot_index].lerp(target_pos, retraction_speed * delta)

		TentacleState.REACHING:
			# Move the tip towards the target_reach_global position
			spine_points[foot_index] = spine_points[foot_index].lerp(target_reach_global, reach_lerp_speed * delta)

			# Check conditions to stop reaching
			var dist_to_target_sq = spine_points[foot_index].distance_squared_to(target_reach_global)
			var dist_to_body_sq = spine_points[foot_index].distance_squared_to(spine_points[0])

			if dist_to_target_sq < 25.0: # Reached close enough to the target point
				try_attach(spine_points[foot_index]) # Attempt to latch onto a surface there
			elif dist_to_body_sq > reach_distance * reach_distance or state_timer > 1.5: # Exceeded reach or timed out
				retract() # Give up and pull back

		TentacleState.ATTACHED:
			# Tip stays fixed at the point it attached to
			spine_points[foot_index] = attached_point_global

		TentacleState.RETRACTING:
			# Move tip back towards the body anchor
			var target_pos = spine_points[0]
			spine_points[foot_index] = spine_points[foot_index].lerp(target_pos, retraction_speed * delta)
			# If tip is close enough to the anchor, become idle
			if spine_points[foot_index].distance_squared_to(target_pos) < 100.0:
				change_state(TentacleState.IDLE)

	# --- 3. Update Intermediate Segment Positions (Chain following) ---
	update_intermediate_points(delta)

	# --- 4. Update the Polygon Visual ---
	update_tentacle_polygon()


# --- Helper Functions ---

func update_intermediate_points(delta: float):
	# Needs at least 3 points (anchor, middle, tip) to have intermediate points
	if spine_points.size() < 3: return

	# Calculate desired segment length based on current anchor-to-tip distance
	var anchor_pos = spine_points[0]
	var foot_pos = spine_points[-1]
	var total_current_length = anchor_pos.distance_to(foot_pos)
	var target_segment_length = total_current_length / max(1.0, float(num_segments - 1))
	# Tolerance to prevent micro-movements when length is correct
	var segment_length_sq_tolerance = (target_segment_length * 0.1) * (target_segment_length * 0.1)

	# Update points from the tip backwards towards the anchor
	for i in range(num_segments - 2, 0, -1): # Iterate from second-to-last down to point 1
		var leader_pos = spine_points[i+1] # Point closer to the tip
		var current_pos = spine_points[i]
		var vector_to_leader = leader_pos - current_pos
		var dist_sq = vector_to_leader.length_squared()

		# Only adjust if not already close enough to target length
		if dist_sq > segment_length_sq_tolerance:
			# Avoid normalizing zero vector
			if vector_to_leader.length_squared() < 0.0001: continue

			var direction_to_leader = vector_to_leader.normalized()
			# Target position is 'target_segment_length' away from leader, back towards anchor
			var target_pos = leader_pos - direction_to_leader * target_segment_length
			# Lerp towards the calculated target position
			spine_points[i] = current_pos.lerp(target_pos, follow_lerp_speed * delta)

func update_tentacle_polygon():
	# Generates the polygon vertices based on the current spine_points
	if spine_points.size() < 2:
		visual_polygon.polygon = PackedVector2Array([])
		return

	var vertices: PackedVector2Array = []
	var num_spine_points = spine_points.size()
	var left_verts: Array[Vector2] = []
	var right_verts: Array[Vector2] = []
	var last_valid_forward_dir = Vector2.RIGHT # Remember last good direction for fallbacks

	for i in range(num_spine_points):
		var current_spine_point_global = spine_points[i]
		var forward_dir: Vector2 = Vector2.ZERO

		# Calculate robust forward direction
		if i == 0: # Anchor point
			if num_spine_points > 1 and (spine_points[1] - current_spine_point_global).length_squared() > 0.001:
				forward_dir = (spine_points[1] - current_spine_point_global).normalized()
			else: forward_dir = last_valid_forward_dir # Use last known good if points overlap
		elif i == num_spine_points - 1: # Tip point
			# Check if previous point exists and is different
			if i > 0 and (current_spine_point_global - spine_points[i-1]).length_squared() > 0.001:
				forward_dir = (current_spine_point_global - spine_points[i-1]).normalized()
			else: forward_dir = last_valid_forward_dir # Use last known good
		else: # Middle points
			# Ensure adjacent points exist and calculate vectors
			var next_vec = spine_points[i+1] - current_spine_point_global if (i+1 < num_spine_points) else Vector2.ZERO
			var prev_vec = current_spine_point_global - spine_points[i-1] if (i > 0) else Vector2.ZERO
			# Average valid, non-opposing directions
			if next_vec.length_squared() > 0.001 and prev_vec.length_squared() > 0.001 and next_vec.dot(prev_vec) > -0.9:
				forward_dir = (next_vec.normalized() + prev_vec.normalized()).normalized()
			elif prev_vec.length_squared() > 0.001: # Fallback to previous segment direction
				forward_dir = prev_vec.normalized()
			elif next_vec.length_squared() > 0.001: # Fallback to next segment direction
				forward_dir = next_vec.normalized()
			else: # Fallback to last known good
				forward_dir = last_valid_forward_dir

		# Final check for zero vector and update last known good
		if forward_dir.length_squared() < 0.001:
			forward_dir = last_valid_forward_dir
		else:
			last_valid_forward_dir = forward_dir

		# Calculate perpendicular and width
		var perpendicular_dir = forward_dir.orthogonal()
		var t = float(i) / max(1.0, float(num_spine_points - 1))
		var current_width = lerp(base_width, tip_width, t)

		# Convert GLOBAL spine point to LOCAL coordinates for the Polygon2D
		# Since this script is on the Tentacle Node2D which *is* the anchor point,
		# local coords are relative to the anchor point.
		var local_spine_point = to_local(current_spine_point_global)

		# Add vertices for the polygon outline
		left_verts.append(local_spine_point + perpendicular_dir * current_width * 0.5)
		right_verts.append(local_spine_point - perpendicular_dir * current_width * 0.5)

	# Combine vertices into the final polygon array
	vertices.append_array(PackedVector2Array(left_verts))
	right_verts.reverse() # Reverse the right side
	vertices.append_array(PackedVector2Array(right_verts)) # Append reversed right side
	visual_polygon.polygon = vertices


# --- Public Methods Called by CarrionBody ---
func setup_tentacle(body: CharacterBody2D):
	body_node = body
	# Initial placement of spine points (can be refined)
	if spine_points.size() == num_segments:
		spine_points[0] = body_node.global_position
		for i in range(1, num_segments):
			# Simple initial layout, maybe straight out based on node rotation?
			var dir = Vector2.RIGHT.rotated(body_node.rotation) # Example initial direction
			spine_points[i] = spine_points[0] + dir * i * (reach_distance / num_segments)
	else:
		printerr("%s: Spine points not initialized correctly in setup!" % name)


func reach_for(target_global: Vector2):
	# Only allow starting a reach if idle/retracting and cooldown is ready
	if (current_state == TentacleState.IDLE or current_state == TentacleState.RETRACTING) and reach_cooldown_timer <= 0:
		target_reach_global = target_global
		change_state(TentacleState.REACHING)
		state_timer = 0.0 # Reset state timer for timeout
		reach_cooldown_timer = reach_cooldown # Start cooldown

func try_attach(potential_pos: Vector2):
	# Use physics space to check for terrain collision near the target point
	var space_state = get_world_2d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters2D.new()
	var query_shape = CircleShape2D.new()
	query_shape.radius = attach_check_radius
	shape_query.shape = query_shape
	shape_query.transform = Transform2D(0, potential_pos) # Center check at potential pos
	# Ensure collision mask is set correctly on the body node
	shape_query.collision_mask = body_node.collision_mask
	shape_query.exclude = [body_node] # Don't attach to self

	var results = space_state.intersect_shape(shape_query)

	if results.size() > 0:
		# Successfully hit terrain!
		attached_point_global = potential_pos # Attach where the tip landed
		spine_points[-1] = attached_point_global # Lock the tip position
		change_state(TentacleState.ATTACHED)
	else:
		# Missed the surface
		retract() # Pull back

func detach():
	# Force detachment if currently attached
	if current_state == TentacleState.ATTACHED:
		retract()

func retract():
	# Initiate retraction towards the body anchor
	change_state(TentacleState.RETRACTING)
	state_timer = 0.0

func change_state(new_state: TentacleState):
	# Optional: Add logic here if needed when changing states
	# print("%s changing state to %s" % [name, TentacleState.keys()[new_state]]) # Debug
	current_state = new_state

# --- Getters ---
func is_attached() -> bool:
	return current_state == TentacleState.ATTACHED

func get_anchor_point_global() -> Vector2:
	# Returns the point where the tentacle is attached to a surface
	return attached_point_global if current_state == TentacleState.ATTACHED else Vector2.INF

func can_reach() -> bool:
	# Check if the tentacle is ready to start a new reach attempt
	return reach_cooldown_timer <= 0 and (current_state == TentacleState.IDLE or current_state == TentacleState.RETRACTING)

# --- Setters (Optional) ---
func set_follow_lerp_speed(speed: float):
	follow_lerp_speed = speed
