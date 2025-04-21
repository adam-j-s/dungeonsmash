# slithering_limb.gd - Coordinator for procedural limb system
extends Node2D
class_name SlitheringLimb

# --- Exports ---
@export var head_scene: PackedScene = preload("res://scenes/enemies/limb_head.tscn")

@export_group("Limb Structure")
@export var num_segments: int = 10
@export var segment_distance: float = 10.0
@export var follow_lerp_speed: float = 12.0

@export_group("Visual Appearance")
@export var limb_base_width: float = 20.0
@export var limb_tip_width: float = 4.0
@export var base_color: Color = Color(0.4, 0.1, 0.6)
@export var color_variation_hue: float = 0.05
@export var color_variation_sat: float = 0.1
@export var color_variation_val: float = 0.1

# --- Variables ---
var follow_points: Array[Vector2] = []
var limb_color: Color = Color.WHITE

@onready var limb_visual: Polygon2D = $LimbVisual
var head_node: LimbHeadEnemy = null

# --- Initialization ---
func _ready():
	# Basic checks for required scenes
	if head_scene == null:
		printerr("%s: Head scene not assigned!" % name)
		set_process(false)
		return
	
	# Spawn head if not already a child
	head_node = get_node_or_null("Head")
	if not head_node:
		head_node = head_scene.instantiate() as LimbHeadEnemy
		if head_node:
			head_node.name = "Head"
			add_child(head_node)
			await head_node.ready
			
			# Set up connection to head
			head_node.limb_parent = self
		else:
			printerr("%s: Failed to instantiate head!" % name)
			set_process(false)
			return
	
	# Check for limb visual
	if not limb_visual:
		printerr("%s: Missing LimbVisual node!" % name)
		set_process(false)
		return
	
	# Initialize Follow Points array
	follow_points.resize(num_segments)
	if follow_points.size() != num_segments:
		printerr("%s: Failed to resize follow_points array!" % name)
		set_process(false)
		return
	
	# Initialize points based on head's position
	var start_pos = head_node.global_position
	for i in range(num_segments):
		follow_points[i] = start_pos - Vector2(i * segment_distance, 0)
	
	# Generate instance color
	limb_color = generate_randomized_color(base_color, color_variation_hue, color_variation_sat, color_variation_val)
	limb_visual.color = limb_color

func _process(delta):
	# Ensure head is still valid
	if not is_instance_valid(head_node):
		printerr("%s: Head node lost!" % name)
		queue_free()
		return
	
	# 1. Update the first spine point to the head's current position
	follow_points[0] = head_node.global_position
	
	# 2. Update the rest of the spine points to follow the one ahead
	for i in range(1, num_segments):
		# Ensure index is valid
		if i >= follow_points.size() or i-1 >= follow_points.size():
			continue
		
		var leader_pos: Vector2 = follow_points[i-1]
		var current_pos: Vector2 = follow_points[i]
		
		var vector_to_leader: Vector2 = leader_pos - current_pos
		var distance_sq: float = vector_to_leader.length_squared()
		
		# Move only if further than tolerance allows
		var min_dist_sq = (segment_distance * 0.01) * (segment_distance * 0.01)
		if distance_sq > min_dist_sq:
			# Avoid normalizing zero vector
			if vector_to_leader.length_squared() < 0.0001:
				continue
			
			var direction_to_leader: Vector2 = vector_to_leader.normalized()
			var target_position: Vector2 = leader_pos - direction_to_leader * segment_distance
			
			# Lerp towards the target position
			follow_points[i] = current_pos.lerp(target_position, follow_lerp_speed * delta)
	
	# 3. Update polygon visualization
	update_limb_polygon()

# --- Polygon Visualization ---
func update_limb_polygon():
	if follow_points.size() < 2:
		limb_visual.polygon = PackedVector2Array([])
		return
	
	var vertices: PackedVector2Array = []
	var num_spine_points = follow_points.size()
	
	var left_verts: Array[Vector2] = []
	var right_verts: Array[Vector2] = []
	
	for i in range(num_spine_points):
		# Ensure indices are valid
		if i >= follow_points.size():
			continue
		
		var current_spine_point_global = follow_points[i]
		
		# Calculate forward direction
		var forward_dir: Vector2
		if i == 0:  # Head
			if num_spine_points > 1 and i+1 < follow_points.size():
				forward_dir = (follow_points[i+1] - current_spine_point_global).normalized()
			else:
				forward_dir = Vector2.RIGHT  # Default
		elif i == num_spine_points - 1:  # Tail
			if i-1 >= 0:
				forward_dir = (current_spine_point_global - follow_points[i-1]).normalized()
			else:
				forward_dir = Vector2.RIGHT  # Default
		else:  # Middle segments
			# Ensure next/prev indices are valid
			if i+1 < follow_points.size() and i-1 >= 0:
				var dir_to_next = (follow_points[i+1] - current_spine_point_global)
				var dir_from_prev = (current_spine_point_global - follow_points[i-1])
				forward_dir = (dir_to_next.normalized() + dir_from_prev.normalized())
			else:
				forward_dir = Vector2.RIGHT
		
		# Handle potential zero vector
		if forward_dir.length_squared() < 0.001:
			if i > 0 and i-1 >= 0:
				forward_dir = (current_spine_point_global - follow_points[i-1]).normalized()
				if forward_dir.length_squared() < 0.001:
					forward_dir = Vector2.RIGHT
			else:
				forward_dir = Vector2.RIGHT
		else:
			forward_dir = forward_dir.normalized()
		
		var perpendicular_dir = forward_dir.orthogonal()
		var t = float(i) / max(1.0, float(num_spine_points - 1))
		var current_width = lerp(limb_base_width, limb_tip_width, t)
		
		var local_spine_point = to_local(current_spine_point_global)
		
		left_verts.append(local_spine_point + perpendicular_dir * current_width * 0.5)
		right_verts.append(local_spine_point - perpendicular_dir * current_width * 0.5)
	
	# Combine vertices
	vertices.append_array(PackedVector2Array(left_verts))
	right_verts.reverse()  # Reverse in-place
	vertices.append_array(PackedVector2Array(right_verts))  # Append reversed
	
	limb_visual.polygon = vertices

# --- Helper Functions ---
func generate_randomized_color(base: Color, hue_var: float, sat_var: float, val_var: float) -> Color:
	var h = base.h + randf_range(-hue_var, hue_var)
	h = fmod(h + 1.0, 1.0)  # Wrap hue to valid range
	
	var s = clamp(base.s + randf_range(-sat_var, sat_var), 0.0, 1.0)
	var v = clamp(base.v + randf_range(-val_var, val_var), 0.0, 1.0)
	
	return Color.from_hsv(h, s, v, base.a)

# Helper functions to interface with the head
func set_target(target_node):
	if is_instance_valid(head_node):
		head_node.set_target(target_node)

func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	if is_instance_valid(head_node):
		head_node.take_damage(amount, hit_direction, knockback_strength)
