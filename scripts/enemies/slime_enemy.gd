# Slime Enemy with Sticky Lunge Mechanic (v4.9 - Attack Lunge on v4.5 Base - NO SHORTENING)
# Inherits from your BaseEnemy script
extends CharacterBody2D

class_name ProceduralSlime

# States
enum States { IDLE, CHASING, FLANKING, PREPARING_LUNGE, LUNGING, RECOVERING, STUNNED }

# --- Export Variables for Tuning (Defaults from v4.5 - Aggression Tuned) ---
@export_group("Movement")
@export var move_speed: float = 70.0
@export var chase_speed_multiplier: float = 1.5
@export var acceleration: float = 18.0
@export var gravity_scale: float = 1.0

@export_group("Lunge")
@export var lunge_detect_range_horizontal: float = 140.0
@export var lunge_detect_range_vertical: float = 170.0
@export var lunge_min_platform_height: float = 25.0
@export var lunge_min_wall_height: float = 15.0
@export var lunge_max_wall_height: float = 130.0
@export var lunge_prep_time: float = 0.45
@export var lunge_force: float = 550.0
@export var lunge_angle_bias: float = 0.8 # Bias for TRAVERSAL lunges
@export var lunge_duration: float = 0.7
@export var lunge_cooldown: float = 1.5
@export var lunge_damage: int = 20
@export var lunge_knockback: float = 250.0
@export var vertical_lunge_threshold_x: float = 15.0 # For TRAVERSAL lunges
@export var attack_lunge_range_x: float = 160.0 # ADDED: Horizontal range for attack lunge
@export var attack_lunge_range_y: float = 60.0  # ADDED: Vertical tolerance for attack lunge (+/- from slime's Y)

@export_group("Appearance & Deformation")
@export var min_scale: float = 0.7
@export var max_scale: float = 1.3
@export var elasticity: float = 0.4
@export var damping: float = 0.85
@export var point_count: int = 16
@export var base_radius: float = 18.0

@export_group("Procedural Variation")
@export var enable_procedural_variation: bool = true

# --- Internal Variables ---
var current_state = States.IDLE
var state_timer: float = 0.0
var current_move_speed: float = 0.0
var target_velocity: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale

var lunge_target_pos: Vector2 = Vector2.ZERO
var can_lunge: bool = true
var lunge_cooldown_timer: float = 0.0
var just_lunged: bool = false
var flank_direction: float = 1.0
var current_lunge_type: String = "traversal" # ADDED: Track lunge intent

# Deformation
var base_points = []
var current_points = []
var point_velocities = []
@onready var polygon_node: Polygon2D = $Polygon2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Target
var _target_node: Node2D = null

# Procedural properties
var slime_color: Color = Color(0.2, 0.8, 0.2)

# Tween for flash effect
var flash_tween: Tween = null

# --- _ready Function (Using v4.5 structure) ---
func _ready():
	# super._ready() # Call if BaseEnemy has a _ready
	if enable_procedural_variation:
		var slime_variation = randi() % 3
		# Apply variations relative to the potentially adjusted base values
		match slime_variation:
			0: # Standard
				slime_color = Color(0.2, 0.8, 0.2)
				elasticity = 0.4
				damping = 0.85
			1: # Quick
				slime_color = Color(0.2, 0.2, 0.8)
				move_speed *= 1.2
				acceleration *= 1.2
				lunge_prep_time *= 0.8
				lunge_cooldown *= 0.7
				elasticity = 0.5
				damping = 0.8
			2: # Heavy
				slime_color = Color(0.8, 0.2, 0.2)
				move_speed *= 0.8
				lunge_force *= 1.1
				lunge_prep_time *= 1.2
				lunge_cooldown *= 1.3
				elasticity = 0.3
				damping = 0.9
	initialize_points()
	create_slime_shape()
	if polygon_node and polygon_node.material and polygon_node.material is ShaderMaterial:
		polygon_node.material = polygon_node.material.duplicate()
	elif polygon_node and not polygon_node.material:
		print("Slime %s: No ShaderMaterial for flash." % name)
	elif not polygon_node:
		print("Slime %s: Missing Polygon2D." % name)
	change_state(States.IDLE)

# --- Initialization Functions (Using v4.5 structure) ---
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

