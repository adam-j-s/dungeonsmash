# surface_crawler.gd
extends BaseEnemy
class_name SurfaceCrawler

# --- Parameters ---
@export_group("Surface Crawling")
@export var platform_speed: float = 70.0
@export var wall_speed: float = 60.0   # Base speed for wall travel
@export var ceiling_speed: float = 60.0
@export var can_climb_walls: bool = true
@export var can_traverse_ceiling: bool = true
@export var ceiling_stick_force: float = 150.0 # Applied over time (delta)
@export var wall_stick_force: float = 500.0   # Applied over time (delta)
@export var wall_climb_speed_limit: float = 45.0 # Speed limit ONLY when climbing UP

# --- State ---
var move_direction: int = 1       # 1 = right, -1 = left (relative to surface)
var climb_direction: int = -1     # -1 = up, 1 = down (relative to wall)
var current_surface: String = "ground" # ground, wall_left, wall_right, ceiling, none
var transition_timer: float = 0.0  # Cooldown to prevent rapid state changes

# --- Raycasts (MUST exist in the scene as children of 'RayCasts' node) ---
@onready var raycasts_node: Node2D = $RayCasts
# Renamed for clarity matching previous refactor suggestion:
@onready var ground_edge_detector: RayCast2D = $RayCasts/GroundEdgeDetector    # Looks down past feet from front edge on ground
@onready var wall_ahead_detector: RayCast2D = $RayCasts/WallAheadDetector      # Looks into wall surface ahead (up/down)
@onready var surface_normal_detector: RayCast2D = $RayCasts/SurfaceNormalDetector # Looks directly into the current surface (wall/ceiling)
@onready var transition_detector: RayCast2D = $RayCasts/TransitionDetector    # Looks perpendicular to current surface for next surface (e.g., ceiling from wall, wall from ceiling edge)

const RAYCAST_LENGTH_SHORT: float = 12.0
const RAYCAST_LENGTH_MEDIUM: float = 28.0
const RAYCAST_LENGTH_LONG: float = 45.0

# --- Initialization ---
func _ready():
	super._ready() # Call BaseEnemy's ready FIRST

	# --- Configure BaseEnemy for simple crawling ---
	use_gravity = false         # Crawler handles its own gravity/sticking logic
	use_avoidance = false       # Avoidance conflicts with surface sticking
	# Disable AI state influence on movement (we only use move_direction/climb_direction)
	aggression_level = 0.0
	direct_chase = false        # Doesn't use BaseEnemy chase logic
	sight_range = 0.0           # Doesn't use BaseEnemy target finding for movement
	# Set a high acceleration/low damping if BaseEnemy's defaults interfere,
	# but setting velocity directly should mostly bypass them.
	# acceleration = 50.0
	# damping = 1.0 # No friction/damping from base class

	# --- Verify Raycasts ---
	if not _verify_raycasts():
		set_physics_process(false) # Stop processing if setup is invalid
		return

	# --- Initial State ---
	current_surface = "ground" # Assume starting on ground
	up_direction = Vector2.UP  # Initial up direction for CharacterBody2D
	transition_timer = 0.5     # Initial delay before first move/transition

	print("Surface crawler '%s' initialized using BaseEnemy hooks." % name)

func _verify_raycasts() -> bool:
	if not is_instance_valid(raycasts_node):
		push_error("SurfaceCrawler '%s' requires a child Node2D named 'RayCasts'." % name)
		return false
	var all_found = true
	if not is_instance_valid(ground_edge_detector): push_error("RayCast 'GroundEdgeDetector' missing."); all_found = false
	if not is_instance_valid(wall_ahead_detector): push_error("RayCast 'WallAheadDetector' missing."); all_found = false
	if not is_instance_valid(surface_normal_detector): push_error("RayCast 'SurfaceNormalDetector' missing."); all_found = false
	if not is_instance_valid(transition_detector): push_error("RayCast 'TransitionDetector' missing."); all_found = false

	if all_found:
		# Ensure they are enabled and have a collision mask (adjust mask if needed)
		for child in raycasts_node.get_children():
			if child is RayCast2D:
				child.enabled = true
				child.collision_mask = 1 # Assumes world geometry is on layer 1
	return all_found

