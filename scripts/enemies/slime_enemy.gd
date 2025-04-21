# procedural_slime.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name ProceduralSlime

# Map the slime's states to BaseEnemy.AIState
# IDLE -> AIState.IDLE
# CHASING -> AIState.CHASING
# FLANKING -> Custom handling within AIState.CHASING
# PREPARING_LUNGE -> AIState.ATTACKING (with prep state flag)
# LUNGING -> AIState.ATTACKING (with lunging state flag)
# RECOVERING -> AIState.REPOSITIONING
# STUNNED -> AIState.STUNNED

# --- Slime-specific properties ---
@export_group("Lunge Behavior")
@export var lunge_detect_range_horizontal: float = 140.0
@export var lunge_detect_range_vertical: float = 170.0
@export var lunge_min_platform_height: float = 25.0
@export var lunge_min_wall_height: float = 15.0
@export var lunge_max_wall_height: float = 130.0
@export var lunge_prep_time: float = 0.45
@export var lunge_force: float = 550.0
@export var lunge_angle_bias: float = 0.8
@export var lunge_duration: float = 0.7
@export var lunge_cooldown: float = 1.5
@export var lunge_damage: int = 20
@export var lunge_knockback: float = 250.0
@export var vertical_lunge_threshold_x: float = 15.0
@export var attack_lunge_range_x: float = 160.0
@export var attack_lunge_range_y: float = 60.0

@export_group("Appearance & Deformation")
@export var min_scale: float = 0.7
@export var max_scale: float = 1.3
@export var elasticity: float = 0.4
@export var point_count: int = 16
@export var base_radius: float = 18.0

# --- Internal state tracking ---
var lunge_state: String = "none" # none, preparing, lunging, recovering
var lunge_target_pos: Vector2 = Vector2.ZERO
var lunge_timer: float = 0.0
var lunge_cooldown_timer: float = 0.0
var current_lunge_type: String = "traversal"
var flank_direction: float = 1.0

# --- Deformation ---
var base_points = []
var current_points = []
var point_velocities = []
@onready var polygon_node: Polygon2D = $Polygon2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- Visual effects ---
var slime_color: Color = Color(0.2, 0.8, 0.2)
var flash_tween: Tween = null

func _ready():
	# Call parent _ready
	super._ready()
	
	# Initialize slime-specific properties
	initialize_points()
	create_slime_shape()
	
	# Setup shader material if available
	if polygon_node and polygon_node.material and polygon_node.material is ShaderMaterial:
		polygon_node.material = polygon_node.material.duplicate()
	
	# Initialize with idle state
	change_ai_state(AIState.IDLE)

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Add to enemies group
	add_to_group("enemies")
	
	# Set collision layers
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers

func _physics_process(delta):
	# First call parent physics process for basic updates
	super._physics_process(delta)
	
	# Handle lunge cooldown
	if lunge_cooldown_timer > 0:
		lunge_cooldown_timer -= delta
	
	# Handle lunge state timer
	if lunge_state != "none":
		lunge_timer += delta
		
		# Transition between lunge states
		match lunge_state:
			"preparing":
				if lunge_timer >= lunge_prep_time:
					execute_lunge()
					lunge_state = "lunging"
					lunge_timer = 0.0
			"lunging":
				if lunge_timer >= lunge_duration:
					lunge_state = "recovering"
					lunge_timer = 0.0
			"recovering":
				if lunge_timer >= 0.3:
					lunge_state = "none"
					lunge_timer = 0.0
	
	# Update deformation
	update_deformation(delta)
	update_polygon_shape()
	
	# Handle collisions during lunging
	if lunge_state == "lunging":
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.is_in_group("player"):
				if collider.has_method("take_damage"):
					collider.take_damage(lunge_damage, (collider.global_position - global_position).normalized(), lunge_knockback)
				lunge_state = "recovering"
				lunge_timer = 0.0
				apply_impact(velocity.normalized() * -1, velocity.length() * 0.1)

# --- Override State Processing Functions ---

func process_idle_state(delta):
	# Call parent method
	super.process_idle_state(delta)
	
	# Add slime-specific idle behavior
	animate_idle(delta)

