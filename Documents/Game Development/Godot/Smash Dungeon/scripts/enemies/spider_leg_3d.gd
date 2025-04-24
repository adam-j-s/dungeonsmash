# SpiderLeg_Pseudo3D.gd (Based on v5.1 single polygon logic)
extends Node2D
class_name SpiderLeg_Pseudo3D # Renamed class

# --- Exports (for visual tuning within the leg) ---
@export var num_leg_segments: int = 6 # Points defining the leg's curve (Anchor + N points + Foot)
@export var leg_base_width: float = 6.0
@export var leg_tip_width: float = 2.0
@export var leg_follow_lerp_speed: float = 15.0 # How quickly internal segments follow

@onready var polygon_visual: Polygon2D = $LegPolygonVisual # Assumes this node exists

# --- IK and Body Connection ---
var ik_target_global: Vector2 = Vector2.ZERO   # Target position for the foot
var current_foot_global: Vector2 = Vector2.ZERO # Actual current foot position (last point in leg_points)
var base_anchor_local: Vector2 = Vector2.ZERO   # Attach point on body (relative to body)
var spider_body: CharacterBody2D = null         # Reference to main body

# --- State ---
var is_stepping: bool = false
var step_lerp_speed: float = 15.0 # How fast the *entire foot target* moves during a step

# --- Internal Spine ---
var leg_points: Array[Vector2] = [] # Stores GLOBAL positions of the leg spine points
var leg_color: Color = Color.BLACK

func _ready():
	if polygon_visual == null:
		printerr("%s: Missing LegPolygonVisual node!" % name)
		set_process(false)
		return

	# Initialize the points array
	leg_points.resize(num_leg_segments)
	if leg_points.size() != num_leg_segments:
		printerr("%s: Failed to resize leg_points!" % name)
		set_process(false)
		return

	polygon_visual.color = leg_color
	set_process(true) # Use _process for visual updates

func _process(delta: float):
	if not is_instance_valid(spider_body) or leg_points.size() < 2:
		queue_free()
		return

	# --- 1. Update Anchor Point ---
	var base_anchor_global = spider_body.to_global(base_anchor_local)
	global_position = base_anchor_global # Keep the Node2D itself at the anchor
	leg_points[0] = base_anchor_global

	# --- 2. Move the IK Foot Target (if stepping) ---
	if is_stepping:
		var foot_index = leg_points.size() - 1
		leg_points[foot_index] = leg_points[foot_index].lerp(ik_target_global, step_lerp_speed * delta)
		if leg_points[foot_index].distance_squared_to(ik_target_global) < 1.0:
			leg_points[foot_index] = ik_target_global
			is_stepping = false
			current_foot_global = leg_points[foot_index]
	else:
		current_foot_global = leg_points[-1]


	# --- 3. Update Intermediate Segment Positions ---
	var segment_length_sq_threshold = 0.01 # Avoid division by zero
	var segment_length = current_foot_global.distance_to(base_anchor_global) / max(1.0, float(num_leg_segments - 1))

	for i in range(num_leg_segments - 2, 0, -1): # Iterate backwards from foot
		var leader_pos = leg_points[i+1]
		var current_pos = leg_points[i]
		var vector_to_leader = leader_pos - current_pos
		var dist_sq = vector_to_leader.length_squared()

		if dist_sq > segment_length_sq_threshold:
			var direction_to_leader = vector_to_leader.normalized()
			var target_pos = leader_pos - direction_to_leader * segment_length
			leg_points[i] = current_pos.lerp(target_pos, leg_follow_lerp_speed * delta)

	# --- 4. Update the Polygon Visual ---
	update_leg_polygon()

# --- Visual Update ---
func update_leg_polygon():
	var vertices: PackedVector2Array = []
	var num_spine_points = leg_points.size()
	if num_spine_points < 2:
		polygon_visual.polygon = vertices
		return

	var left_verts: Array[Vector2] = []
	var right_verts: Array[Vector2] = []
	var last_valid_forward_dir = Vector2.RIGHT

	for i in range(num_spine_points):
		var current_spine_point_global = leg_points[i]
		var forward_dir: Vector2 = Vector2.ZERO

		# Calculate Target Forward Direction (Robust calculation from previous fix)
		if i == 0: # Anchor point
			if num_spine_points > 1 and (leg_points[1] - current_spine_point_global).length_squared() > 0.001:
				forward_dir = (leg_points[1] - current_spine_point_global).normalized()
			else: forward_dir = last_valid_forward_dir
		elif i == num_spine_points - 1: # Foot point
			if (current_spine_point_global - leg_points[i-1]).length_squared() > 0.001:
				forward_dir = (current_spine_point_global - leg_points[i-1]).normalized()
			else: forward_dir = last_valid_forward_dir
		else: # Middle points
			var next_vec = leg_points[i+1] - current_spine_point_global
			var prev_vec = current_spine_point_global - leg_points[i-1]
			if next_vec.length_squared() > 0.001 and prev_vec.length_squared() > 0.001 and next_vec.dot(prev_vec) > -0.9:
				forward_dir = (next_vec.normalized() + prev_vec.normalized()).normalized()
			elif prev_vec.length_squared() > 0.001: forward_dir = prev_vec.normalized()
			else: forward_dir = last_valid_forward_dir

		if forward_dir.length_squared() < 0.001: forward_dir = last_valid_forward_dir
		else: last_valid_forward_dir = forward_dir

		var perpendicular_dir = forward_dir.orthogonal()
		var t = float(i) / max(1.0, float(num_spine_points - 1))
		var current_width = lerp(leg_base_width, leg_tip_width, t)
		# Convert GLOBAL spine point to LOCAL coords for the polygon
		var local_spine_point = to_local(current_spine_point_global)

		left_verts.append(local_spine_point + perpendicular_dir * current_width * 0.5)
		right_verts.append(local_spine_point - perpendicular_dir * current_width * 0.5)

	vertices.append_array(PackedVector2Array(left_verts))
	right_verts.reverse()
	vertices.append_array(PackedVector2Array(right_verts))
	polygon_visual.polygon = vertices


# --- Control Functions ---
func start_step(target_global_pos: Vector2):
	ik_target_global = target_global_pos
	is_stepping = true

func setup_leg(body: CharacterBody2D, anchor_loc: Vector2, initial_foot_glob: Vector2, seg_count: int, base_w: float, tip_w: float, color: Color):
	spider_body = body
	base_anchor_local = anchor_loc
	current_foot_global = initial_foot_glob
	ik_target_global = initial_foot_glob
	num_leg_segments = seg_count
	leg_base_width = base_w
	leg_tip_width = tip_w
	leg_color = color

	leg_points.resize(num_leg_segments)
	if leg_points.size() == num_leg_segments:
		var base_anchor_glob = spider_body.to_global(base_anchor_local)
		global_position = base_anchor_glob
		leg_points[0] = base_anchor_glob
		leg_points[leg_points.size() - 1] = initial_foot_glob
		for i in range(1, num_leg_segments - 1):
			var t = float(i) / float(num_leg_segments - 1)
			leg_points[i] = base_anchor_glob.lerp(initial_foot_glob, t)
	else: printerr("%s: Failed resize in setup!" % name)

	if polygon_visual: polygon_visual.color = leg_color

# NEW: Function to set Z-index
func set_leg_z_index(index: int):
	z_index = index