# --- Override AI Logic Hook (Called BEFORE move_and_slide) ---
func perform_ai_logic(delta):
	# We don't call super.perform_ai_logic() because we don't want BaseEnemy's
	# state machine or target_velocity calculations to affect this simple crawler.

	# Update timers
	if transition_timer > 0:
		transition_timer -= delta

	# --- Calculate Velocity based on current surface ---
	var calculated_velocity = Vector2.ZERO
	match current_surface:
		"ground":
			calculated_velocity = _calculate_ground_velocity(delta)
			up_direction = Vector2.UP
		"wall_left":
			calculated_velocity = _calculate_wall_velocity(delta, Vector2.RIGHT) # Pass wall's outward normal
			up_direction = Vector2.RIGHT
		"wall_right":
			calculated_velocity = _calculate_wall_velocity(delta, Vector2.LEFT) # Pass wall's outward normal
			up_direction = Vector2.LEFT
		"ceiling":
			calculated_velocity = _calculate_ceiling_velocity(delta)
			up_direction = Vector2.DOWN
		_: # air / none
			calculated_velocity = _calculate_air_velocity(delta)
			up_direction = Vector2.UP

	# --- Apply calculated velocity and settings for BaseEnemy ---
	velocity = calculated_velocity         # Set the final velocity for move_and_slide
	_velocity_set_by_component = true    # Tell BaseEnemy we handled velocity calculation
	use_gravity = (current_surface == "none") # Only use base gravity when falling

	# Configure raycasts based on current state *before* movement potentially changes it
	# (Their results will be read *after* movement in _post_physics_update)
	_configure_raycasts_for_state()


# --- Velocity Calculation Helpers (Called by perform_ai_logic) ---

func _calculate_ground_velocity(_delta) -> Vector2:
	var target_vel = Vector2.ZERO
	target_vel.x = move_direction * platform_speed
	target_vel.y = 30 # Small downward force to ensure floor contact
	return target_vel

func _calculate_wall_velocity(delta, wall_outward_normal: Vector2) -> Vector2:
	var target_vel = Vector2.ZERO
	var current_climb_speed = wall_speed
	if climb_direction < 0: # Moving up, apply speed limit
		current_climb_speed = min(wall_speed, wall_climb_speed_limit)

	# Base vertical/horizontal velocity along the wall (orthogonal to up_direction)
	target_vel = up_direction.orthogonal() * climb_direction * current_climb_speed

	# Apply force INTO the wall (opposite of outward normal) over time
	target_vel -= wall_outward_normal * wall_stick_force * delta

	return target_vel

func _calculate_ceiling_velocity(delta) -> Vector2:
	var target_vel = Vector2.ZERO
	target_vel.x = move_direction * ceiling_speed

	# Apply sticking force (world UP) over time to counteract gravity/maintain contact
	# This force pushes towards the ceiling surface (which is world down relative to crawler)
	target_vel += Vector2.UP * ceiling_stick_force * delta

	return target_vel

func _calculate_air_velocity(_delta) -> Vector2:
	# Keep horizontal momentum, allow some air control
	var target_vel_x = move_direction * platform_speed * 0.7
	# Keep existing vertical velocity; BaseEnemy will add gravity if use_gravity is true
	return Vector2(target_vel_x, velocity.y)


