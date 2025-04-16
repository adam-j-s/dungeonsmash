# SlitheringLimb.gd (v5.1 - Reverted to First Working Single Polygon State)
extends Node2D
class_name SlitheringLimb

# --- Exports ---
@export var head_scene: PackedScene = preload("res://scenes/enemies/limb_head.tscn") # CHANGE PATH

@export_group("Limb Structure")
@export var num_segments: int = 10 # Total points in the spine (Head + N virtual followers)
@export var segment_distance: float = 10.0 # Desired spacing between spine points
@export var follow_lerp_speed: float = 12.0 # How quickly follower points catch up (higher = stiffer)

@export_group("Head Properties")
@export var head_move_speed: float = 80.0
@export var head_acceleration: float = 15.0

@export_group("Visual Appearance")
@export var limb_base_width: float = 20.0 # Width at the head
@export var limb_tip_width: float = 4.0  # Width at the tail
@export var base_color: Color = Color(0.4, 0.1, 0.6) # Base purple/dark color
@export var color_variation_hue: float = 0.05
@export var color_variation_sat: float = 0.1
@export var color_variation_val: float = 0.1

# --- Variables ---
var follow_points: Array[Vector2] = [] # Stores the spine points' global positions
var limb_color: Color = Color.WHITE    # Actual color for this instance

@onready var head_node: LimbHead = $Head
@onready var limb_visual: Polygon2D = $LimbVisual

var _target_node: Node2D = null

# --- Initialization (Version causing startup stretch) ---
func _ready():
	# Basic checks for required nodes
	if head_scene == null:
		printerr("%s: Head scene not assigned!" % name)
		set_process(false); set_physics_process(false)
		return
	if head_node == null or limb_visual == null:
		printerr("%s: Missing required child node 'Head' (LimbHead) or 'LimbVisual' (Polygon2D)!" % name)
		set_process(false); set_physics_process(false)
		return

	# --- NO await head_node.ready here in this specific reverted version ---
	# This might cause issues if head setup is complex, but matches the state
	# where the stretch occurred but drawing likely worked initially.

	# Initialize head properties (might run before head is fully ready without await)
	head_node.move_speed = head_move_speed
	head_node.acceleration = head_acceleration

	# Initialize Follow Points array size
	follow_points.resize(num_segments)
	if follow_points.size() != num_segments:
		printerr("%s: Failed to resize follow_points array!" % name)
		set_process(false); set_physics_process(false)
		return

	# Initialize points based on head's position *at this moment* in _ready
	# This is the source of the initial stretch if head is moved later.
	var start_pos = head_node.global_position
	for i in range(num_segments):
		follow_points[i] = start_pos - Vector2(i * segment_distance, 0) # Assume facing right

	# Generate initial instance color
	limb_color = generate_randomized_color(base_color, color_variation_hue, color_variation_sat, color_variation_val)
	limb_visual.color = limb_color

	# Start processing
	set_physics_process(true)
	print("%s: Initialized single-polygon limb (v5.1 - Reverted State)." % name)

	# Apply target if already set
	if _target_node:
		set_target(_target_node)


# --- Physics Processing ---
func _physics_process(delta: float):
	# Ensure head is still valid
	if not is_instance_valid(head_node):
		print("%s: Head node lost!" % name)
		queue_free()
		return

	# Check if follow_points was initialized correctly (basic check)
	if follow_points.size() == 0: # Check if empty (should have been resized in ready)
		print("%s: follow_points array is empty in physics process!" % name)
		set_physics_process(false)
		return

	# 1. Update the first spine point to the head's current position
	follow_points[0] = head_node.global_position

	# 2. Update the rest of the spine points to follow the one ahead
	for i in range(1, num_segments):
		# Ensure index is valid before accessing (safety)
		if i >= follow_points.size() or i-1 >= follow_points.size():
			printerr("%s: Index out of bounds in follow loop (i=%d, size=%d)" % [name, i, follow_points.size()])
			continue # Skip this iteration

		var leader_pos : Vector2 = follow_points[i-1]
		var current_pos : Vector2 = follow_points[i]

		var vector_to_leader : Vector2 = leader_pos - current_pos
		var distance_sq : float = vector_to_leader.length_squared()

		# Move only if further than tolerance allows
		var min_dist_sq = (segment_distance * 0.01) * (segment_distance * 0.01)
		if distance_sq > min_dist_sq:
			# Avoid normalizing zero vector if points overlap exactly
			if vector_to_leader.length_squared() < 0.0001: continue # Skip if too close
			var direction_to_leader : Vector2 = vector_to_leader.normalized()
			var target_position : Vector2 = leader_pos - direction_to_leader * segment_distance

			# Lerp towards the target position
			follow_points[i] = current_pos.lerp(target_position, follow_lerp_speed * delta)

	# 3. Regenerate the visual polygon
	update_limb_polygon()