# --- _physics_process Function (Using v4.5 structure) ---
func _physics_process(delta: float) -> void:
	# Cooldowns
	if lunge_cooldown_timer > 0:
		lunge_cooldown_timer -= delta
		if lunge_cooldown_timer <= 0:
			can_lunge = true
			just_lunged = false
	# Gravity
	if current_state != States.LUNGING or velocity.y > 0:
		velocity.y += gravity * delta
	state_timer += delta
	# State Machine
	match current_state:
		States.IDLE: process_idle_state(delta)
		States.CHASING: process_chasing_state(delta)
		States.FLANKING: process_flanking_state(delta)
		States.PREPARING_LUNGE: process_preparing_lunge_state(delta)
		States.LUNGING: process_lunging_state(delta)
		States.RECOVERING: process_recovering_state(delta)
		States.STUNNED: process_stunned_state(delta)
	# Movement
	if current_state != States.PREPARING_LUNGE and current_state != States.STUNNED and current_state != States.LUNGING:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * 60)
	elif current_state != States.LUNGING:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta * 60)
	var collided = move_and_slide()
	# Post-Movement Checks
	if collided and current_state == States.LUNGING:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.is_in_group("player"):
				if collider.has_method("take_damage"):
					collider.take_damage(lunge_damage, (collider.global_position - global_position).normalized(), lunge_knockback)
				# print("%s: Lunge hit player!" % name) # Reduced debug print
		if is_on_floor() or is_on_wall():
			apply_impact(velocity.normalized() * -1, velocity.length() * 0.1)
			change_state(States.RECOVERING)
	# Visuals
	update_deformation(delta)
	update_polygon_shape()

# ==============================
# STATE PROCESSING FUNCTIONS
# ==============================
func process_idle_state(_delta: float):
	target_velocity.x = 0
	if _target_node:
		change_state(States.CHASING)

# --- REVISED process_chasing_state (Attack Lunge Added First + Flank Decoupled + v4.5 Syntax) ---
func process_chasing_state(_delta: float):
	if not _target_node:
		change_state(States.IDLE)
		return

	var current_pos = global_position
	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - current_pos # Used for distance checks
	var direction_to_target = vector_to_target.normalized()
	var vertical_dist = vector_to_target.y # Negative = target is above
	var horizontal_dist = abs(vector_to_target.x)

	# Set default horizontal movement towards target - THIS IS CONTINUOUS
	current_move_speed = move_speed * chase_speed_multiplier
	target_velocity.x = direction_to_target.x * current_move_speed

	# --- CHECK LUNGE/FLANK OPTIONS ---

	# --- PRIORITY 1: Check for Attack Lunge Opportunity ---
	# Check if lunge is ready and player is within the defined attack range
	if can_lunge and not just_lunged and \
	   horizontal_dist < attack_lunge_range_x and \
	   abs(vertical_dist) < attack_lunge_range_y:
		# Player is within direct attack lunge range
		print("%s: Player in Attack Lunge range." % name) # Debug
		current_lunge_type = "attack" # Set intent
		lunge_target_pos = target_pos # Target the player directly
		change_state(States.PREPARING_LUNGE)
		return # Prioritize attack lunge, skip other checks

	# --- PRIORITY 2: Check if Path Upward is Blocked (for Flanking) ---
	var blocked_upward = false
	# *** Check for blockage REGARDLESS of lunge cooldown ***
	if vertical_dist < -lunge_min_platform_height: # Check if player is significantly above
		var space_state = get_world_2d().direct_space_state
		var upward_check_start = current_pos + Vector2(0, -base_radius * 0.5)
		# Use shorter check distance from v4.5 aggression tuning
		var upward_check_end = upward_check_start + Vector2.UP * (lunge_min_platform_height * 0.8)
		var query = PhysicsRayQueryParameters2D.create(upward_check_start, upward_check_end, collision_mask, [self])
		var result = space_state.intersect_ray(query)
		if result and result.normal.y > 0.7: # Hit a ceiling very nearby?
			blocked_upward = true
			# print("%s: Path upward blocked by VERY low ceiling." % name) # Debug

	# If blocked, flank immediately (don't wait for lunge cooldown)
	if blocked_upward:
		# Path immediately blocked, initiate flanking
		# print("%s: Path Blocked - Entering Flanking State." % name) # Debug
		flank_direction = sign(target_pos.x - current_pos.x)
		if flank_direction == 0: flank_direction = 1.0 if randf() > 0.5 else -1.0
		change_state(States.FLANKING)
		return # Exit chase state logic

	# --- PRIORITY 3: Check for Traversal Lunge ---
	# If not flanking and no attack lunge triggered, check for traversal lunge.
	# THIS check STILL respects the cooldown.
	if can_lunge and not just_lunged:
		var lunge_opportunity = check_for_lunge_opportunity() # Finds platforms/ledges
		if lunge_opportunity:
			# print("%s: Found Traversal Lunge opportunity." % name) # Debug
			current_lunge_type = "traversal" # Explicitly set type
			lunge_target_pos = lunge_opportunity.target_point
			change_state(States.PREPARING_LUNGE)
			# Don't return, allow horizontal movement until PREPARING starts

