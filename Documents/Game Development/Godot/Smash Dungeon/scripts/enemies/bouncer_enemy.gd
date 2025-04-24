# bouncer_enemy.gd - Fully integrated with enhanced BaseEnemy system
extends BaseEnemy
class_name BouncerEnemy

# --- Bouncer-specific exports ---
@export var direction: float = 1.0  # 1 = right, -1 = left
@export var direction_change_cooldown: float = 0.5
@export var stuck_threshold: float = 1.0  # Distance under which we consider the bouncer stuck
@export var bump_damage: int = 5
@export var jump_force: float = 200.0
@export var collision_damage_cooldown: float = 0.5

# --- Animation states ---
enum AnimationState { IDLE, MOVE, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# --- Node references ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check_right = $WallCheckRight
@onready var wall_check_left = $WallCheckLeft
@onready var ground_check = $GroundCheck

# --- Internal state ---
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var direction_change_timer: float = 0.0
var collision_damage_timer: float = 0.0
var is_jumping: bool = false

func _ready():
	# Ensure enemy doesn't try to use a weapon
	weapon_id = ""
	
	# Call parent _ready
	super._ready()
	
	# Initialize position tracking
	last_position = global_position
	
	# Start with idle/move animation
	update_animation(AnimationState.MOVE)

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to bouncer
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers

# --- Override physics process ---
func _physics_process(delta):
	# Call the parent physics process first
	super._physics_process(delta)
	
	# Update timers
	direction_change_timer -= delta
	collision_damage_timer -= delta
	
	# Check if we're on floor to reset jumping
	if is_on_floor():
		is_jumping = false
	
	# Apply custom movement logic
	apply_bouncer_movement(delta)
	
	# Check if we're stuck
	var distance_moved = global_position.distance_to(last_position)
	if distance_moved < stuck_threshold and is_on_floor():
		stuck_timer += delta
		if stuck_timer > 0.5:  # If stuck for half a second
			change_direction()
			stuck_timer = 0
	else:
		stuck_timer = 0
	
	# Update last position
	last_position = global_position
	
	# Update animation
	update_animations_from_state(delta)
	
	# Wall collision checks
	check_wall_collisions()

# --- Custom Bouncer Movement ---
func apply_bouncer_movement(delta):
	# Apply gravity
	if not is_on_floor() and use_gravity:
		velocity.y += gravity * delta
	
	# Handle movement based on AI state
	match current_ai_state:
		AIState.IDLE, AIState.CHASING:
			# Move horizontally - using current direction
			velocity.x = move_speed * direction
		AIState.ATTACKING:
			# Slow down slightly during attack but keep moving
			velocity.x = move_speed * direction * 0.7
		AIState.STUNNED:
			# Maintain some momentum but don't add new force
			velocity.x *= 0.9
	
	# Perform the movement
	var collision = move_and_slide()
	
	# Check if we collided with something
	if collision:
		handle_collision()

# --- Direction & Collision Handling ---
func change_direction():
	if direction_change_timer <= 0:
		direction *= -1
		direction_change_timer = direction_change_cooldown
		
		# Flip sprite
		if animated_sprite:
			animated_sprite.flip_h = (direction < 0)

func check_wall_collisions():
	# Update raycasts
	if wall_check_right and wall_check_left:
		wall_check_right.force_raycast_update()
		wall_check_left.force_raycast_update()
		
		# Change direction if we hit a wall
		if (direction > 0 and wall_check_right.is_colliding()) or \
		   (direction < 0 and wall_check_left.is_colliding()):
			change_direction()

func handle_collision():
	# Check for player collisions
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If we hit a player and damage cooldown is expired
		if collider and collider.is_in_group("players") and collision_damage_timer <= 0:
			if collider.has_method("take_damage"):
				var dir = (collider.global_position - global_position).normalized()
				collider.take_damage(bump_damage, dir, 150)
				
				# Set cooldown
				collision_damage_timer = collision_damage_cooldown
				