# --- Polygon Generation (Version that fixed reverse(), used to_local, might flicker) ---
func update_limb_polygon():
	if follow_points.size() < 2:
		limb_visual.polygon = PackedVector2Array([])
		return

	var vertices: PackedVector2Array = []
	var num_spine_points = follow_points.size()

	var left_verts: Array[Vector2] = []
	var right_verts: Array[Vector2] = []

	# var limb_origin_global = global_position # Not used in this version

	for i in range(num_spine_points):
		# Ensure indices are valid before accessing
		if i >= follow_points.size(): continue

		var current_spine_point_global = follow_points[i]

		# Calculate forward direction (Simpler version - potential flicker source)
		var forward_dir: Vector2
		if i == 0: # Head
			if num_spine_points > 1 and i+1 < follow_points.size():
				forward_dir = (follow_points[i+1] - current_spine_point_global).normalized()
			else:
				forward_dir = Vector2.RIGHT # Default
		elif i == num_spine_points - 1: # Tail
			if i-1 >= 0:
				forward_dir = (current_spine_point_global - follow_points[i-1]).normalized()
			else:
				forward_dir = Vector2.RIGHT # Default
		else: # Middle segments
			# Ensure next/prev indices are valid
			if i+1 < follow_points.size() and i-1 >= 0:
				var dir_to_next = (follow_points[i+1] - current_spine_point_global)
				var dir_from_prev = (current_spine_point_global - follow_points[i-1])
				# Average direction attempt
				forward_dir = (dir_to_next.normalized() + dir_from_prev.normalized())
			else: # Fallback if indices somehow invalid
				forward_dir = Vector2.RIGHT

		# Handle potential zero vector
		if forward_dir.length_squared() < 0.001:
			if i > 0 and i-1 >= 0: # Try previous direction
				forward_dir = (current_spine_point_global - follow_points[i-1]).normalized()
				if forward_dir.length_squared() < 0.001: forward_dir = Vector2.RIGHT
			else: forward_dir = Vector2.RIGHT
		else:
			forward_dir = forward_dir.normalized()


		var perpendicular_dir = forward_dir.orthogonal()
		var t = float(i) / max(1.0, float(num_spine_points - 1))
		var current_width = lerp(limb_base_width, limb_tip_width, t)

		# *** Using to_local() in this reverted version ***
		var local_spine_point = to_local(current_spine_point_global)

		left_verts.append(local_spine_point + perpendicular_dir * current_width * 0.5)
		right_verts.append(local_spine_point - perpendicular_dir * current_width * 0.5)

	# Combine vertices
	vertices.append_array(PackedVector2Array(left_verts))
	right_verts.reverse() # Reverse in-place (Corrected)
	vertices.append_array(PackedVector2Array(right_verts)) # Append reversed

	limb_visual.polygon = vertices


# --- Public Methods ---
func set_target(target: Node2D):
	_target_node = target
	# Check if head_node is valid before calling its method
	if is_instance_valid(head_node):
		head_node.set_target(target)

# --- Color Generation Helper ---
func generate_randomized_color(base: Color, hue_var: float, sat_var: float, val_var: float) -> Color:
	var h = base.h + randf_range(-hue_var, hue_var); h = fmod(h + 1.0, 1.0)
	var s = clamp(base.s + randf_range(-sat_var, sat_var), 0.0, 1.0)
	var v = clamp(base.v + randf_range(-val_var, val_var), 0.0, 1.0)
	return Color.from_hsv(h, s, v, base.a)

# --- Optional: Health, Damage, Death logic ---
# func take_damage(amount): ...
# func die(): ...
