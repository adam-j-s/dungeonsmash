# floater_enemy.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name FloaterEnemy

# Floater-specific exports
@export var hover_height: float = 1.5
@export var hover_speed: float = 2.0
@export var orbit_factor: float = 0.5

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var shadow = $Shadow
@onready var glow_effect = $GlowEffect

# Animation states
enum AnimationState { IDLE, FLOAT, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# Hover effect tracking
var hover_time: float = 0.0
var base_y_position: float = 0.0
var hover_offset: float = 0.0

func _ready():
	# Call parent _ready
	super._ready()
	
	# Set floating motion mode
	motion_mode = MOTION_MODE_FLOATING
	
	# Store initial y position for hover effect
	base_y_position = global_position.y
	
	# Start with idle animation
	update_animation(AnimationState.IDLE)
	
	# Configure shadow
	if shadow:
		shadow.modulate.a = 0.3

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to floater
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers
	
	# Start glow effect if present
	if glow_effect:
		glow_effect.emitting = true

# Override physics process to handle floating movement
func _physics_process(delta):
	# Call the parent physics process first
	super._physics_process(delta)
	
	# Update hover effect
	hover_time += delta * hover_speed
	hover_offset = sin(hover_time) * hover_height
	
	# Apply hover offset
	if not _is_defeated:
		global_position.y = base_y_position + hover_offset
	
	# Update base_y_position when moving
	if abs(velocity.y) > 0.1:
		base_y_position = global_position.y - hover_offset
	
	# Update animations based on state and movement
	update_animations_from_state(delta)

# Handle specific animation updates based on AI state and movement
func update_animations_from_state(_delta):
	match current_ai_state:
		AIState.IDLE:
			update_animation(AnimationState.IDLE)
		AIState.CHASING, AIState.REPOSITIONING, AIState.FLEEING:
			update_animation(AnimationState.FLOAT)
			# Update sprite direction based on horizontal movement
			if velocity.x != 0:
				animated_sprite.flip_h = velocity.x < 0
		AIState.ATTACKING:
			update_animation(AnimationState.ATTACK)
			# Keep facing target during attack
			if is_instance_valid(_target_node):
				animated_sprite.flip_h = global_position.x > _target_node.global_position.x
		AIState.STUNNED:
			update_animation(AnimationState.HURT)

# Update the animation if needed
func update_animation(new_state):
	if current_animation_state == new_state:
		return
		
	current_animation_state = new_state
	
	match new_state:
		AnimationState.IDLE:
			animated_sprite.play("idle")
		AnimationState.FLOAT:
			animated_sprite.play("float")
		AnimationState.ATTACK:
			animated_sprite.play("attack")
		AnimationState.HURT:
			animated_sprite.play("hurt")
		AnimationState.DEATH:
			animated_sprite.play("death")

# Override process_chasing_state for floater-specific movement
func process_chasing_state(delta):
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
		
	# Get target position and calculate distance
	var target_pos = _target_node.global_position
	var vector_to_target = target_pos - global_position
	var distance_sq = vector_to_target.length_squared()
	var distance = sqrt(distance_sq)
	
	# Calculate preferred distance difference
	var preferred_distance_diff = distance - preferred_attack_distance
	var move_strength = 1.0
	
	# If we're close to the preferred distance, reduce movement speed
	if abs(preferred_distance_diff) < preferred_distance_tolerance:
		move_strength = abs(preferred_distance_diff) / preferred_distance_tolerance
	
	# Direction to target
	var direction_to_target = vector_to_target.normalized()
	
	# Floater-specific movement: more emphasis on orbital movement
	if abs(preferred_distance_diff) > preferred_distance_tolerance:
		if preferred_distance_diff > 0:
			# Too far, move toward player
			target_velocity = direction_to_target * move_speed
		else:
			# Too close, back away from player
			target_velocity = -direction_to_target * move_speed * 0.8
	else:
		# At good distance, strong orbital movement
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x)
		if randf() > 0.5: # Randomly reverse direction
			orbit_dir = -orbit_dir
			
		# Mix orbital and approach/retreat for natural movement
		target_velocity = (orbit_dir * orbit_factor + direction_to_target * (preferred_distance_diff / preferred_distance_tolerance) * 0.2) * move_speed * move_strength
	
	# Check if within attack range
	if distance <= preferred_attack_distance + preferred_distance_tolerance and check_line_of_sight():
		change_ai_state(AIState.ATTACKING)

# Override process_attacking_state for floater-specific behavior
func process_attacking_state(delta):
	# Call parent for basic behavior
	super.process_attacking_state(delta)
	
	# Floaters drift slightly while attacking
	if is_instance_valid(_target_node):
		var direction_to_target = (_target_node.global_position - global_position).normalized()
		
		# Add slight orbital movement while attacking
		var orbit_dir = Vector2(-direction_to_target.y, direction_to_target.x)
		if randf() > 0.5:
			orbit_dir = -orbit_dir
			
		target_velocity = orbit_dir * move_speed * combat_movement_speed_multiplier * 0.3

# Override execute_ranged_attack for floater projectiles
func execute_ranged_attack(attack_data: Dictionary):
	# Use parent implementation
	super.execute_ranged_attack(attack_data)
	
	# Add visual effects
	if glow_effect:
		glow_effect.restart()
		glow_effect.emitting = true

# Override death handler to play death animation
func play_death_effects():
	# Update animation
	update_animation(AnimationState.DEATH)
	
	# Call parent method to handle signals and cleanup
	super.play_death_effects()
	
	# Stop glow effect
	if glow_effect:
		glow_effect.emitting = false
	
	# Hide shadow
	if shadow:
		shadow.visible = false
	
	# Wait for death animation to finish
	await animated_sprite.animation_finished
	
	# Disable collision
	disable_collision()
	
	# Fall to ground
	var fall_tween = create_tween()
	fall_tween.tween_property(self, "global_position:y", base_y_position + 10, 0.5)
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.7)
	
	# Queue free after fade out
	await fade_tween.finished
	queue_free()