				# Perform an attack animation
				update_animation(AnimationState.ATTACK)
				
				# Signal that attack was performed
				emit_signal("attack_performed", "bump", bump_damage)

# --- Animation Handling ---
func update_animations_from_state(_delta):
	match current_ai_state:
		AIState.IDLE, AIState.CHASING:
			update_animation(AnimationState.MOVE)
		AIState.ATTACKING:
			update_animation(AnimationState.ATTACK)
		AIState.STUNNED:
			update_animation(AnimationState.HURT)
	
	# Ensure sprite is facing correct direction
	if animated_sprite and direction_change_timer <= 0:
		animated_sprite.flip_h = (direction < 0)

func update_animation(new_state):
	if current_animation_state == new_state:
		return
	
	current_animation_state = new_state
	
	if animated_sprite:
		match new_state:
			AnimationState.IDLE:
				animated_sprite.play("idle")
			AnimationState.MOVE:
				animated_sprite.play("move")
			AnimationState.ATTACK:
				animated_sprite.play("attack")
			AnimationState.HURT:
				animated_sprite.play("hurt")
			AnimationState.DEATH:
				animated_sprite.play("death")

# --- Override State Processing Functions ---

func process_idle_state(delta):
	# Bouncers always move, so in idle they just continue
	# bouncing in current direction
	target_velocity.x = move_speed * direction
	
	# Find target
	find_target()

func process_chasing_state(delta):
	# If we've lost our target, go back to idle
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Get target position and direction
	var target_pos = _target_node.global_position
	var to_target = target_pos - global_position
	
	# Change direction to face target
	if to_target.x > 10 and direction < 0:
		change_direction()
	elif to_target.x < -10 and direction > 0:
		change_direction()
	
	# Move in the decided direction
	target_velocity.x = move_speed * direction
	
	# If target is above us, consider jumping
	if to_target.y < -40 and is_on_floor() and not is_jumping:
		jump()
	
	# Check distance for attack
	var distance = global_position.distance_to(target_pos)
	if distance < preferred_attack_distance:
		change_ai_state(AIState.ATTACKING)

func process_attacking_state(delta):
	# Bouncer's attack is just to keep moving and cause damage on collision
	target_velocity.x = move_speed * direction * 0.7
	
	# Check if target still exists
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Get distance to target
	var distance = global_position.distance_to(_target_node.global_position)
	
	# If target is too far, go back to chasing
	if distance > preferred_attack_distance * 1.5:
		change_ai_state(AIState.CHASING)

func process_stunned_state(delta):
	# When stunned, slow down horizontal movement
	target_velocity.x = velocity.x * 0.9
	
	# Recover from stun after a while
	if state_timer >= 0.7:
		change_ai_state(AIState.IDLE)

# --- Jumping ---
func jump():
	if not is_on_floor():
		return
	
	is_jumping = true
	velocity.y = -jump_force
	
	# Play jump animation/sound if available

# --- BaseEnemy Overrides ---

func take_damage(amount, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Call parent method
	super.take_damage(amount, hit_direction, knockback_strength)
	
	# Update animation
	update_animation(AnimationState.HURT)
	
	# Apply knockback
	if hit_direction != Vector2.ZERO and knockback_strength > 0:
		velocity = hit_direction * knockback_strength
	
	# Consider changing direction when hit
	if randf() > 0.5:
		change_direction()
	
	# Consider getting stunned
	if amount > 10 or randf() < 0.3:
		change_ai_state(AIState.STUNNED)

func play_death_effects():
	# Update animation
	update_animation(AnimationState.DEATH)
	
	# Call parent method
	super.play_death_effects()
	
	# Wait for death animation if available
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	
	# Queue free after fade out
	await tween.finished
	queue_free()

# --- Helper Functions ---

func perform_attack(String):
	# Bouncer attacks by collision, so just ensure
	# we're in attack state and moving
	return is_instance_valid(_target_node)
