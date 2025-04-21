# procedural_spider_3d.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name ProceduralSpider3D

# --- Physics Layer Constants (From original script) ---
const TERRAIN_LAYER = 1         # Bit = 1 << 0
const PLAYER_PLANE_LAYER = 10   # Bit = 1 << 9
const FOREGROUND_LAYER = 11     # Bit = 1 << 10

# --- Surface States ---
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }

# --- Depth States ---
enum DepthState { PLAYER_PLANE, FOREGROUND, TRANSITIONING }

# --- Exports ---
# Reference the SpiderLeg scene for 3D
@export var leg_scene: PackedScene = preload("res://scenes/enemies/spider_leg_3d.tscn")

@export_group("Spider Movement")
@export var turn_speed: float = 8.0
@export var gravity_scale: float = 1.5

@export_group("Leg Structure & Stepping")
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

# --- Internal Variables ---
var current_surface_state = SurfaceState.AIRBORNE
var current_depth_state = DepthState.PLAYER_PLANE # Start on player plane
var target_surface_normal: Vector2 = Vector2.UP
var current_up_direction: Vector2 = Vector2.UP

var legs: Array[SpiderLeg_Pseudo3D] = []
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
	# Call parent _ready
	super._ready()
	
	# Set initial gravity
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale
	
	# Initialize scales
	target_scale = player_plane_scale
	scale = player_plane_scale
	
	# Generate body shape
	generate_body_shape()
	
	# Spawn legs
	spawn_legs()
	
	# Force initial surface check & alignment
	update_surface_state()
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0
	
	# Set initial collision based on starting depth state
	set_collision_for_depth_state(current_depth_state)
	
	# Initialize with idle state
	change_ai_state(AIState.IDLE)

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Add to enemies group
	add_to_group("enemies")
	
	# Set collision layers - will be updated based on depth state
	collision_layer = 1 << (PLAYER_PLANE_LAYER - 1)  # Initial layer
	collision_mask = 1 << (TERRAIN_LAYER - 1)        # Always collide with terrain

# --- Override _physics_process ---
func _physics_process(delta):
	# Skip parent's _physics_process and implement our own
	# since the spider movement is substantially different and
	# we need to handle depth state
	
	# Update state timers from parent
	state_timer += delta
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# 1. Update Surface and Depth States
	update_surface_state()
	update_depth_state(delta)
	
	# 2. Smoothly rotate body's perceived UP towards the target surface normal's opposite
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	
	# 3. Rotate the physics body itself
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)
	
	# 4. Update Scale (for Pseudo-3D effect)
	if scale.distance_squared_to(target_scale) > 0.001:
		scale = scale.lerp(target_scale, scale_lerp_speed * delta)
	
	# 5. Process AI state (from BaseEnemy)
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)
		AIState.REPOSITIONING: process_repositioning_state(delta)
		AIState.FLEEING: process_fleeing_state(delta)
		AIState.STUNNED: process_stunned_state(delta)
	
	# 6. Apply forces (Gravity + Movement)
	var final_velocity = velocity
	
	# Apply gravity pulling towards the surface
	final_velocity += target_surface_normal * gravity * delta
	
	# Apply surface movement acceleration - only if not transitioning depth
	if current_depth_state != DepthState.TRANSITIONING:
		var current_surface_velocity = velocity.slide(current_up_direction)
		var target_surface_velocity = target_velocity  # From state processing
		var new_surface_velocity = current_surface_velocity.move_toward(target_surface_velocity, acceleration * delta * 60)
		final_velocity = velocity.project(target_surface_normal) + new_surface_velocity
	
	# 7. Execute Movement
	velocity = final_velocity
	move_and_slide()
	
	# 8. Update Legs Periodically
	leg_step_timer -= delta
	if leg_step_timer <= 0:
		update_leg_steps()
		leg_step_timer = leg_step_cooldown

# --- Override State Processing Functions ---

func process_idle_state(delta):
	# Set idle movement along surface
	target_velocity = current_wander_direction * move_speed * wander_speed_multiplier
	
	# Convert to surface-aligned movement
	var surface_direction = current_up_direction.orthogonal()
	var surface_dot = target_velocity.normalized().dot(surface_direction)
	target_velocity = surface_direction * surface_dot * move_speed * wander_speed_multiplier
	
	# Check for targets
	find_target()

func process_chasing_state(delta):
	# Skip if no target
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Calculate movement vector along the surface
	var vector_to_target_global = _target_node.global_position - global_position
	var surface_direction = current_up_direction.orthogonal()
	var target_dot = vector_to_target_global.normalized().dot(surface_direction)
	
	# Move only if not transitioning or if allowed during transition
	if current_depth_state != DepthState.TRANSITIONING:
		target_velocity = surface_direction * target_dot * move_speed
	else:
		target_velocity = Vector2.ZERO
	
	# Check if in attack range
	var distance = global_position.distance_to(_target_node.global_position)
	if distance < preferred_attack_distance and current_depth_state != DepthState.TRANSITIONING:
		change_ai_state(AIState.ATTACKING)
	
	# Consider depth transition when chasing
	if current_depth_state == DepthState.PLAYER_PLANE:
		if distance < foreground_trigger_distance:
			move_to_foreground()