func process_chasing_state(delta):
	# Enhanced chase logic
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	var current_pos = global_position
	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - current_pos
	var vertical_dist = vector_to_target.y
	var horizontal_dist = abs(vector_to_target.x)
	var direction_to_target = vector_to_target.normalized()
	
	# Set chase speed
	target_velocity.x = direction_to_target.x * move_speed * chase_speed_multiplier
	
	# Check for attack lunge opportunity
	if lunge_cooldown_timer <= 0 and horizontal_dist < attack_lunge_range_x and abs(vertical_dist) < attack_lunge_range_y:
		current_lunge_type = "attack"
		lunge_target_pos = target_pos
		start_lunge_preparation()
		return
	
	# Check if path upward is blocked (for flanking)
	var blocked_upward = false
	if vertical_dist < -lunge_min_platform_height:
		var space_state = get_world_2d().direct_space_state
		var upward_check_start = current_pos + Vector2(0, -base_radius * 0.5)
		var upward_check_end = upward_check_start + Vector2.UP * (lunge_min_platform_height * 0.8)
		var query = PhysicsRayQueryParameters2D.create(upward_check_start, upward_check_end, collision_mask, [self])
		var result = space_state.intersect_ray(query)
		if result and result.normal.y > 0.7:
			blocked_upward = true
	
	# If blocked, start flanking
	if blocked_upward:
		flank_direction = sign(target_pos.x - current_pos.x)
		if flank_direction == 0: 
			flank_direction = 1.0 if randf() > 0.5 else -1.0
		process_flanking_behavior(delta)
		return
	
	# Check for traversal lunge
	if lunge_cooldown_timer <= 0:
		var lunge_opportunity = check_for_lunge_opportunity()
		if lunge_opportunity:
			current_lunge_type = "traversal"
			lunge_target_pos = lunge_opportunity.target_point
			start_lunge_preparation()
	
	# Animation
	animate_chasing(delta)

func process_attacking_state(delta):
	# In the BaseEnemy system, we're using ATTACKING state for lunging
	match lunge_state:
		"preparing":
			# Preparing for lunge
			target_velocity.x = 0
			animate_preparing_lunge(delta)
		"lunging":
			# Currently lunging
			animate_lunging(delta)
		"recovering":
			# Recovering from lunge
			target_velocity.x = 0
			animate_recovering(delta)
			if lunge_timer >= 0.3:
				change_ai_state(AIState.CHASING)
		"none":
			# Not in a lunge phase - restart or transition
			if is_instance_valid(_target_node):
				var distance = global_position.distance_to(_target_node.global_position)
				if distance < preferred_attack_distance * 1.5:
					start_lunge_preparation()
				else:
					change_ai_state(AIState.CHASING)
			else:
				change_ai_state(AIState.IDLE)

func process_stunned_state(delta):
	# Call parent handling
	super.process_stunned_state(delta)
	
	# Slime-specific stunned animation
	animate_stunned(delta)

# --- Custom Methods ---

func process_flanking_behavior(delta):
	# This implements the flanking behavior from the original script
	# while keeping the BaseEnemy state as CHASING
	
	target_velocity.x = flank_direction * move_speed * chase_speed_multiplier
	
	# Check if we can stop flanking
	var space_state = get_world_2d().direct_space_state
	var upward_check_start = global_position + Vector2(0, -base_radius * 0.5)
	var upward_check_end = upward_check_start + Vector2.UP * (lunge_min_platform_height * 1.1)
	var query = PhysicsRayQueryParameters2D.create(upward_check_start, upward_check_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)
	var still_blocked = (result and result.normal.y > 0.7)
	
	if not still_blocked or state_timer > 4.0:
		# Return to normal chasing
		change_ai_state(AIState.CHASING)
	
	# Animation during flanking
	animate_chasing(delta)

func start_lunge_preparation():
	# Transition to ATTACKING state for lunge
	change_ai_state(AIState.ATTACKING)
	lunge_state = "preparing"
	lunge_timer = 0.0

