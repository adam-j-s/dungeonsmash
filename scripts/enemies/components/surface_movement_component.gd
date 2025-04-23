# surface_movement_component.gd
# Predictive Raycast Approach (Phase 1: Basic Surfaces)
class_name SurfaceMovementComponent
extends EnemyComponent # MUST EXTEND NODE2D via EnemyComponent

# --- Parameters ---
@export_group("Movement")
@export var surface_speed: float = 70.0
@export var rotation_speed: float = TAU # Radians per second (TAU = full circle)

@export_group("Sticking & Physics")
@export var use_sticking_force: bool = true
@export var constant_sticking_magnitude: float = 100.0 # Reduced default for testing

@export_group("Raycasts")
@export var ground_check_distance: float = 15.0 # How far the ground ray checks
@export var wall_check_distance: float = 15.0   # How far the forward wall check ray checks
@export var surface_normal_threshold: float = 0.95 # Cosine of angle (closer to 1 = flatter surface required)

# --- Internal State ---
var _current_surface_normal: Vector2 = Vector2.UP # Normal OF the surface BELOW/BEHIND the enemy
var _is_on_surface: bool = false
var _target_up_direction: Vector2 = Vector2.UP # Desired enemy UP based on surface normal

# --- Physics ---
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

# --- Node References ---
@onready var ground_ray: RayCast2D = $GroundRay_Center
# Add more rays later for stability/corners (e.g., GroundRay_Left, GroundRay_Right)
# @onready var wall_ray: RayCast2D = $WallRay_Center # Not used in Phase 1 detection

# --- Initialization ---
var _is_initialized: bool = false

#-----------------------------------------------------------------------------#
# Setup & Initialization                                                      #
#-----------------------------------------------------------------------------#

func setup():
	if not is_instance_valid(enemy):
		push_error("[%s] Enemy instance is invalid during setup!" % name)
		return

	# Configure Raycasts
	if is_instance_valid(ground_ray):
		ground_ray.target_position = Vector2(0, ground_check_distance)
		ground_ray.enabled = true
		ground_ray.exclude_parent = true # Make sure it doesn't hit the parent enemy
		# Make sure ray collision mask is set correctly in the editor
	else:
		push_error("[%s] GroundRay_Center node not found or invalid!" % name)
		set_process(false) # Disable component if rays are missing
		return

	# Config Loading (Optional)
	if "config" in enemy and enemy.config:
		if enemy.config.component_configs.has("SurfaceMovement"):
			var config = enemy.config.component_configs["SurfaceMovement"]
			surface_speed = config.get("surface_speed", surface_speed)
			rotation_speed = deg_to_rad(config.get("rotation_speed_deg", rad_to_deg(rotation_speed))) # Allow config in degrees
			use_sticking_force = config.get("use_sticking_force", use_sticking_force)
			constant_sticking_magnitude = config.get("constant_sticking_magnitude", constant_sticking_magnitude)
			ground_check_distance = config.get("ground_check_distance", ground_check_distance)
			wall_check_distance = config.get("wall_check_distance", wall_check_distance)
			if is_instance_valid(ground_ray): ground_ray.target_position.y = ground_check_distance
			# Update other ray distances if added later
			if DEBUG: print("[%s] Applied SurfaceMovement config." % name)
		else:
			if DEBUG: print("[%s] No SurfaceMovement config found, using defaults." % name)
	else:
		if DEBUG: print("[%s] Enemy config not found or invalid, using defaults." % name)

	# Initial State (Assume starting airborne or on ground)
	_current_surface_normal = Vector2.UP
	_target_up_direction = -_current_surface_normal # Enemy UP is opposite surface normal
	_is_on_surface = false # Will be determined by first raycast

	if is_instance_valid(enemy): enemy.up_direction = _target_up_direction

	_is_initialized = true
	if DEBUG: print("[%s] Setup complete. Sticking Mag: %.1f" % [name, constant_sticking_magnitude])


#-----------------------------------------------------------------------------#
# Main Processing Loop (Called by BaseEnemy._physics_process before move_and_slide) #
#-----------------------------------------------------------------------------#