func process_attacking_state(delta):
	# If we lost our target, go back to idle/chase
	if not is_instance_valid(_target_node):
		attack_state_timer = 0.0
		change_ai_state(AIState.CHASING)
		return
	
	# Get distance to target
	var distance = global_position.distance_to(_target_node.global_position)
	
	# If out of range, chase again
	if distance > preferred_attack_distance * 1.5:
		attack_state_timer = 0.0
		change_ai_state(AIState.CHASING)
		return
	
	# Reduce movement speed during attack but continue some movement
	var vector_to_target_global = _target_node.global_position - global_position
	var surface_direction = current_up_direction.orthogonal()
	var target_dot = vector_to_target_global.normalized().dot(surface_direction)
	target_velocity = surface_direction * target_dot * move_speed * combat_movement_speed_multiplier
	
	# Try to perform an attack if we've been in this state long enough
	if attack_state_timer >= min_attack_state_duration:
		attack_closest_target()

func process_stunned_state(delta):
	# Stop movement
	target_velocity = Vector2.ZERO
	
	# Recover after 1 second
	if state_timer >= 1.0:
		change_ai_state(AIState.IDLE)

# --- Surface and Depth State Management ---

func update_surface_state():
	# Determine which surface we're on and get the normal
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
		current_surface_state = new_state
	
	# Target normal drives gravity direction
	target_surface_normal = detected_normal.normalized()

func update_depth_state(delta: float):
	match current_depth_state:
		DepthState.PLAYER_PLANE:
			# Check if player is close enough to trigger move to foreground
			if is_instance_valid(_target_node):
				var dist_sq = global_position.distance_squared_to(_target_node.global_position)
				if dist_sq < foreground_trigger_distance * foreground_trigger_distance:
					move_to_foreground()

		DepthState.FOREGROUND:
			# Countdown timer to return to player plane
			foreground_timer -= delta
			if foreground_timer <= 0:
				move_to_player_plane()

		DepthState.TRANSITIONING:
			# Check if scale is close enough to target to finish transition
			if scale.distance_squared_to(target_scale) < 0.01:
				if target_scale == foreground_scale:
					current_depth_state = DepthState.FOREGROUND
					foreground_timer = foreground_duration  # Start the timer
				else:
					current_depth_state = DepthState.PLAYER_PLANE

func move_to_foreground():
	if current_depth_state == DepthState.FOREGROUND:
		return  # Already there
		
	current_depth_state = DepthState.TRANSITIONING
	target_scale = foreground_scale
	set_collision_for_depth_state(DepthState.FOREGROUND)
	
	# Set Z-index (higher value = visually in front)
	z_index = 10
	if is_instance_valid(body_visual):
		body_visual.z_index = 0  # Relative to parent
		
	# Update legs z-index
	for leg in legs:
		if is_instance_valid(leg) and leg.has_method("set_leg_z_index"):
			leg.set_leg_z_index(1)  # Relative to parent

func move_to_player_plane():
	if current_depth_state == DepthState.PLAYER_PLANE:
		return  # Already there
		
	current_depth_state = DepthState.TRANSITIONING
	target_scale = player_plane_scale
	set_collision_for_depth_state(DepthState.PLAYER_PLANE)
	
	# Reset Z-index
	z_index = 0
	if is_instance_valid(body_visual):
		body_visual.z_index = 0
		
	# Update legs z-index
	for leg in legs:
		if is_instance_valid(leg) and leg.has_method("set_leg_z_index"):
			leg.set_leg_z_index(0)

func set_collision_for_depth_state(state: DepthState):
	# Mask should ALWAYS include terrain layer for movement casts
	var terrain_mask = 1 << (TERRAIN_LAYER - 1)  # Bitmask for terrain layer
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

# --- Leg Management Functions ---

func update_leg_steps():
	if legs.is_empty():
		return
	
	# Cycle through legs to step one at a time
	var leg_index = next_leg_to_step
	if leg_index >= legs.size():
		next_leg_to_step = 0
		return
	
	var leg = legs[leg_index]
	if not is_instance_valid(leg) or leg.is_stepping:
		next_leg_to_step = (leg_index + 1) % num_legs
		return
	
	# Calculate the ideal position for this foot 
	var ideal_foot_global = to_global(leg.base_anchor_local) - current_up_direction * leg_step_distance
	
	# Check distance from current foot position to ideal
	var dist_sq = leg.current_foot_global.distance_squared_to(ideal_foot_global)
	
	# If foot is too far from ideal, find a new step target
	if dist_sq > max_step_trigger_dist * max_step_trigger_dist:
		var step_target_global = find_valid_step_location(ideal_foot_global, to_global(leg.base_anchor_local))
		leg.start_step(step_target_global)
	
	# Move to the next leg
	next_leg_to_step = (leg_index + 1) % num_legs