# --- Raycast Configuration (Called by perform_ai_logic) ---
# Sets up raycast positions and targets based on the current state
func _configure_raycasts_for_state():
	var extents = get_collision_shape_extents()

	match current_surface:
		"ground":
			ground_edge_detector.position = Vector2(extents.x * move_direction * 0.95, 0)
			ground_edge_detector.target_position = Vector2(0, extents.y + RAYCAST_LENGTH_SHORT)
			# Disable others or set to safe defaults if needed
			wall_ahead_detector.target_position = Vector2.ZERO
			surface_normal_detector.target_position = Vector2.ZERO
			transition_detector.target_position = Vector2.ZERO

		"wall_left", "wall_right":
			var wall_outward_normal = -up_direction # up_direction points out from wall
			var ahead_offset_y = extents.y * 0.9 * climb_direction
			var detector_base_x = extents.x * 0.5 * (-wall_outward_normal.x) # Position slightly away from wall surface

			# Ground edge detector not used on wall
			ground_edge_detector.target_position = Vector2.ZERO

			# Wall Ahead: Look into wall surface, ahead in climb direction
			wall_ahead_detector.position = Vector2(detector_base_x, ahead_offset_y)
			wall_ahead_detector.target_position = -wall_outward_normal * RAYCAST_LENGTH_MEDIUM

			# Surface Normal: Look directly into wall surface from center
			surface_normal_detector.position = Vector2(detector_base_x, 0)
			surface_normal_detector.target_position = -wall_outward_normal * RAYCAST_LENGTH_SHORT

			# Transition: Look perpendicular to wall (world up/down) from leading edge
			transition_detector.position = Vector2(0, ahead_offset_y)
			# climb_direction = -1 (up), target = (0, -Len) [world UP]
			# climb_direction =  1 (down), target = (0, Len) [world DOWN]
			transition_detector.target_position = Vector2(0, RAYCAST_LENGTH_MEDIUM * climb_direction)

		"ceiling":
			var ahead_offset_x = extents.x * 0.9 * move_direction
			var detector_base_y = extents.y * 0.6 # Slightly below center (world Y relative to crawler)

			# Ground edge detector not used
			ground_edge_detector.target_position = Vector2.ZERO
			# Wall ahead detector not used
			wall_ahead_detector.target_position = Vector2.ZERO

			# Surface Normal: Look UP (world) from center to check attachment
			surface_normal_detector.position = Vector2(0, detector_base_y)
			surface_normal_detector.target_position = Vector2(0, -RAYCAST_LENGTH_SHORT) # World UP

			# Transition: Look UP (world) from leading edge to detect end of ceiling
			transition_detector.position = Vector2(ahead_offset_x, detector_base_y)
			transition_detector.target_position = Vector2(0, -RAYCAST_LENGTH_MEDIUM) # World UP

		"none": # Air - disable most surface detectors
			ground_edge_detector.target_position = Vector2.ZERO
			wall_ahead_detector.target_position = Vector2.ZERO
			surface_normal_detector.target_position = Vector2.ZERO
			transition_detector.target_position = Vector2.ZERO


