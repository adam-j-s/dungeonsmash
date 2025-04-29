# res://state_machines/bouncer_enemy_sm.gd
extends BaseEnemySM # IMPORTANT: Inherit from BaseEnemySM
class_name BouncerEnemySM

# --- Node References (Copied from old script) ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Type hint
@onready var wall_check_right: RayCast2D = $WallCheckRight       # Type hint
@onready var wall_check_left: RayCast2D = $WallCheckLeft        # Type hint
# @onready var ground_check = $GroundCheck # is_on_floor() is usually sufficient
# @onready var bump_sound = $BumpSound # Add if you have one

# --- Animation Enum (Copied from old script) ---
enum AnimationState { IDLE, MOVE, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# --- Bouncer State Variables (Migrated from old script) ---
var direction: float = 1.0  # 1 = right, -1 = left
var direction_change_timer: float = 0.0
var collision_damage_timer: float = 0.0
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
# var is_jumping: bool = false # We can infer this from !is_on_floor()

var _config_collision_damage_cooldown: float = 0.5

# --- Godot Lifecycle ---

func _ready():
	super() # Call parent ready FIRST
	last_position = global_position
	# Ensure sprite matches initial direction
	if is_instance_valid(animated_sprite):
		animated_sprite.flip_h = (direction < 0)
	weapon_id = "" # Explicitly ensure no weapon for bouncer

func _physics_process(delta):
	
	print("BouncerEnemySM _physics_process TICK - ", name)
	# --- 1. Initial Defeated Check ---
	if _is_defeated:
		velocity = Vector2.ZERO
		target_velocity = Vector2.ZERO
		return

	# --- 2. Get Config Values (Read Once Per Frame) ---
	# Start with safe defaults from BaseEnemy or hardcoded fallbacks
	var current_move_speed: float = move_speed
	var current_acceleration: float = acceleration
	var current_damping: float = damping
	var current_use_gravity: bool = use_gravity
	var current_gravity: float = gravity
	var current_motion_mode: int = motion_mode
	var current_use_avoidance: bool = false # Bouncer likely defaults this to false via config

	# Bouncer specific values - Use member variables for defaults/storage if needed outside physics
	# Using local vars and reading each frame is also fine. Using _config_ version for the one needed elsewhere.
	var current_bump_damage: int = 5
	_config_collision_damage_cooldown = 0.5 # Assign default to member variable
	var current_direction_change_cooldown: float = 0.5
	var current_stuck_threshold: float = 1.0

	# Attempt to read override values from the loaded config resource
	var cfg = config as BouncerConfig # Try cast to BouncerConfig first
	if is_instance_valid(cfg):
		# Read standard values from BouncerConfig (it inherits them)
		current_move_speed = cfg.move_speed
		current_acceleration = cfg.acceleration
		current_damping = cfg.damping
		current_use_gravity = cfg.use_gravity
		current_motion_mode = cfg.motion_mode
		current_use_avoidance = cfg.use_avoidance

		# Read bouncer-specific values
		current_bump_damage = cfg.bump_damage
		_config_collision_damage_cooldown = cfg.collision_damage_cooldown # Update member variable
		current_direction_change_cooldown = cfg.direction_change_cooldown
		current_stuck_threshold = cfg.stuck_threshold
	elif is_instance_valid(config): # If config exists but isn't BouncerConfig (shouldn't happen if generator is right)
		 # Read standard values from base EnemyConfig at least
		current_move_speed = config.move_speed
		current_acceleration = config.acceleration
		current_damping = config.damping
		current_use_gravity = config.use_gravity
		current_motion_mode = config.motion_mode
		current_use_avoidance = config.use_avoidance

	# --- 3. Update Timers ---
	if direction_change_timer > 0.0: direction_change_timer -= delta
	if collision_damage_timer > 0.0: collision_damage_timer -= delta

	# --- 4. State Machine Logic Execution ---
	# Let the current state (Idle/Chase/Stunned) run its logic.
	# This might influence direction change or trigger jumps via methods on this script.
	var current_state_name = ""
	if state_machine and state_machine.current_state:
		current_state_name = state_machine.current_state_name
		state_machine.current_state.physics_process(delta)

	# --- 5. Bouncer Specific Movement & Checks ---
	# Only perform movement/checks if not stunned
	if current_state_name != "StunnedState":
		# 5a. Wall Check (triggers direction change internally if needed)
		check_wall_collisions(current_direction_change_cooldown)