func process(delta: float):
	if not _is_initialized or not is_instance_valid(enemy): return
	# (Add stun check if needed)

		# --- 1. Ground Detection using Raycast ---
	if not is_instance_valid(ground_ray): # Extra safety check
		_is_on_surface = false
		_current_surface_normal = Vector2.UP
		_target_up_direction = Vector2.UP
		if DEBUG: print("ERROR: GroundRay invalid!")
		return # Stop processing if ray is broken

	ground_ray.force_raycast_update()
	var ground_hit = ground_ray.is_colliding()
	var detected_surface_normal = Vector2.UP # Default if airborne
	var detected_on_surface = false

	if DEBUG: print("  Ray Check: GroundRay Hit = %s" % ground_hit) # Print hit status

	if ground_hit:
		detected_surface_normal = ground_ray.get_collision_normal()
		var collided_object = ground_ray.get_collider()
		if DEBUG: print("    Ray Hit Details: Normal=%s, Collider=%s (%s)" % [detected_surface_normal.round(), collided_object.name if is_instance_valid(collided_object) else "N/A", str(collided_object)])

		# Check if the normal is valid for sticking
		var dot_with_inverse_up = detected_surface_normal.dot(-enemy.up_direction)
		var angle_limit_rad = deg_to_rad(85.0) # Max angle allowed
		var angle_limit_cos = cos(angle_limit_rad)
		if DEBUG: print("    Surface Angle Check: Normal.dot(-EnemyUp) = %.3f (Limit Cos = %.3f)" % [dot_with_inverse_up, angle_limit_cos])

		if dot_with_inverse_up > angle_limit_cos: # Allow up to 85 degree slopes
			detected_on_surface = true
			if DEBUG: print("    Surface Angle OK.")
		else:
			if DEBUG: print("    GroundRay hit steep slope (Normal: %s vs -EnemyUp: %s), treating as airborne." % [detected_surface_normal.round(), (-enemy.up_direction).round()])
			detected_surface_normal = Vector2.UP # Reset normal if slope is too steep
			detected_on_surface = false
	else:
		detected_on_surface = false
		detected_surface_normal = Vector2.UP # Ensure world UP if airborne

	# Update internal state based on detection
	_is_on_surface = detected_on_surface
	_current_surface_normal = detected_surface_normal
	_target_up_direction = -_current_surface_normal # Enemy's UP is opposite the surface normal

	# --- Debug Prints (State after detection) ---
	if DEBUG and delta > 0:
		print("  State After Detect: OnSurf=%s SurfN=%s TargetUp=%s" % [_is_on_surface, _current_surface_normal.round(), _target_up_direction.round()])

	# --- 2. Rotation towards Target Up Direction ---
	# Smoothly rotate the enemy node itself towards the target orientation
	var current_angle = enemy.up_direction.angle()
	var target_angle = _target_up_direction.angle()
	var angle_diff = angle_difference(current_angle, target_angle)

	# Clamp rotation speed
	var rotation_delta = sign(angle_diff) * min(abs(angle_diff), rotation_speed * delta)
	var new_angle = current_angle + rotation_delta

	# Apply the new rotation directly to the enemy
	enemy.rotation = new_angle # Rotate the parent CharacterBody2D
	# Update the enemy's up_direction for physics based on the smoothed rotation
	enemy.up_direction = Vector2.UP.rotated(enemy.rotation) # More reliable than rotating the vector itself repeatedly

	# if DEBUG: print("  Rotation: Current=%.1f Target=%.1f Diff=%.1f Delta=%.1f New=%.1f -> EnemyUp=%s" % [rad_to_deg(current_angle), rad_to_deg(target_angle), rad_to_deg(angle_diff), rad_to_deg(rotation_delta), rad_to_deg(new_angle), enemy.up_direction.round()])

	# --- 3. Calculate Velocity ---
	var desired_velocity = Vector2.ZERO

	if _is_on_surface:
		# --- On Surface ---
		# Calculate tangent based on the *current* smoothed enemy up_direction
		var tangent = Vector2(-enemy.up_direction.y, enemy.up_direction.x)
		# For Phase 1, assume movement is always "right" relative to the enemy's orientation
		# (We can add _movement_direction logic back later)
		tangent *= 1.0 # Or -1.0 to go left relative to orientation

		var tangent_velocity = tangent.normalized() * surface_speed

		var sticking_force = Vector2.ZERO
		if use_sticking_force:
			# Stick towards the detected surface normal (points into surface)
			sticking_force = -_current_surface_normal * constant_sticking_magnitude
			# if DEBUG: print("    Sticking Force: %s (Dir: %s, Mag: %.1f)" % [sticking_force.round(), (-_current_surface_normal).round(), constant_sticking_magnitude])

		desired_velocity = tangent_velocity + sticking_force
		if DEBUG: print("  On Surface Vel: Tangent=%s Stick=%s -> Final=%s" % [tangent_velocity.round(), sticking_force.round(), desired_velocity.round()])

		# Signal BaseEnemy to use our velocity
		if "_velocity_set_by_component" in enemy: enemy._velocity_set_by_component = true

	else:
		# --- Airborne ---
		if DEBUG: print("  Airborne - Applying Gravity")
		# Let BaseEnemy handle gravity OR apply it here if BaseEnemy's gravity is disabled
		# Assuming BaseEnemy handles gravity if component doesn't set velocity:
		if "_velocity_set_by_component" in enemy: enemy._velocity_set_by_component = false
		# OR, if we want this component to ALWAYS control velocity:
		# enemy.velocity.y += _gravity * delta
		# if "_velocity_set_by_component" in enemy: enemy._velocity_set_by_component = true

	# --- 4. Set Final Velocity (or let BaseEnemy do it) ---
	# If component controls velocity, set it now.
	if "_velocity_set_by_component" in enemy and enemy._velocity_set_by_component:
		enemy.velocity = desired_velocity
	# If component doesn't control velocity (e.g., airborne), BaseEnemy calculates it using its own logic + gravity.

	# NOTE: BaseEnemy calls move_and_slide() AFTER this process function finishes.

	# if DEBUG: print("--- [%s] Frame End ---" % name)


# Helper to find the smallest angle difference (-PI to PI)
func angle_difference(angle1: float, angle2: float) -> float:
	var diff = angle2 - angle1
	while diff <= -PI: diff += TAU
	while diff > PI: diff -= TAU
	return diff
