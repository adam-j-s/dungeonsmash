# fodder_enemy_sm.gd
extends BaseEnemySM
class_name FodderEnemySM

# --- Basic Fodder Behavior Parameters ---
@export var retreat_chance: float = 0.4
@export var jump_chance: float = 0.2
@export var detection_range: float = 500.0

# --- Animation and State ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var telegraph_effect = $TelegraphEffect

# Animation states
enum AnimationState { IDLE, RUN, TELEGRAPH, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# Debug constant
const DEBUG = true

func _ready():
	# Call parent _ready first
	super()

	# Ensure telegraph effect is properly set up
	if telegraph_effect:
		telegraph_effect.visible = false
		telegraph_effect.size = Vector2(16, 16)  # Set appropriate size
		telegraph_effect.position = Vector2(-8, -8)  # Center it
		telegraph_effect.color = Color(1, 0, 0, 0.3)  # Semi-transparent red
		
	# Debug weapon system state
	print("Weapon System Debug on _ready:")
	print("- Initial weapon ID: " + (weapon_id if weapon_id else "NONE"))
	
	# Add to proper groups
	if not is_in_group("enemies"):
		add_to_group("enemies")
		
	# Update collision layers/masks
	collision_layer = 8  # Enemy layer
	collision_mask = 1 | 2  # World and player layers
	
	# Make the fodder enemy very aggressive
	aggression_level = 0.9
	direct_chase = true
	chase_speed_multiplier = 1.8
	
	# Force weapon initialization
	reinitialize_weapon()
		
	# Start the animated sprite playing
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("default")

func initialize():
	# Call parent initialization
	super()
	
	# Additional initialization specific to fodder enemy
	add_to_group("enemies")
	collision_layer = 8  # Enemy layer
	collision_mask = 1 | 2  # World and player layers
	
	# Make the fodder enemy very aggressive
	aggression_level = 0.9
	direct_chase = true
	chase_speed_multiplier = 1.8
	chase_jump_chance = 0.1
	chase_jump_force = 350.0
	
	# Adjust attack parameters for close combat
	preferred_attack_distance = 40.0
	preferred_distance_tolerance = 30.0
	
	# Reduce the tendency to reposition after attacking
	reposition_chance = 0.1
	
	# Ensure it keeps moving during combat
	combat_movement_speed_multiplier = 0.9
	
	# Hide telegraph effect initially
	if telegraph_effect:
		telegraph_effect.visible = false

func reinitialize_weapon():
	if DEBUG:
		print("Reinitializing weapon with ID: " + weapon_id)
		
	if weapon_system:
		# Make sure weapon is properly initialized
		weapon_system.initialize(self, weapon_id)
		
		# Add signal connection if not already connected
		if not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
			weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)
			print("Connected to weapon cooldown signal")
			
		# Force weapon to be ready on initialization
		can_attack = true
			
		if DEBUG:
			print("Weapon initialization complete")
			print("Weapon can attack: " + str(weapon_system.can_attack()))
			
# Handle weapon cooldown completion
func _on_weapon_cooldown_complete():
	if DEBUG:
		print("Weapon cooldown completed, updating enemy state")
	
	# Update our state
	can_attack = true
	
	# Make sure the weapon is also marked as ready
	if weapon_system and weapon_system.weapon:
		weapon_system.weapon.can_attack = true
		
		if DEBUG:
			print("Synchronized states - Enemy can attack: " + str(can_attack) + 
				  ", Weapon can attack: " + str(weapon_system.weapon.can_attack))
	
# Force reset weapon cooldown (for debugging)
func reset_weapon_cooldown():
	if DEBUG:
		print("Attempting to reset weapon cooldown")
	
	can_attack = true
	
	if weapon_system:
		if weapon_system.has_signal("cooldown_complete"):
			weapon_system.cooldown_complete.emit()
			print("Weapon cooldown signal emitted")
	
# --- Animation handling ---
func update_animations_from_state(delta):
	# Update based on state machine's current state
	if state_machine:
		var current_state = state_machine.current_state_name
		
		match current_state:
			"IdleState":
				update_animation(AnimationState.IDLE)
			"ChaseState":
				update_animation(AnimationState.RUN)
				if velocity.x != 0 and animated_sprite:
					animated_sprite.flip_h = velocity.x < 0
			"AttackState":
				# Check if telegraph effect is visible - if so, telegraph animation
				if telegraph_effect and telegraph_effect.visible:
					update_animation(AnimationState.TELEGRAPH)
				else:
					update_animation(AnimationState.ATTACK)
			"StunnedState":
				update_animation(AnimationState.HURT)
			"DeathState":
				update_animation(AnimationState.DEATH)

func update_animation(new_state):
	if current_animation_state == new_state:
		return
		
	current_animation_state = new_state
	
	if animated_sprite:
		match new_state:
			AnimationState.IDLE:
				if animated_sprite.sprite_frames.has_animation("idle"):
					animated_sprite.play("idle")
				else:
					animated_sprite.play("default")
			AnimationState.RUN:
				if animated_sprite.sprite_frames.has_animation("run"):
					animated_sprite.play("run")
				else:
					animated_sprite.play("default")
			AnimationState.TELEGRAPH:
				if animated_sprite.sprite_frames.has_animation("telegraph"):
					animated_sprite.play("telegraph")
				else:
					animated_sprite.play("default")
			AnimationState.ATTACK:
				if animated_sprite.sprite_frames.has_animation("attack"):
					animated_sprite.play("attack")
				else:
					animated_sprite.play("default")
			AnimationState.HURT:
				if animated_sprite.sprite_frames.has_animation("hurt"):
					animated_sprite.play("hurt")
				else:
					animated_sprite.play("default")
			AnimationState.DEATH:
				if animated_sprite.sprite_frames.has_animation("death"):
					animated_sprite.play("death")
				else:
					animated_sprite.play("default")

func _physics_process(delta):
	# Call parent physics process
	super._physics_process(delta)
	
	if DEBUG:
		# Periodically reset weapon cooldown if it's stuck
		if state_machine and state_machine.current_state_name == "ChaseState" and is_instance_valid(_target_node):
			var distance = global_position.distance_to(_target_node.global_position)
			if distance <= 50.0 and not weapon_system.can_attack():
				if randf() < 0.05:  # 5% chance per frame to force reset
					reset_weapon_cooldown()
	
	# Update animations
	update_animations_from_state(delta)

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