		# 5b. Stuck Check
		var dist_moved_this_frame = global_position.distance_to(last_position)
		# Compare distance moved against threshold scaled by time
		if is_on_floor() and dist_moved_this_frame < (current_stuck_threshold * delta):
			stuck_timer += delta
			if stuck_timer > 0.5: # Stuck duration threshold
				if state_machine.debug_mode: print("Bouncer stuck, changing direction.")
				change_direction(current_direction_change_cooldown)
				stuck_timer = 0.0 # Reset timer after changing direction
		else:
			stuck_timer = 0.0 # Reset if moving sufficiently
		last_position = global_position # Update position tracker AFTER checking distance

		# 5c. Set Horizontal Target Velocity based on current direction
		target_velocity.x = direction * current_move_speed

	else: # If stunned
		# Ensure target velocity is zero while stunned
		target_velocity.x = 0
		# Optional: Apply extra damping or specific stunned behavior if needed
		velocity.x *= pow(0.5, delta * 60.0) # Example: Fast damping

	# Ensure vertical target velocity is zero (unless a state explicitly sets it for jump windup?)
	target_velocity.y = 0

	# --- 6. Apply Base Physics ---
	var avoidance_vector = Vector2.ZERO # Bouncer has use_avoidance = false via config override

	# 6a. Apply Gravity
	if not is_on_floor() and current_motion_mode != MOTION_MODE_FLOATING and current_use_gravity:
		velocity.y += current_gravity * delta

	# 6b. Apply Damping (affects both x and y)
	if delta > 0:
		var damping_factor = clamp(pow(current_damping, delta * 60.0), 0.0, 1.0)
		velocity *= damping_factor

	# 6c. Apply Horizontal Acceleration towards Target
	var max_horizontal_delta = current_acceleration * delta
	velocity.x = move_toward(velocity.x, target_velocity.x + avoidance_vector.x, max_horizontal_delta)
	# Note: Vertical velocity (velocity.y) is handled by gravity/jumps/damping, not move_toward here.

	# --- 7. Final Movement & Collision Damage Check ---
	move_and_slide()

	# 7a. Check for Collision Damage AFTER moving
	if collision_damage_timer <= 0.0: # Only check if cooldown is ready
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision: # Check collision object is valid
				var collider = collision.get_collider()
				# Check if collider is valid and is a player
				if is_instance_valid(collider) and collider.is_in_group("players"):
					if collider.has_method("take_damage"):
						var hit_dir = collision.get_normal() # Normal points OUT of the wall/player hit
						if state_machine.debug_mode: print("Bouncer bumping player!")
						# Apply damage to player, pushing them away from the contact point (-hit_dir)
						collider.take_damage(current_bump_damage, -hit_dir, 150)
						# Use the MEMBER variable here for resetting timer based on config value loaded earlier
						collision_damage_timer = _config_collision_damage_cooldown
						update_animation(AnimationState.ATTACK) # Play bump animation
						emit_signal("attack_performed", "bump", current_bump_damage)
						# Optional: Apply bounce-back force to self using the normal
						# velocity += hit_dir * 100.0 # Example force value
						break # Apply damage only once per frame/collision check

	# --- 8. Animation Update ---
	# Call the function to update animation based on current state/action
	update_animations_from_state(delta)
	
# --- Bouncer Specific Methods  ---

# Use configured cooldown
func change_direction(cooldown_duration: float):
	# --- DEBUG PRINT ---
	if state_machine and state_machine.debug_mode: print("Attempting change_direction. Timer = %.2f" % direction_change_timer)
	# --------------------
	if direction_change_timer <= 0:
		direction *= -1.0
		direction_change_timer = cooldown_duration # Use value from config
		stuck_timer = 0.0 # Reset stuck timer when direction changes
		if is_instance_valid(animated_sprite):
			animated_sprite.flip_h = (direction < 0)
		#if state_machine.debug_mode: print("Bouncer changed direction to: ", direction)
		if state_machine.debug_mode: print(">>> Direction CHANGED to %.1f" % direction)
# Use configured cooldown
func check_wall_collisions(cooldown_duration: float):
	# Ensure raycasts are ready and enabled
	if not is_instance_valid(wall_check_right) or not is_instance_valid(wall_check_left): return
	if not wall_check_right.is_enabled() or not wall_check_left.is_enabled(): return

	var hit_right = wall_check_right.is_colliding()
	var hit_left = wall_check_left.is_colliding()	
		 # --- DEBUG PRINT ---
	if state_machine and state_machine.debug_mode:
		if hit_right or hit_left: print("Wall Check: Dir=%.1f, HitRight=%s, HitLeft=%s" % [direction, hit_right, hit_left])
	#