# --- Override Post Physics Hook (Called AFTER move_and_slide) ---
func _post_physics_update(_delta):
	# Don't run transition checks if a transition just happened
	if transition_timer > 0:
		# Optional: Could add logic here for during-transition adjustments if needed
		return

	# Get physics state *after* move_and_slide
	var current_is_on_floor = is_on_floor()
	var current_is_on_wall = is_on_wall()
	var current_is_on_ceiling = is_on_ceiling()
	var current_wall_normal = get_wall_normal() # CharacterBody2D's result

	# Force update raycasts to get results based on the NEW position
	ground_edge_detector.force_raycast_update()
	wall_ahead_detector.force_raycast_update()
	surface_normal_detector.force_raycast_update()
	transition_detector.force_raycast_update()

	# --- Transition Logic ---
	match current_surface:
		"ground":
			# Ground -> Wall (Hit a wall while moving horizontally)
			if current_is_on_wall and can_climb_walls and abs(velocity.x) > 5.0: # Check velocity to ensure intentional collision
				# Check if moving towards the wall normal indicates
				if (current_wall_normal.x < -0.7 and move_direction > 0) or \
				   (current_wall_normal.x > 0.7 and move_direction < 0):
					_transition_to_wall(current_wall_normal, false) # From ground = false
					return # Transition occurred

			# Ground -> Air (Fell off edge - check ground detector)
			elif current_is_on_floor and not ground_edge_detector.is_colliding() and transition_timer <= 0:
				print("Transition: Ground -> Air (Edge)")
				current_surface = "none"
				transition_timer = 0.15
				return
			# Ground -> Air (Lost floor contact unexpectedly)
			elif not current_is_on_floor and not current_is_on_wall and transition_timer <= 0:
				print("Transition: Ground -> Air (Lost Floor)")
				current_surface = "none"
				transition_timer = 0.1
				return

		"wall_left", "wall_right":
			var wall_continues = wall_ahead_detector.is_colliding()
			var surface_detected_perp = transition_detector.is_colliding()
			var perp_normal = transition_detector.get_collision_normal() if surface_detected_perp else Vector2.ZERO

			if climb_direction < 0: # --- Moving UP the wall ---
				# Wall -> Ceiling (Highest Priority: Hit ceiling OR detected ceiling above)
				if can_traverse_ceiling and (current_is_on_ceiling or (surface_detected_perp and perp_normal.y < -0.7)): # Normal points DOWNWARD from ceiling
					print("Transition: Wall -> Ceiling")
					current_surface = "ceiling"
					# Set horizontal direction based on which wall we came from
					move_direction = 1 if current_surface == "wall_right" else -1
					# Give a nudge to help attach
					velocity.y = -50
					transition_timer = 0.4
					return

				# Wall -> Air (Top edge, no ceiling detected by perp ray or direct contact)
				elif not wall_continues and not surface_detected_perp and not current_is_on_ceiling:
					print("Transition: Wall -> Reverse (Top Edge Reached)")
					climb_direction *= -1 # Reverse to go down
					velocity.y = 0 # Stop upward movement briefly
					transition_timer = 0.3
					return

			else: # --- Moving DOWN the wall ---
				# Wall -> Ground (Hit floor)
				if current_is_on_floor:
					print("Transition: Wall -> Ground")
					current_surface = "ground"
					move_direction = 1 if current_surface == "wall_right" else -1 # Set horizontal based on wall
					transition_timer = 0.2
					return

			# Wall -> Air (Lost contact - check main surface detector)
			if not surface_normal_detector.is_colliding() and not current_is_on_wall:
				# Double check we didn't accidentally hit floor/ceiling in the same frame
				if not current_is_on_floor and not current_is_on_ceiling:
					print("Transition: Wall -> Air (Lost Contact)")
					current_surface = "none"
					transition_timer = 0.1
					return


		"ceiling":
			var ceiling_continues_ahead = transition_detector.is_colliding() # Checks UP from front edge
			var still_on_ceiling_center = surface_normal_detector.is_colliding() # Checks UP from center

			# Ceiling -> Wall (Hit a side wall while moving horizontally)
			if current_is_on_wall and can_climb_walls and abs(velocity.x) > 5.0:
				# Check if moving towards the wall
				if (current_wall_normal.x < -0.7 and move_direction > 0) or \
				   (current_wall_normal.x > 0.7 and move_direction < 0):
					_transition_to_wall(current_wall_normal, true) # From ceiling = true
					return

			# Ceiling -> Air/Wall (Reached Edge - front detector misses, center still hits)
			elif not ceiling_continues_ahead and still_on_ceiling_center:
				# Check for a wall directly below the edge point
				if _check_for_wall_below_ceiling_edge():
					print("Transition: Ceiling Edge -> Wall Down")
					# Transition to the correct wall, starting downwards
					_transition_to_wall(Vector2(-1, 0) if move_direction > 0 else Vector2(1, 0), true)
					return
				else:
					# No wall found, reverse direction on ceiling
					print("Transition: Ceiling -> Reverse (Edge, No Wall)")
					move_direction *= -1
					velocity.x = 0 # Stop briefly
					transition_timer = 0.3
					return

			# Ceiling -> Air (Lost contact - center detector misses)
			elif not still_on_ceiling_center and not current_is_on_ceiling:
				# Double check we didn't hit a wall in the same frame
				if not current_is_on_wall:
					print("Transition: Ceiling -> Air (Lost Contact)")
					current_surface = "none"
					transition_timer = 0.1
					return

		"none": # --- Currently in Air ---
			# Air -> Ground
			if current_is_on_floor:
				print("Transition: Air -> Ground")
				current_surface = "ground"
				transition_timer = 0.1
				return
			# Air -> Wall
			elif current_is_on_wall and can_climb_walls:
				print("Transition: Air -> Wall")
				_transition_to_wall(current_wall_normal, false) # Treat as coming from ground/air
				return
			# Air -> Ceiling
			elif current_is_on_ceiling and can_traverse_ceiling:
				print("Transition: Air -> Ceiling")
				current_surface = "ceiling"
				transition_timer = 0.2
				return


