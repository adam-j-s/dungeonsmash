# basic_fodder_enemy.gd - Simplified after BaseEnemy weapon system integration
extends BaseEnemy
class_name BasicFodderEnemy

# --- Basic Fodder Behavior Parameters ---
@export var retreat_chance: float = 0.4           # Chance to back off after attacking
@export var jump_chance: float = 0.2              # Chance to jump when approaching player
@export var detection_range: float = 500.0		  # How far enemy will scan for player

# --- Animation and State ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var telegraph_effect = $TelegraphEffect  # Visual indicator for attack

# Behavior state tracking
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
var is_retreating: bool = false
var retreat_timer: float = 0.0

# Animation states (expanded from BasicEnemy)
enum AnimationState { IDLE, RUN, TELEGRAPH, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

func _ready():
	# Call parent _ready first (it will set up the weapon system)
	super._ready()
	
	# Initialize telegraph effect (if available)
	if telegraph_effect:
		telegraph_effect.visible = false
	
	# We don't need to create or initialize the weapon system anymore,
	# since that's handled by the BaseEnemy class
	
	# Connect to the weapon system's cooldown signal
	if weapon_system and not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
		weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to fodder enemy
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers
	
	# Make the fodder enemy very aggressive
	aggression_level = 0.9
	direct_chase = true
	chase_speed_multiplier = 1.8
	chase_jump_chance = 3.0
	chase_jump_force = 350.0
	
	# Adjust attack parameters for close combat
	preferred_attack_distance = 40.0
	preferred_distance_tolerance = 30.0
	
	# Reduce the tendency to reposition after attacking
	reposition_chance = 0.1
	
	# Ensure it keeps moving during combat
	combat_movement_speed_multiplier = 0.9

func _physics_process(delta):
	# Call parent physics process
	super._physics_process(delta)
	
	# Update telegraph timer
	if is_telegraphing:
		telegraph_timer += delta
		if telegraph_timer >= attack_telegraph_time:
			is_telegraphing = false
			telegraph_timer = 0
			perform_attack()
	
	# Update retreat timer
	if is_retreating:
		retreat_timer -= delta
		if retreat_timer <= 0:
			is_retreating = false
			# Return to chasing
			if is_instance_valid(_target_node):
				change_ai_state(AIState.CHASING)
	
	# Update animations based on state and movement
	update_animations_from_state(delta)

# --- Weapon System Callbacks ---

func _on_weapon_cooldown_complete():
	# Weapon is ready to use again
	can_attack = true

# --- Handle telegraphing attack ---
func start_telegraph_attack():
	# Only start telegraph if weapon is ready
	if not weapon_system or not can_attack or not weapon_system.can_attack():
		return
	
	is_telegraphing = true
	telegraph_timer = 0
	
	# Show telegraph effect
	if telegraph_effect:
		telegraph_effect.visible = true
	
	# Update animation
	update_animation(AnimationState.TELEGRAPH)

func perform_attack(attack_type: String = "melee") -> bool:
	# Hide telegraph
	if telegraph_effect:
		telegraph_effect.visible = false
	
	# Update animation
	update_animation(AnimationState.ATTACK)
	
	# Make sure we're positioned optimally for attack
	if is_instance_valid(_target_node):
		# Force small position adjustment toward target for close-range attack
		var attack_vector = (_target_node.global_position - global_position).normalized()
		global_position += attack_vector * 5  # Small adjustment to ensure attack connects
	
	# Use weapon system to attack
	var attack_success = false
	if weapon_system:
		attack_success = weapon_system.perform_attack()
		
		# Set attack cooldown
		if attack_success:
			can_attack = false
	
	# Only consider retreating if we're not highly aggressive
	if aggression_level < 0.7 and randf() < retreat_chance:
		start_retreat()
	else:
		# For aggressive enemies, set a timer to transition back to chasing
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.1
		add_child(timer)
		timer.timeout.connect(func():
			if is_instance_valid(_target_node) and current_ai_state == AIState.ATTACKING:
				change_ai_state(AIState.CHASING)
			timer.queue_free()
		)
		timer.start()
	
	return attack_success

func start_retreat():
	is_retreating = true
	retreat_timer = 0.5  # Retreat for half a second
	
	# Move away from target
	if is_instance_valid(_target_node):
		var direction = (global_position - _target_node.global_position).normalized()
		target_velocity = direction * move_speed * 0.7

# --- Override State Processing Functions ---

func process_chasing_state(delta):
	# Basic implementation (call parent method)
	super.process_chasing_state(delta)
	
	# Occasionally jump when approaching target
	if is_on_floor() and randf() < jump_chance * delta * 2:
		velocity.y = -300  # Simple jump
	
	# If close enough, start telegraph attack
	if is_instance_valid(_target_node) and can_attack:
		var distance = global_position.distance_to(_target_node.global_position)
		if distance < preferred_attack_distance and not is_telegraphing:
			start_telegraph_attack()

func process_attacking_state(delta):
	# If we're telegraphing, let the telegraph logic handle it
	if is_telegraphing:
		return
		
	# If retreating, let retreat logic handle it
	if is_retreating:
		return
	
	# Otherwise, use parent implementation
	super.process_attacking_state(delta)

# --- Animation handling ---
func update_animations_from_state(delta):
	# Telegraph and retreat have priority
	if is_telegraphing:
		update_animation(AnimationState.TELEGRAPH)
		return
		
	if is_retreating:
		update_animation(AnimationState.RUN)
		# Ensure sprite faces correct direction during retreat
		if is_instance_valid(_target_node) and animated_sprite:
			animated_sprite.flip_h = global_position.x > _target_node.global_position.x
		return
	
	# Otherwise handle normal states
	match current_ai_state:
		AIState.IDLE:
			update_animation(AnimationState.IDLE)
		AIState.CHASING:
			update_animation(AnimationState.RUN)
			if velocity.x != 0 and animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
		AIState.ATTACKING:
			# Animation handled by attack logic
			pass
		AIState.STUNNED:
			update_animation(AnimationState.HURT)

func update_animation(new_state):
	if current_animation_state == new_state:
		return
		
	current_animation_state = new_state
	
	if animated_sprite:
		match new_state:
			AnimationState.IDLE:
				animated_sprite.play("idle")
			AnimationState.RUN:
				animated_sprite.play("run")
			AnimationState.TELEGRAPH:
				animated_sprite.play("telegraph")  # Attack wind-up animation
			AnimationState.ATTACK:
				animated_sprite.play("attack")
			AnimationState.HURT:
				animated_sprite.play("hurt")
			AnimationState.DEATH:
				animated_sprite.play("death")

# --- Override for death effects ---
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
