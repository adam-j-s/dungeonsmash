# LimbSegment.gd (Revised - Robust Leader Check)
extends Node2D
class_name LimbSegment

# --- Variables ---
var leader_node: Node2D = null      # The node this segment follows (Head or another Segment)
var follow_distance: float = 15.0   # Target distance to maintain from the leader
var follow_lerp_speed: float = 10.0 # How quickly the segment catches up

@onready var polygon_node: Polygon2D = $SegmentPolygon

# --- Procedural Appearance (Passed from Limb Root) ---
var segment_color: Color = Color.WHITE
var num_points: int = 8
var segment_radius: float = 10.0
var radius_variation: float = 0.1

func _ready():
	# Generate the initial polygon shape
	generate_shape()
	# Apply the assigned color
	if polygon_node:
		polygon_node.color = segment_color

	# *** CHANGE HERE: Always enable physics process initially ***
	set_physics_process(true)
	# We will check for a valid leader INSIDE _physics_process instead.
	# This avoids potential timing issues during initialization.

func _physics_process(delta: float):
	# *** CHANGE HERE: Check leader validity *every frame* before processing ***
	if not is_instance_valid(leader_node):
		# Leader might have been destroyed or wasn't set properly.
		# Optionally, destroy this segment too or have it fade out.
		# For now, just stop processing to prevent errors.
		# print_warning("%s: Leader node is invalid. Stopping follow." % name) # Optional Debug
		# If you want segments to just fall/stop when leader dies:
		# set_physics_process(false)
		# If you want segments to disappear when leader dies:
		queue_free()
		return

	# --- Following Logic (Same as before) ---
	var vector_to_leader = leader_node.global_position - global_position
	# Avoid division by zero if somehow leader is at the same spot
	if vector_to_leader.length_squared() < 0.01:
		return
	var target_position = leader_node.global_position - vector_to_leader.normalized() * follow_distance

	# --- Movement ---
	global_position = global_position.lerp(target_position, follow_lerp_speed * delta)

	# --- Rotation ---
	var move_direction = leader_node.global_position - global_position # Face the actual leader
	if move_direction.length_squared() > 0.01:
		rotation = move_direction.angle()

# --- Shape Generation ---
func generate_shape():
	if not polygon_node: return

	var points: PackedVector2Array = []
	for i in range(num_points):
		var angle = TAU * i / num_points
		var current_radius = segment_radius * (1.0 + randf_range(-radius_variation, radius_variation))
		var point = Vector2.from_angle(angle) * current_radius
		points.append(point)

	polygon_node.polygon = points

# --- Public Method to set parameters ---
func setup_segment(leader: Node2D, distance: float, lerp_speed: float, color: Color, point_count: int, radius: float, variation: float):
	leader_node = leader # This assignment should still work
	follow_distance = distance
	follow_lerp_speed = lerp_speed
	segment_color = color
	num_points = point_count
	segment_radius = radius
	radius_variation = variation
	# Re-apply color/shape if called after _ready (though usually called before)
	if is_inside_tree(): # Check if _ready has potentially run
		if polygon_node: polygon_node.color = segment_color
		generate_shape()