# --- Helper Functions ---

func _check_for_wall_below_ceiling_edge() -> bool:
	var extents = get_collision_shape_extents()
	# Start check just beyond the collider's edge in movement direction, slightly below center line
	var check_start_offset = Vector2(extents.x * 1.1 * move_direction, extents.y * 0.3)
	var check_start_pos = global_position + check_start_offset
	# Look straight down
	var check_end_pos = check_start_pos + Vector2(0, RAYCAST_LENGTH_MEDIUM)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(check_start_pos, check_end_pos, collision_mask, [self])
	var result = space_state.intersect_ray(query)
	return result != null # Return true if any collision downward is found

func _transition_to_wall(wall_normal: Vector2, from_ceiling: bool):
	var new_surface = ""
	if wall_normal.x > 0.7: # Hit wall on the left (normal points right)
		new_surface = "wall_left"
		print("Transition: -> Wall Left")
	elif wall_normal.x < -0.7: # Hit wall on the right (normal points left)
		new_surface = "wall_right"
		print("Transition: -> Wall Right")
	else:
		print("Warning: Invalid wall normal for transition: ", wall_normal)
		return # Don't transition on ambiguous normal

	current_surface = new_surface

	# Set climb direction based on origin
	if from_ceiling:
		climb_direction = 1 # Start moving down the wall
	else: # From ground or air
		climb_direction = -1 # Start moving up the wall

	transition_timer = 0.3 # Cooldown

func get_collision_shape_extents() -> Vector2:
	# Find the first CollisionShape2D child (non-recursive)
	var shape_node = find_child("CollisionShape2D", false, false)
	if shape_node and shape_node is CollisionShape2D:
		var shape = shape_node.shape
		if shape is RectangleShape2D:
			return shape.size / 2.0
		elif shape is CircleShape2D:
			return Vector2(shape.radius, shape.radius)
		elif shape is CapsuleShape2D:
			return Vector2(shape.radius, shape.height / 2.0 + shape.radius)
		else:
			push_warning("SurfaceCrawler '%s': Unsupported CollisionShape type: %s" % [name, shape.get_class()])
	else:
		push_warning("SurfaceCrawler '%s': No direct CollisionShape2D child found. Using default extents." % name)

	return Vector2(8, 8) # Default fallback extents

# Interface function for animation component (if needed)
# Renamed to avoid potential conflicts and be more descriptive
func get_crawler_surface_info() -> Dictionary:
	var surface_direction = Vector2.ZERO # Direction *along* the surface
	match current_surface:
		"ground": surface_direction = Vector2(move_direction, 0)
		"ceiling": surface_direction = Vector2(move_direction, 0)
		"wall_left": surface_direction = Vector2(0, climb_direction) # climb_dir is -1 up, 1 down
		"wall_right": surface_direction = Vector2(0, climb_direction)
		_: surface_direction = Vector2(move_direction, 0) # Air

	return {
		"type": current_surface,
		"local_direction": surface_direction, # Movement relative to surface orientation
		"world_velocity": velocity,
		"world_up_vector": up_direction    # CharacterBody's up direction
	}