func process_flanking_state(_delta: float):
	if not _target_node:
		change_state(States.IDLE)
		return
	current_move_speed = move_speed * chase_speed_multiplier
	target_velocity.x = flank_direction * current_move_speed
	# Use correct variable names from v4.5 structure
	var space_state = get_world_2d().direct_space_state
	var upward_check_start = global_position + Vector2(0, -base_radius * 0.5)
	var upward_check_end = upward_check_start + Vector2.UP * (lunge_min_platform_height * 1.1) # Use original check distance here
	var query = PhysicsRayQueryParameters2D.create(upward_check_start, upward_check_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)
	var still_blocked = (result and result.normal.y > 0.7)
	if not still_blocked:
		# print("%s: Flanking clear." % name) # Reduced debug spam
		change_state(States.CHASING)
		return
	if state_timer > 4.0:
		# print("%s: Flanking timeout." % name) # Reduced debug spam
		change_state(States.CHASING)
		return

func process_preparing_lunge_state(_delta: float):
	target_velocity.x = 0
	if state_timer >= lunge_prep_time:
		execute_lunge()
		change_state(States.LUNGING)
func process_lunging_state(_delta: float):
	if state_timer >= lunge_duration:
		change_state(States.RECOVERING)
func process_recovering_state(_delta: float):
	target_velocity.x = 0
	if state_timer >= 0.3:
		change_state(States.CHASING if _target_node else States.IDLE)
func process_stunned_state(_delta: float):
	target_velocity.x = 0
	if state_timer >= 1.0:
		change_state(States.IDLE)

# ==============================
# ACTION & HELPER FUNCTIONS
# ==============================
func change_state(new_state):
	current_state = new_state
	state_timer = 0.0
	if new_state in [States.IDLE, States.PREPARING_LUNGE, States.RECOVERING, States.STUNNED]:
		target_velocity.x = 0

func check_for_lunge_opportunity() -> Dictionary: # Finds TRAVERSAL opportunities only
	if not _target_node: return {}
	# Use correct variable names from v4.5 structure
	var space_state = get_world_2d().direct_space_state
	var current_pos = global_position
	var target_pos = _target_node.global_position
	# Platform Check
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
					# print("%s: Lunge Check - Platform scan hit"%name)
					return {"type": "platform_scan", "target_point": land_target}
	# Wall/Ledge Check
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
							# print("%s: Lunge Check - Wall/Ledge found"%name)
							var land_target = surface_result.position + Vector2(look_dir * 10, -5)
							return {"type": "ledge", "target_point": land_target}
	return {}