	# force_raycast_update() might not be needed if rays are children and physics runs
	if direction > 0 and wall_check_right.is_colliding():
		#if state_machine.debug_mode: print("Bouncer hit right wall")
		change_direction(cooldown_duration)
	elif direction < 0 and wall_check_left.is_colliding():
		#if state_machine.debug_mode: print("Bouncer hit left wall")
		change_direction(cooldown_duration)

# Renamed from jump() to attempt_jump() for clarity - called by ChaseState
func attempt_jump():
	var jump_force_val = 300.0 # Default fallback
	var cfg = config as BouncerConfig
	# Jump force is in EnemyConfig, not BouncerConfig unless moved
	if is_instance_valid(config) and "jump_force" in config:
		jump_force_val = config.jump_force

	if is_on_floor(): # Only jump if on floor
		if state_machine and state_machine.debug_mode: print("Bouncer attempting jump with force:", jump_force_val)
		velocity.y = -jump_force_val
		# Optional: play jump sound/animation

# --- Animation Handling (Adapted for FSM) ---
func update_animations_from_state(_delta):
	var current_state_name = ""
	if state_machine and state_machine.current_state:
		current_state_name = state_machine.current_state_name

	var target_anim_state = AnimationState.MOVE # Default: Bouncer is always moving

	match current_state_name:
		"IdleState":
			target_anim_state = AnimationState.MOVE # Always moving
		"ChaseState":
			target_anim_state = AnimationState.MOVE # Always moving unless bumping
		"StunnedState":
			target_anim_state = AnimationState.HURT
		"DeathState":
			target_anim_state = AnimationState.DEATH
		_: # Default case for any other potential states
			target_anim_state = AnimationState.MOVE

	# Override if currently bumping (based on collision timer?)
	# Check if cooldown timer was JUST reset (means bump just happened)
	if collision_damage_timer > (_config_collision_damage_cooldown - _delta * 2.0): # Check if timer is very close to its max value
		target_anim_state = AnimationState.ATTACK

	update_animation(target_anim_state)


func update_animation(new_state):
	if not is_instance_valid(animated_sprite): return

	# Allow MOVE animation to restart, prevent others from restarting mid-play
	if current_animation_state == new_state and animated_sprite.is_playing():
		if new_state != AnimationState.MOVE: # Only prevent non-looping anims
			return

	current_animation_state = new_state
	var anim_name = ""
	match new_state:
		AnimationState.IDLE: anim_name = "idle" # Should use "move"?
		AnimationState.MOVE: anim_name = "move" # Assumes "move" animation exists
		AnimationState.ATTACK: anim_name = "attack" # Assumes "attack" (bump) animation exists
		AnimationState.HURT: anim_name = "hurt"
		AnimationState.DEATH: anim_name = "death"

	var has_anim = false
	if animated_sprite.sprite_frames:
		has_anim = animated_sprite.sprite_frames.has_animation(anim_name)

	if has_anim:
		animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")

	# Ensure sprite faces the correct direction AFTER playing animation
	# But only flip if the animation isn't HURT or DEATH? (Might look weird)
	if new_state != AnimationState.HURT and new_state != AnimationState.DEATH:
		animated_sprite.flip_h = (direction < 0)


# --- BaseEnemy/BaseEnemySM Overrides ---

func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	super(amount, hit_direction, knockback_strength) # Call parent

	# Bouncer specific reaction (if not defeated)
	if not _is_defeated:
		var cd_cooldown = 0.5 # Default fallback
		var cfg = config as BouncerConfig
		if is_instance_valid(cfg): cd_cooldown = cfg.direction_change_cooldown

		if randf() > 0.4: # Chance to change direction when hit
			change_direction(cd_cooldown)

		# Stun state is handled by the message sent from BaseEnemySM to the state machine
		# No need to call change_ai_state here


func play_death_effects():
	# Animation is handled by update_animations_from_state when DeathState is active
	super.play_death_effects() # Handles flags, signals
	# Custom cleanup if needed
	call_deferred("_handle_death_animation_and_cleanup") # Use deferred call

func _handle_death_animation_and_cleanup():
	# Wait for death animation
	if is_instance_valid(animated_sprite) and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		if animated_sprite.animation != "death": animated_sprite.play("death")
		# Use await safely
		if animated_sprite.is_playing():
			await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout # Fallback delay

	# BaseEnemy.play_death_effects likely handles queue_free() now. Check BaseEnemy.
	print("Bouncer death anim finished.")
	# if not get_parent().get_node_or_null(name): # Example check if already freed
	#    queue_free() # Only free if not already handled by base
