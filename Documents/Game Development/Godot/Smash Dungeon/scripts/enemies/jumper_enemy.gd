# jumper_enemy.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name JumperEnemy

# Jumper-specific exports
@export var jump_force: float = 400.0
@export var jump_cooldown: float = 1.0
@export var min_jump_distance: float = 50.0
@export var max_jump_distance: float = 200.0

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var jump_sound = $JumpSound
@onready var land_sound = $LandSound

# Jump state tracking
var can_jump: bool = true
var jump_timer: float = 0.0
var is_jumping: bool = false
var jump_direction: Vector2 = Vector2.ZERO

# Animation states
enum AnimationState { IDLE, RUN, JUMP, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

func _ready():
	# Call parent _ready
	super._ready()
	
	# Start with idle animation
	update_animation(AnimationState.IDLE)

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to jumper
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers

# Override physics process to handle jumping
func _physics_process(delta):
	# Call the parent physics process first
	super._physics_process(delta)
	
	# Update jump cooldown
	if jump_timer > 0:
		jump_timer -= delta
		if jump_timer <= 0:
			can_jump = true
	
	# Check if we've landed from a jump
	if is_jumping and is_on_floor():
		land_from_jump()
	
	# Update animations based on state and movement
	update_animations_from_state(delta)

# Handle specific animation updates based on AI state and movement
func update_animations_from_state(_delta):
	# If jumping, override with jump animation
	if is_jumping:
		update_animation(AnimationState.JUMP)
		return
		
	match current_ai_state:
		AIState.IDLE:
			update_animation(AnimationState.IDLE)
		AIState.CHASING:
			update_animation(AnimationState.RUN)
			# Update sprite direction based on horizontal movement
			if velocity.x != 0:
				animated_sprite.flip_h = velocity.x < 0
		AIState.ATTACKING:
			update_animation(AnimationState.ATTACK)
			# Keep facing target during attack
			if is_instance_valid(_target_node):
				animated_sprite.flip_h = global_position.x > _target_node.global_position.x
		AIState.REPOSITIONING:
			update_animation(AnimationState.RUN)
			# Update sprite direction based on movement
			if velocity.x != 0:
				animated_sprite.flip_h = velocity.x < 0
		AIState.FLEEING:
			update_animation(AnimationState.RUN)
			if velocity.x != 0:
				animated_sprite.flip_h = velocity.x < 0
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
		AnimationState.RUN:
			animated_sprite.play("run")
		AnimationState.JUMP:
			animated_sprite.play("jump")
		AnimationState.ATTACK:
			animated_sprite.play("attack")
		AnimationState.HURT:
			animated_sprite.play("hurt")
		AnimationState.DEATH:
			animated_sprite.play("death")

# Perform a jump in specified direction
func jump(direction: Vector2):
	if not can_jump or not is_on_floor():
		return false
	
	# Set jump state
	is_jumping = true
	can_jump = false
	jump_timer = jump_cooldown
	jump_direction = direction.normalized()
	
	# Apply jump velocity
	velocity = Vector2(jump_direction.x * jump_force, -jump_force * 0.8)
	
	# Play jump sound
	if jump_sound:
		jump_sound.play()
	
	# Update animation
	update_animation(AnimationState.JUMP)
	
	return true

# Handle landing from a jump
func land_from_jump():
	is_jumping = false
	
	# Play land sound
	if land_sound:
		land_sound.play()
	
	# Check if we can attack on landing
	if is_instance_valid(_target_node):
		var distance = global_position.distance_to(_target_node.global_position)
		if distance < preferred_attack_distance:
			change_ai_state(AIState.ATTACKING)
			execute_melee_attack(attack_types["melee"])
	
	# Wait a moment before being able to jump again
	can_jump = false
	jump_timer = jump_cooldown * 0.5

# Override process_chasing_state for jumper-specific movement
func process_chasing_state(delta):
	# If not on floor, use parent behavior to handle falling
	if not is_on_floor():
		super.process_chasing_state(delta)
		return
	
	# Check if target is valid
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Get distance to target
	var distance = global_position.distance_to(_target_node.global_position)
	
	# Check if we can jump to the target
	if can_jump and distance > min_jump_distance and distance < max_jump_distance:
		var direction = (_target_node.global_position - global_position).normalized()
		
		# Check if there's clear line of sight
		if check_line_of_sight():
			# 70% chance to jump toward target
			if randf() < 0.7:
				if jump(direction):
					return  # Skip normal chase behavior
	
	# Use normal chase behavior if we don't jump
	super.process_chasing_state(delta)
	
	# If we get close enough to attack
	if distance < preferred_attack_distance and is_on_floor():
		change_ai_state(AIState.ATTACKING)

# Override process_attacking_state for jumper-specific behavior
func process_attacking_state(delta):
	# Call parent for basic behavior
	super.process_attacking_state(delta)
	
	# Check if target is still valid
	if not is_instance_valid(_target_node):
		change_ai_state(AIState.IDLE)
		return
	
	# Get distance to target
	var distance = global_position.distance_to(_target_node.global_position)
	
	# If target moved out of range, try to jump to it
	if distance > preferred_attack_distance and can_jump and is_on_floor():
		var direction = (_target_node.global_position - global_position).normalized()
		
		# Check if we need to retreat or advance
		if distance < min_jump_distance:
			# Too close, jump away
			direction = -direction
		
		# Try to jump
		if jump(direction):
			return
	
	# If we're close enough and on floor, try to attack
	if distance < preferred_attack_distance and is_on_floor():
		execute_melee_attack(attack_types["melee"])

# Override execute_melee_attack for jumper-specific attacks
func execute_melee_attack(attack_data: Dictionary):
	# Only proceed if we have a valid target
	if not is_instance_valid(_target_node):
		return
		
	# Get attack attributes
	var damage = attack_data.get("damage", 12)
	var knockback = attack_data.get("knockback", 120.0)
	
	# Calculate direction to target
	var direction = (_target_node.global_position - global_position).normalized()
	
	# Apply damage if target has take_damage method
	if _target_node.has_method("take_damage"):
		_target_node.take_damage(damage, direction, knockback)
	
	# Play attack animation
	update_animation(AnimationState.ATTACK)
	
	# Apply self-knockback (small push back)
	velocity = -direction * knockback * 0.3

# Override death handler to play death animation
func play_death_effects():
	# Update animation
	update_animation(AnimationState.DEATH)
	
	# Call parent method to handle signals and cleanup
	super.play_death_effects()
	
	# Wait for death animation to finish
	await animated_sprite.animation_finished
	
	# Disable collision
	disable_collision()
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	
	# Queue free after fade out
	await tween.finished
	queue_free()