func execute_lunge():
	# Implement the original logic for executing a lunge
	var lunge_vector: Vector2
	var target_direction: Vector2
	
	# Determine base direction
	if lunge_target_pos != Vector2.ZERO:
		target_direction = (lunge_target_pos - global_position).normalized()
	elif _target_node:
		target_direction = (_target_node.global_position - global_position).normalized()
		lunge_target_pos = _target_node.global_position
	else:
		target_direction = Vector2(1.0 if scale.x > 0 else -1.0, -1.0).normalized()
		lunge_target_pos = global_position + target_direction * 100
	
	# Calculate lunge vector based on type
	if current_lunge_type == "attack":
		# Attack lunge
		var attack_angle = target_direction.angle()
		if target_direction.y >= -0.1:
			attack_angle = lerp_angle(attack_angle, Vector2.UP.angle(), 0.1)
		lunge_vector = Vector2.from_angle(attack_angle) * lunge_force
	elif current_lunge_type == "traversal":
		# Traversal lunge
		var horizontal_dist_to_target = abs(lunge_target_pos.x - global_position.x)
		
		if horizontal_dist_to_target < vertical_lunge_threshold_x:
			# Near-vertical traversal lunge
			var vertical_dir_x_component = (lunge_target_pos.x - global_position.x) * 0.05
			var vertical_dir = Vector2(vertical_dir_x_component, -1.0).normalized()
			lunge_vector = vertical_dir * lunge_force
		else:
			# Angled traversal lunge
			var angle = target_direction.angle()
			var more_vertical_angle = Vector2(target_direction.x, -abs(target_direction.x * lunge_angle_bias)).angle()
			var biased_angle = lerp_angle(angle, more_vertical_angle, 0.5)
			lunge_vector = Vector2.from_angle(biased_angle) * lunge_force
	else:
		# Fallback
		lunge_vector = Vector2.UP * lunge_force
	
	# Apply the calculated lunge vector
	velocity = lunge_vector
	apply_impact(lunge_vector.normalized() * -1, lunge_force * 0.1)
	
	# Manage cooldowns and flags
	lunge_cooldown_timer = lunge_cooldown
	lunge_target_pos = Vector2.ZERO
	current_lunge_type = "traversal"

func check_for_lunge_opportunity() -> Dictionary:
	if not _target_node:
		return {}
	
	# Use the space state for ray casting
	var space_state = get_world_2d().direct_space_state
	var current_pos = global_position
	var target_pos = _target_node.global_position
	
	# Platform Check - Look for platforms above that we can jump to
	var upward_scan_angles = [-40, -20, 0, 20, 40]
	var platform_ray_length = lunge_detect_range_vertical * 1.2
	
	for angle_deg in upward_scan_angles:
		var angle_rad = deg_to_rad(angle_deg)
		var scan_dir = Vector2.UP.rotated(angle_rad)
		var scan_start = current_pos + Vector2(0, -base_radius * 0.5)
		var scan_end = scan_start + scan_dir * platform_ray_length
		var query = PhysicsRayQueryParameters2D.create(scan_start, scan_end, collision_mask, [self])
		var result = space_state.intersect_ray(query)
		
		if result and result.normal.y > 0.7:
			var platform_height = current_pos.y - result.position.y
			if platform_height > lunge_min_platform_height and platform_height < lunge_detect_range_vertical:
				var land_target = result.position + Vector2(0, -10.0)
				land_target.x += sign(target_pos.x - current_pos.x) * 5.0
				if abs(land_target.x - current_pos.x) < lunge_detect_range_horizontal:
					return {"type": "platform_scan", "target_point": land_target}
	
	# Wall/Ledge Check - Look for walls that we can climb
	var look_dir = sign(target_velocity.x) if target_velocity.x != 0 else (1 if scale.x > 0 else -1)
	var wall_check_start = current_pos + Vector2(look_dir * base_radius * 0.5, -base_radius * 0.5)
	var wall_check_end = wall_check_start + Vector2(look_dir * 40, 0)
	var wall_query = PhysicsRayQueryParameters2D.create(wall_check_start, wall_check_end, collision_mask, [self])
	var wall_result = space_state.intersect_ray(wall_query)
	
	if wall_result:
		var wall_normal = wall_result.normal
		if abs(wall_normal.x) > 0.7:
			var height_check_origin = wall_result.position + wall_normal * 2.0 + Vector2(0, -5)
			var height_check_up = height_check_origin + Vector2(0, -lunge_max_wall_height * 1.2)
			var ceiling_query = PhysicsRayQueryParameters2D.create(height_check_origin, height_check_up, collision_mask, [self])
			var ceiling_result = space_state.intersect_ray(ceiling_query)
			
			if not ceiling_result:
				var edge_find_start = height_check_origin + Vector2(0, -lunge_max_wall_height)
				var edge_find_end = edge_find_start + Vector2(look_dir * 30, 0)
				var edge_query = PhysicsRayQueryParameters2D.create(edge_find_start, edge_find_end, collision_mask, [self])
				var edge_result = space_state.intersect_ray(edge_query)
				
				if not edge_result:
					var surface_find_start = edge_find_start + Vector2(look_dir * 15, 0)
					var surface_find_end = surface_find_start + Vector2(0, lunge_max_wall_height * 1.5)
					var surface_query = PhysicsRayQueryParameters2D.create(surface_find_start, surface_find_end, collision_mask, [self])
					var surface_result = space_state.intersect_ray(surface_query)
					
					if surface_result:
						var wall_height = current_pos.y - surface_result.position.y
						if wall_height > lunge_min_wall_height and wall_height < lunge_max_wall_height:
							var land_target = surface_result.position + Vector2(look_dir * 10, -5)
							return {"type": "ledge", "target_point": land_target}
	
	return {}

