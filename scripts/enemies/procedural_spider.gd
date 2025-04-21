# procedural_spider.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name ProceduralSpider

# --- Surface States ---
enum SurfaceState { ON_FLOOR, ON_WALL_R, ON_WALL_L, ON_CEILING, AIRBORNE }

# --- Exports ---
# Reference the SpiderLeg scene
@export var leg_scene: PackedScene = preload("res://scenes/enemies/spider_leg.tscn")

@export_group("Spider Movement")
@export var turn_speed: float = 8.0 # How fast body rotates to align with surface normal
@export var gravity_scale: float = 1.5 # Needs gravity to stick!

@export_group("Leg Structure & Stepping")
@export var num_legs: int = 10
@export var leg_placement_radius: float = 25.0 # How far from center legs attach
@export var leg_step_distance: float = 35.0   # How far a leg ideally reaches from anchor
@export var max_step_trigger_dist: float = 45.0 # If foot is further than this from ideal pos, trigger step
@export var leg_step_cooldown: float = 0.1    # Min time between steps for different legs
@export var leg_step_lerp_speed: float = 15.0   # How fast the foot moves to target during a step

@export_group("Leg Visuals")
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

# --- Internal Variables ---
var current_surface_state = SurfaceState.AIRBORNE # Start assuming airborne
var target_surface_normal: Vector2 = Vector2.UP   # The normal of the surface we want to stick to
var current_up_direction: Vector2 = Vector2.UP    # The spider's current perceived "up"

var legs: Array[SpiderLeg] = [] 
var leg_step_timer: float = 0.0
var next_leg_to_step: int = 0

@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var wall_check_r: RayCast2D = $WallCheckRight
@onready var wall_check_l: RayCast2D = $WallCheckLeft
@onready var body_visual: Polygon2D = $Visuals/BodyVisual

# --- Initialization ---
func _ready():
	# Call parent _ready
	super._ready()
	
	# Generate body visual
	generate_body_shape()
	
	# Spawn legs
	spawn_legs()
	
	# Force initial surface check & alignment
	update_surface_state()
	current_up_direction = -target_surface_normal
	rotation = current_up_direction.angle() + PI / 2.0
	
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

# --- Override _physics_process ---
func _physics_process(delta):
	# Skip parent's _physics_process and implement our own
	# since the spider movement is substantially different
	
	# Update state timers from parent
	state_timer += delta
	for attack_type in attack_cooldowns:
		if attack_cooldowns[attack_type] > 0:
			attack_cooldowns[attack_type] -= delta
	
	# Update leg step timer
	leg_step_timer -= delta
	
	# 1. Determine Target Surface and Up Direction
	update_surface_state()
	
	# 2. Smoothly rotate body's perceived UP towards the target surface normal's opposite
	current_up_direction = current_up_direction.lerp(-target_surface_normal, turn_speed * delta).normalized()
	
	# 3. Rotate the physics body itself
	rotation = lerp_angle(rotation, current_up_direction.angle() + PI/2.0, turn_speed * delta)
	
	# 4. Process AI state (from BaseEnemy)
	match current_ai_state:
		AIState.IDLE: process_idle_state(delta)
		AIState.CHASING: process_chasing_state(delta)
		AIState.ATTACKING: process_attacking_state(delta)
		AIState.REPOSITIONING: process_repositioning_state(delta)
		AIState.FLEEING: process_fleeing_state(delta)
		AIState.STUNNED: process_stunned_state(delta)
	
	# 5. Apply forces (Gravity + Movement)
	var final_velocity = velocity
	
	# Apply gravity pulling towards the surface
	final_velocity += target_surface_normal * (ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale) * delta
	
	# Apply surface movement acceleration
	var current_surface_velocity = velocity.slide(current_up_direction)
	var target_surface_velocity = target_velocity # Already calculated along surface in process_*_state
	var new_surface_velocity = current_surface_velocity.move_toward(target_surface_velocity, acceleration * delta * 60)
	
	# Reconstruct velocity: component towards surface + component along surface
	final_velocity = velocity.project(target_surface_normal) + new_surface_velocity
	
	# 6. Execute Movement
	velocity = final_velocity
	move_and_slide()
	
	# 7. Update Legs Periodically
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
	target_velocity = surface_direction * target_dot * move_speed
	
	# Check if in attack range
	var distance = global_position.distance_to(_target_node.global_position)
	if distance < preferred_attack_distance:
		change_ai_state(AIState.ATTACKING)

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

# --- Surface Movement Helpers ---

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

func update_leg_steps():
	if legs.is_empty(): return
	
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
		
		var leg_instance = leg_scene.instantiate() as SpiderLeg
		if not leg_instance:
			printerr("Failed to instantiate SpiderLeg!")
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
		
		legs.append(leg_instance)

# --- Attack Implementation ---

func execute_melee_attack(attack_data: Dictionary):
	# Only proceed if we have a valid target
	if not is_instance_valid(_target_node):
		return
	
	# Get attack attributes
	var damage = attack_data.get("damage", 15)
	var knockback = attack_data.get("knockback", 100.0)
	
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