# --- REVISED execute_lunge function (Handles Attack vs Traversal + v4.5 Syntax) ---
func execute_lunge():
	var lunge_vector: Vector2
	var target_direction: Vector2

	# --- Determine Base Direction ---
	if lunge_target_pos != Vector2.ZERO:
		target_direction = (lunge_target_pos - global_position).normalized()
	elif _target_node:
		# Fallback if target_pos somehow missing
		print("%s: Lunge target pos zero, using player pos fallback." % name)
		target_direction = (_target_node.global_position - global_position).normalized()
		lunge_target_pos = _target_node.global_position # Set it for calcs below
	else:
		# Failsafe if everything is missing
		print("%s: Lunge target and player node missing!" % name)
		target_direction = Vector2(1.0 if scale.x > 0 else -1.0, -1.0).normalized()
		lunge_target_pos = global_position + target_direction * 100 # Fake target for calcs

	# --- Calculate Lunge Vector based on Type ---
	if current_lunge_type == "attack":
		# *** ATTACK LUNGE ***
		# Aim more directly towards the player, maybe slightly above them
		print("%s: Executing ATTACK lunge towards %s" % [name, str(lunge_target_pos)]) # Debug
		# Calculate angle directly to target
		var attack_angle = target_direction.angle()
		# Optional: Nudge slightly up if target is level or below slime?
		if target_direction.y >= -0.1: # Target isn't significantly above
			attack_angle = lerp_angle(attack_angle, Vector2.UP.angle(), 0.1) # Nudge 10% towards pure up
		# Calculate final vector
		lunge_vector = Vector2.from_angle(attack_angle) * lunge_force

	elif current_lunge_type == "traversal":
		# *** TRAVERSAL LUNGE (Platform/Ledge) ***
		# Calculate horizontal distance for near-vertical check
		var horizontal_dist_to_target = abs(lunge_target_pos.x - global_position.x)

		# Check if target is almost directly above for near-vertical jump
		if horizontal_dist_to_target < vertical_lunge_threshold_x:
			# NEAR-VERTICAL TRAVERSAL LUNGE
			# print("%s: Executing near-vertical TRAVERSAL lunge (DistX: %.1f < %.1f)" % [name, horizontal_dist_to_target, vertical_lunge_threshold_x]) # Debug
			var vertical_dir_x_component = (lunge_target_pos.x - global_position.x) * 0.05 # Tiny horizontal nudge
			var vertical_dir = Vector2(vertical_dir_x_component, -1.0 ).normalized() # Mostly vertical
			lunge_vector = vertical_dir * lunge_force
		else:
			# ANGLED TRAVERSAL LUNGE (Apply bias)
			# print("%s: Executing angled TRAVERSAL lunge towards %s" % [name, str(lunge_target_pos)]) # Debug
			var angle = target_direction.angle()
			var more_vertical_angle = Vector2(target_direction.x, -abs(target_direction.x * lunge_angle_bias)).angle()
			var biased_angle = lerp_angle(angle, more_vertical_angle, 0.5) # Mix between direct and biased angle
			lunge_vector = Vector2.from_angle(biased_angle) * lunge_force
	else:
		# Fallback / Error case
		print("%s: Unknown lunge type '%s'! Defaulting upward." % [name, current_lunge_type])
		lunge_vector = Vector2.UP * lunge_force

	# --- Apply the calculated lunge_vector ---
	velocity = lunge_vector
	apply_impact(lunge_vector.normalized() * -1, lunge_force * 0.1)

	# Manage cooldowns and flags
	can_lunge = false
	just_lunged = true
	lunge_cooldown_timer = lunge_cooldown
	lunge_target_pos = Vector2.ZERO # Clear target position
	current_lunge_type = "traversal" # Reset default type for next time

# ==============================
# DEFORMATION & VISUALS
# ==============================
func update_deformation(delta: float):
	match current_state:
		States.IDLE: animate_idle(delta)
		States.CHASING: animate_chasing(delta)
		States.FLANKING: animate_flanking(delta)
		States.PREPARING_LUNGE: animate_preparing_lunge(delta)
		States.LUNGING: animate_lunging(delta)
		States.RECOVERING: animate_recovering(delta)
		States.STUNNED: animate_stunned(delta)
	for i in range(current_points.size()):
		var diff_to_base = base_points[i] - current_points[i]
		point_velocities[i] += diff_to_base * elasticity * delta * 60
		point_velocities[i] *= pow(damping, delta * 60)
		current_points[i] += point_velocities[i] * delta * 60
func update_polygon_shape():
	if polygon_node: polygon_node.polygon = current_points
func apply_impact(direction:Vector2,strength:float):
	if not polygon_node: return
	var normalized_dir = direction.normalized()
	for i in range(current_points.size()):
		var point_local = current_points[i]
		var dot_product = point_local.normalized().dot(normalized_dir)
		if dot_product > 0.1:
			var distance_factor = 1.0 / (1.0 + point_local.length() * 0.05)
			point_velocities[i] += normalized_dir * strength * dot_product * distance_factor

# --- Animation Functions (Using correct v4.5 syntax) ---
func animate_idle(delta: float):
	var time = Time.get_ticks_msec() / 1000.0
	for i in range(current_points.size()):
		var original = base_points[i]
		var angle = original.angle()
		var pulse = sin(time * 2.5) * 0.05 + 1.0
		var target = original * pulse + Vector2.from_angle(time * 1.5 + angle * 2) * 1.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 50