# --- Deformation & Animation Methods ---
func initialize_points():
	base_points.clear()
	current_points.clear()
	point_velocities.clear()
	
	for i in range(point_count):
		var angle = TAU * i / point_count
		var point = Vector2.from_angle(angle) * base_radius
		base_points.append(point)
		current_points.append(point)
		point_velocities.append(Vector2.ZERO)

func create_slime_shape():
	if polygon_node:
		polygon_node.color = slime_color
		polygon_node.polygon = current_points

func update_deformation(delta: float):
	# Handle deformation based on AI state
	match current_ai_state:
		AIState.IDLE:
			animate_idle(delta)
		AIState.CHASING:
			animate_chasing(delta)
		AIState.ATTACKING:
			match lunge_state:
				"preparing":
					animate_preparing_lunge(delta)
				"lunging":
					animate_lunging(delta)
				"recovering":
					animate_recovering(delta)
				"none":
					animate_idle(delta)
		AIState.STUNNED:
			animate_stunned(delta)
		_:
			animate_idle(delta)
	
	# Apply point physics
	for i in range(current_points.size()):
		var diff_to_base = base_points[i] - current_points[i]
		point_velocities[i] += diff_to_base * elasticity * delta * 60
		point_velocities[i] *= pow(damping, delta * 60)
		current_points[i] += point_velocities[i] * delta * 60

func update_polygon_shape():
	# Original code for updating polygon based on points
	if polygon_node:
		polygon_node.polygon = current_points

func apply_impact(direction: Vector2, strength: float):
	# Original code for applying impact forces to the deformation
	if not polygon_node:
		return
	
	var normalized_dir = direction.normalized()
	for i in range(current_points.size()):
		var point_local = current_points[i]
		var dot_product = point_local.normalized().dot(normalized_dir)
		if dot_product > 0.1:
			var distance_factor = 1.0 / (1.0 + point_local.length() * 0.05)
			point_velocities[i] += normalized_dir * strength * dot_product * distance_factor

# --- Animation Functions ---
func animate_idle(delta: float):
	# Original idle animation code
	var time = Time.get_ticks_msec() / 1000.0
	for i in range(current_points.size()):
		var original = base_points[i]
		var angle = original.angle()
		var pulse = sin(time * 2.5) * 0.05 + 1.0
		var target = original * pulse + Vector2.from_angle(time * 1.5 + angle * 2) * 1.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 50

func animate_chasing(delta: float):
	# Original chasing animation code
	var time = Time.get_ticks_msec() / 1000.0
	var direction = velocity.normalized()
	var factor = clamp(velocity.length() / (move_speed * chase_speed_multiplier + 0.01), 0.0, 1.0)
	
	for i in range(current_points.size()):
		var original = base_points[i]
		var dot = original.normalized().dot(direction)
		var scale_factor = lerp(1.0, 1.15, factor * dot) if dot > 0 else lerp(1.0, 0.85, factor * abs(dot))
		var target = original * scale_factor
		target.y *= lerp(1.0, 0.9, factor)
		target += Vector2.from_angle(time * 4 + original.angle() * 3) * 1.5 * factor
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 60

