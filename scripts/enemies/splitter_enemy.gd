# splitter_enemy.gd - Adapted to use enhanced BaseEnemy system
extends BaseEnemy
class_name SplitterEnemy

# Splitter-specific exports
@export var split_health_threshold: int = 20
@export var split_count: int = 2
@export var child_scale: float = 0.65
@export var child_health_percentage: float = 0.5
@export var can_split: bool = true
@export var split_scene: PackedScene
@export var is_child: bool = false

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var split_effect = $SplitEffect

# Animation states
enum AnimationState { IDLE, RUN, ATTACK, HURT, DEATH, SPLIT }
var current_animation_state = AnimationState.IDLE

# Split tracking
var has_split: bool = false

func _ready():
	# Call parent _ready
	super._ready()
	
	# Start with idle animation
	update_animation(AnimationState.IDLE)
	
	# Configure child properties if this is a child splitter
	if is_child:
		scale = Vector2.ONE * child_scale
		can_split = false

func initialize():
	# Call parent initialization
	super.initialize()
	
	# Additional initialization specific to splitter
	add_to_group("enemies")
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and player layers

# Override physics process
func _physics_process(delta):
	# Call the parent physics process first
	super._physics_process(delta)
	
	# Update animations based on state and movement
	update_animations_from_state(delta)
	
	# Check if we should split
	if can_split and not has_split and current_health <= split_health_threshold and not _is_defeated:
		perform_split()

# Handle specific animation updates based on AI state and movement
func update_animations_from_state(_delta):
	match current_ai_state:
		AIState.IDLE:
			update_animation(AnimationState.IDLE)
		AIState.CHASING, AIState.REPOSITIONING, AIState.FLEEING:
			update_animation(AnimationState.RUN)
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
		AnimationState.RUN:
			animated_sprite.play("run")
		AnimationState.ATTACK:
			animated_sprite.play("attack")
		AnimationState.HURT:
			animated_sprite.play("hurt")
		AnimationState.DEATH:
			animated_sprite.play("death")
		AnimationState.SPLIT:
			animated_sprite.play("split")

# Handle the split process
func perform_split():
	if has_split or not can_split:
		return
		
	has_split = true
	
	# Play split animation and effect
	update_animation(AnimationState.SPLIT)
	if split_effect:
		split_effect.emitting = true
	
	# Prevent taking additional damage during split
	_is_defeated = true
	
	# Wait for animation to finish
	await animated_sprite.animation_finished
	
	# Create child splitters
	spawn_children()
	
	# Remove this splitter
	queue_free()

# Spawn child splitters
func spawn_children():
	if not split_scene:
		if debug_mode:
			print("ERROR: split_scene not set for splitter enemy")
		return
		
	for i in range(split_count):
		var child = split_scene.instantiate()
		
		# Set child properties
		child.is_child = true
		child.max_health = int(max_health * child_health_percentage)
		child.current_health = child.max_health
		
		# Randomize position slightly
		var offset = Vector2(randf_range(-20, 20), randf_range(-10, 10))
		child.global_position = global_position + offset
		
		# Set target if we have one
		if is_instance_valid(_target_node):
			child.set_target(_target_node)
		
		# Add to the scene
		get_parent().add_child(child)
		
		if debug_mode:
			print("Spawned child splitter at ", child.global_position)

# Override execute_melee_attack for splitter-specific attacks
func execute_melee_attack(attack_data: Dictionary):
	# Only proceed if we have a valid target
	if not is_instance_valid(_target_node):
		return
		
	# Get attack attributes
	var damage = attack_data.get("damage", 10)
	var knockback = attack_data.get("knockback", 100.0)
	
	# Adjust damage for child splitters
	if is_child:
		damage = int(damage * 0.7)
		knockback *= 0.7
	
	# Calculate direction to target
	var direction = (_target_node.global_position - global_position).normalized()
	
	# Apply damage if target has take_damage method
	if _target_node.has_method("take_damage"):
		_target_node.take_damage(damage, direction, knockback)
	
	# Play attack animation
	update_animation(AnimationState.ATTACK)
	
	# Apply a little self-knockback for dynamics
	velocity -= direction * 50

# Override take_damage to handle split threshold
func take_damage(amount: int, hit_direction = Vector2.ZERO, knockback_strength = 0):
	# Calculate new health after damage
	var new_health = current_health - amount
	
	# Check if this damage would put us below split threshold
	if can_split and not has_split and current_health > split_health_threshold and new_health <= split_health_threshold:
		# Only take enough damage to reach threshold
		super.take_damage(current_health - split_health_threshold, hit_direction, knockback_strength)
		
		# Trigger split in the next frame
		call_deferred("perform_split")
	else:
		# Normal damage handling
		super.take_damage(amount, hit_direction, knockback_strength)

# Override death handler
func play_death_effects():
	# If we're at the split threshold and can split, don't die yet
	if can_split and not has_split and current_health <= split_health_threshold:
		call_deferred("perform_split")
		return
	
	# Normal death for non-splitting or already split enemies
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