func animate_chasing(delta: float):
	var time = Time.get_ticks_msec() / 1000.0
	var direction = velocity.normalized() # Changed 'dir' to 'direction' for clarity
	var factor = clamp(velocity.length() / (current_move_speed + 0.01), 0.0, 1.0)
	for i in range(current_points.size()):
		var original = base_points[i]
		var dot = original.normalized().dot(direction)
		var scale_factor = lerp(1.0, 1.15, factor * dot) if dot > 0 else lerp(1.0, 0.85, factor * abs(dot)) # Changed 's' to 'scale_factor'
		var target = original * scale_factor
		target.y *= lerp(1.0, 0.9, factor)
		target += Vector2.from_angle(time * 4 + original.angle() * 3) * 1.5 * factor
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 60
func animate_flanking(delta: float):
	animate_chasing(delta) # Reuse chasing anim
func animate_preparing_lunge(delta: float):
	var progress = state_timer / lunge_prep_time
	var ease_p = ease(progress, EASE_OUT_IN)
	var squash = lerp(1.0, 0.4, ease_p)
	var spread = lerp(1.0, 1.6, ease_p)
	for i in range(current_points.size()):
		var original = base_points[i]
		var target = Vector2(original.x * spread, original.y * squash)
		target += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * progress * 3.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 100
func animate_lunging(delta: float):
	var time = Time.get_ticks_msec() / 1000.0
	var lunge_dir = velocity.normalized()
	var speed = velocity.length()
	if lunge_dir == Vector2.ZERO: lunge_dir = Vector2.UP
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
	var progress = state_timer / 0.3
	for i in range(current_points.size()):
		var original = base_points[i]
		var overshoot = lerp(1.3, 1.0, progress)
		var target = original * overshoot
		target += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * (1.0 - progress) * 4.0
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 70
func animate_stunned(delta: float):
	var time = Time.get_ticks_msec() / 1000.0
	for i in range(current_points.size()):
		var original = base_points[i]
		var target = original + Vector2(sin(time * 20 + i * 1.1) * 4, cos(time * 15 + i * 0.8) * 4)
		point_velocities[i] += (target - current_points[i]) * elasticity * delta * 60

# ==============================
# Damage Handling & Death
# ==============================
func take_damage(amount, hit_direction=Vector2.ZERO, knockback_strength=0):
	if is_instance_valid(polygon_node) and polygon_node.material is ShaderMaterial:
		var material: ShaderMaterial = polygon_node.material # Changed 'mat' to 'material'
		if flash_tween and flash_tween.is_valid():
			flash_tween.kill()
		flash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		material.set_shader_parameter("flash_modifier", 1.0)
		flash_tween.tween_method(func(value): if is_instance_valid(material): material.set_shader_parameter("flash_modifier", value), 1.0, 0.0, 0.15)
	if hit_direction != Vector2.ZERO and knockback_strength > 0:
		velocity = hit_direction * knockback_strength
		apply_impact(hit_direction, knockback_strength * 0.15)
	if amount > 20 or randf() < 0.3:
		if current_state != States.STUNNED and current_state != States.LUNGING:
			change_state(States.STUNNED)
	# --- Handle Health Reduction (Adapt!) ---
	# super.take_damage(amount, hit_direction, knockback_strength)
	# current_health -= amount; if current_health <= 0: die()
	# print("%s took %d damage." % [name, amount])
func die():
	if not is_inside_tree() or current_state == States.IDLE and state_timer > 0.1: return
	change_state(States.IDLE)
	target_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	play_death_effects()
	set_physics_process(false)
	set_process(false)
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true
func play_death_effects():
	if not is_instance_valid(polygon_node):
		queue_free()
		return
	for i in range(current_points.size()):
		point_velocities[i] = base_points[i].normalized() * randf_range(200, 500)
	var tween = create_tween().set_parallel(false)
	tween.tween_interval(0.1)
	tween.tween_property(polygon_node, "modulate:a", 0.0, 0.5).from_current()
	tween.tween_callback(queue_free)

# ==============================
# Helper Functions
# ==============================
const EASE_OUT_IN = 2.0
func ease(x: float, power: float) -> float: # Changed 'p' to 'power'
	if x < 0.5:
		return pow(2.0 * x, power) / 2.0
	else:
		return 1.0 - pow(2.0 * (1.0 - x), power) / 2.0
func set_target(target: Node2D):
	_target_node = target
	if not is_physics_processing():
		set_physics_process(true)
	if current_state == States.IDLE and _target_node:
		change_state(States.CHASING)