func find_valid_step_location(ideal_pos_global: Vector2, anchor_pos_global: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	
	# Ray starts above ideal pos (relative to spider up)
	var ray_start = ideal_pos_global + current_up_direction * 5.0
	
	# Cast down (relative to spider up)
	var ray_end = ideal_pos_global - current_up_direction * (leg_step_distance * 1.5)
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, [self])
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position  # Found surface
	else:
		# No surface found, fallback towards anchor
		return anchor_pos_global - current_up_direction * (leg_step_distance * 0.5)

# --- Leg & Body Visual Methods ---

func generate_body_shape():
	if not body_visual:
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
		printerr("Leg scene not set!")
		return
	
	# Clear any existing legs
	for leg in legs:
		if is_instance_valid(leg):
			leg.queue_free()
	legs.clear()
	
	# Need to know the initial 'down' direction to place feet
	var initial_down = -current_up_direction
	
	var angle_step = TAU / float(num_legs)
	for i in range(num_legs):
		var angle = float(i) * angle_step
		
		# Calculate anchor position
		var anchor_pos_local = Vector2.from_angle(angle) * leg_placement_radius
		
		var leg_instance = leg_scene.instantiate() as SpiderLeg_Pseudo3D
		if not leg_instance:
			printerr("Failed to instantiate SpiderLeg_Pseudo3D!")
			continue
		
		add_child(leg_instance)
		
		# Initial foot placement
		var initial_anchor_global = to_global(anchor_pos_local)
		var desired_foot_pos = initial_anchor_global + initial_down * leg_step_distance
		var initial_foot_pos = find_valid_step_location(desired_foot_pos, initial_anchor_global)
		
		# Setup the leg
		if leg_instance.has_method("setup_leg"):
			leg_instance.setup_leg(
				self,
				anchor_pos_local,
				initial_foot_pos,
				leg_num_segments,
				leg_base_width,
				leg_tip_width,
				leg_color
			)
			
			# Set follow speed if method exists
			if leg_instance.has_method("set_follow_lerp_speed"):
				leg_instance.set_follow_lerp_speed(leg_follow_lerp_speed)
				
			# Set initial z-index based on current depth state
			if leg_instance.has_method("set_leg_z_index"):
				leg_instance.set_leg_z_index(1 if current_depth_state == DepthState.FOREGROUND else 0)
		
		legs.append(leg_instance)

# --- Attack Implementation ---

func execute_melee_attack(attack_data: Dictionary):
	# Only proceed if we have a valid target
	if not is_instance_valid(_target_node):
		return
	
	# Get attack attributes
	var damage = attack_data.get("damage", 20)
	var knockback = attack_data.get("knockback", 120.0)
	
	# Calculate direction to target
	var direction = (_target_node.global_position - global_position).normalized()
	
	# Apply damage if target has take_damage method
	if _target_node.has_method("take_damage"):
		_target_node.take_damage(damage, direction, knockback)
	
	# Could add animation here if spider had one

# --- BaseEnemy Overrides ---

func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Call parent method
	super.take_damage(amount, hit_direction, knockback_strength)
	
	# Spider-specific: consider detaching some legs when hit
	if randf() < 0.3:
		var leg_count = min(2, legs.size())
		var shuffled_indices = range(legs.size())
		shuffled_indices.shuffle()
		
		for i in range(leg_count):
			if i < shuffled_indices.size():
				var leg_idx = shuffled_indices[i]
				if leg_idx < legs.size() and is_instance_valid(legs[leg_idx]):
					# If leg has detach method or similar
					if legs[leg_idx].has_method("start_step"):
						var random_dir = Vector2.from_angle(randf() * TAU)
						var detach_target = legs[leg_idx].current_foot_global + random_dir * 30.0
						legs[leg_idx].start_step(detach_target)
	
	# Return to player plane when hit in foreground
	if current_depth_state == DepthState.FOREGROUND:
		move_to_player_plane()

func play_death_effects():
	# First call parent method
	super.play_death_effects()
	
	# Disable legs
	for leg in legs:
		if is_instance_valid(leg):
			# Make legs fade with body
			leg.modulate = modulate
	
	# Body death effect
	if body_visual:
		body_visual.modulate.a = 0.7
		
		# Create a tween for death animation
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
		tween.tween_callback(queue_free)

# --- Helper Functions ---
const EASE_OUT_IN = 2.0
func ease(x: float, power: float) -> float:
	if x < 0.5:
		return pow(2.0 * x, power) / 2.0
	else:
		return 1.0 - pow(2.0 * (1.0 - x), power) / 2.0