func animate_preparing_lunge(delta: float):
	# Original preparing animation code
	var progress = lunge_timer / lunge_prep_time
	var ease_p = ease(progress, EASE_OUT_IN)
	var squash = lerp(1.0, 0.4, ease_p)
	var spread = lerp(1.0, 1.6, ease_p)
	
	for i in range(current_points.size()):
		var original = base_points[i]
		var target = Vector2(original.x * spread, original.y * squash)
		target += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * progress * 3.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 100

func animate_lunging(delta: float):
	# Original lunging animation code
	var time = Time.get_ticks_msec() / 1000.0
	var lunge_dir = velocity.normalized()
	var speed = velocity.length()
	
	if lunge_dir == Vector2.ZERO:
		lunge_dir = Vector2.UP
		
	var stretch = clamp(1.0 + speed * 0.005, 1.0, 2.5)
	var width = clamp(1.0 - speed * 0.001, 0.3, 1.0)
	
	for i in range(current_points.size()):
		var original = base_points[i]
		var dot = original.normalized().dot(lunge_dir)
		var target: Vector2
		target = original + lunge_dir * original.length() * stretch * (dot if dot > 0.1 else 0.1 * dot)
		
		var perp_dir = lunge_dir.orthogonal()
		var perp_dot = original.normalized().dot(perp_dir)
		target -= perp_dir * original.length() * (1.0 - width) * perp_dot
		target += perp_dir * sin(time * 15 - current_points[i].length() * 0.1 + original.angle()) * 3.0 * (1.0 - width)
		
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 80

func animate_recovering(delta: float):
	# Original recovering animation code
	var progress = lunge_timer / 0.3
	
	for i in range(current_points.size()):
		var original = base_points[i]
		var overshoot = lerp(1.3, 1.0, progress)
		var target = original * overshoot
		target += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * (1.0 - progress) * 4.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 70

func animate_stunned(delta: float):
	# Original stunned animation code
	var time = Time.get_ticks_msec() / 1000.0
	
	for i in range(current_points.size()):
		var original = base_points[i]
		var target = original + Vector2(sin(time * 20 + i * 1.1) * 4, cos(time * 15 + i * 0.8) * 4)
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 60
# --- BaseEnemy Overrides ---

func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# First handle flash effect
	if is_instance_valid(polygon_node) and polygon_node.material is ShaderMaterial:
		var material = polygon_node.material
		if flash_tween and flash_tween.is_valid():
			flash_tween.kill()
		flash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		material.set_shader_parameter("flash_modifier", 1.0)
		flash_tween.tween_method(func(value): if is_instance_valid(material): material.set_shader_parameter("flash_modifier", value), 1.0, 0.0, 0.15)
	
	# Apply knockback to velocity and deformation
	if hit_direction != Vector2.ZERO and knockback_strength > 0:
		velocity = hit_direction * knockback_strength
		apply_impact(hit_direction, knockback_strength * 0.15)
	
	# Consider stunning based on damage amount
	if amount > 20 or randf() < 0.3:
		if current_ai_state != AIState.STUNNED and lunge_state != "lunging":
			change_ai_state(AIState.STUNNED)
	
	# Call base implementation for health handling
	super.take_damage(amount, hit_direction, knockback_strength)

func play_death_effects():
	# Call parent method first
	super.play_death_effects()
	
	# Add slime-specific death effects
	if not is_instance_valid(polygon_node):
		queue_free()
		return
		
	# Explode points outward
	for i in range(current_points.size()):
		point_velocities[i] = base_points[i].normalized() * randf_range(200, 500)
	
	# Fade out with tween
	var tween = create_tween().set_parallel(false)
	tween.tween_interval(0.1)
	tween.tween_property(polygon_node, "modulate:a", 0.0, 0.5).from_current()
	tween.tween_callback(queue_free)

# --- Helper Functions ---
const EASE_OUT_IN = 2.0
func ease(x: float, power: float) -> float:
	if x < 0.5:
		return pow(2.0 * x, power) / 2.0
	else:
		return 1.0 - pow(2.0 * (1.0 - x), power) / 2.0
