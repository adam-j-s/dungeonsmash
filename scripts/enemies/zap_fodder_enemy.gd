# zap_fodder_enemy.gd - Floating enemy with AOE attacks and electrify behavior
extends BaseEnemy
class_name ZapFodderEnemy

# --- Basic Parameters ---
@export var retreat_chance: float = 0.1
@export var detection_range: float = 500.0

# --- Electrify Behavior ---
@export_group("Electrify Behavior")
@export_range(50, 300) var approach_distance: float = 120.0     # Distance to get close to player
@export_range(0.1, 3.0) var electrify_duration: float = 0.8      # How long to stay in attack state
@export_range(100, 500) var cooldown_distance: float = 300.0     # Distance to retreat after attack
@export_range(0.5, 2.0) var retreat_speed_multiplier: float = 1.2  # How fast to move during retreat
@export_range(0.1, 1.0) var approach_speed_multiplier: float = 0.8 # How fast to move during approach
@export_range(0.5, 5.0) var retreat_duration: float = 1.0        # How long to retreat

# --- Visual Effects ---
@export_group("Visual Effects")
@export var electric_particles_amount: int = 20
@export var electric_particles_color: Color = Color(0.2, 0.7, 1.0)  # Blue-ish electric color

# --- Node References ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var aoe_effect = $AOEEffect

# --- State Tracking ---
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
var is_retreating: bool = false
var retreat_timer: float = 0.0
var is_electrifying: bool = false
var electrify_timer: float = 0.0
var should_retreat_after_attack: bool = true

# --- Animation States ---
enum AnimationState { IDLE, MOVE, TELEGRAPH, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

func _ready():
	# Set weapon ID before calling parent _ready so it can set up the weapon system
	weapon_id = "zap_aoe"
	
	super._ready()
	
	# Set floating mode
	motion_mode = MOTION_MODE_FLOATING
	use_gravity = false
	
	# Initialize telegraph effect
	if aoe_effect:
		aoe_effect.visible = false
		aoe_effect.scale = Vector2(0.1, 0.1)
	
	# Connect weapon system signals
	if weapon_system and not weapon_system.is_connected("cooldown_complete", _on_weapon_cooldown_complete):
		weapon_system.cooldown_complete.connect(_on_weapon_cooldown_complete)

func initialize():
	super.initialize()
	
	# Setup for floating enemy
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1 | 2 | 4

func _physics_process(delta):
	super._physics_process(delta)
	
	# Handle telegraphing
	if is_telegraphing:
		telegraph_timer += delta
		if telegraph_timer >= attack_telegraph_time:
			is_telegraphing = false
			telegraph_timer = 0
			perform_attack("area")
	
	# Handle retreat
	if is_retreating:
		retreat_timer -= delta
		if retreat_timer <= 0:
			is_retreating = false
			if is_instance_valid(_target_node):
				change_ai_state(AIState.CHASING)
	
	# Handle electrifying
	if is_electrifying:
		electrify_timer += delta
		if electrify_timer >= electrify_duration:
			is_electrifying = false
			electrify_timer = 0
			
			# Time to retreat
			if should_retreat_after_attack:
				start_retreat()
	
	# Update animations
	update_animations_from_state(delta)

# --- Weapon System Callbacks ---

func _on_weapon_cooldown_complete():
	can_attack = true

# --- Attack Handling ---

func start_telegraph_attack():
	if not can_attack or not weapon_system or not weapon_system.can_attack():
		return
	
	is_telegraphing = true
	telegraph_timer = 0
	
	if aoe_effect:
		aoe_effect.visible = true
		var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		var target_radius = weapon_system.get_attack_range()
		var target_scale = target_radius / 50.0
		tween.tween_property(aoe_effect, "scale", Vector2(target_scale, target_scale), attack_telegraph_time).from(Vector2(0.1, 0.1))
	
	update_animation(AnimationState.TELEGRAPH)

func perform_attack(attack_type: String = "area") -> bool:
	if aoe_effect:
		aoe_effect.visible = false
		aoe_effect.scale = Vector2(0.1, 0.1)
	
	update_animation(AnimationState.ATTACK)
	
	var attack_success = false
	if weapon_system:
		attack_success = weapon_system.perform_attack()
	
	if attack_success:
		can_attack = false
		
		# Start electrifying instead of immediately retreating
		is_electrifying = true
		electrify_timer = 0
		
		# Start electric effect
		start_electric_effect()
	else:
		# If attack failed, still consider retreating 
		if randf() < retreat_chance:
			start_retreat()
		else:
			var timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = post_attack_pause if post_attack_pause > 0 else 0.1
			add_child(timer)
			timer.timeout.connect(func():
				if is_instance_valid(self) and not _is_defeated and is_instance_valid(_target_node):
					change_ai_state(AIState.CHASING)
				timer.queue_free()
			)
			timer.start()
	
	return attack_success

func start_electric_effect():
	# Create electric particles
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = electric_particles_amount
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 80
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = electric_particles_color
	add_child(particles)
	
	# Set a timer to remove particles
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = electrify_duration
	add_child(timer)
	timer.timeout.connect(func():
		particles.queue_free()
		timer.queue_free()
	)
	timer.start()

func start_retreat():
	is_retreating = true
	retreat_timer = retreat_duration
	
	if is_instance_valid(_target_node):
		var direction = (global_position - _target_node.global_position).normalized()
		target_velocity = direction * move_speed * retreat_speed_multiplier

# --- State Processing ---

func process_chasing_state(delta):
	if is_instance_valid(_target_node):
		var distance = global_position.distance_to(_target_node.global_position)
		
		# Always move toward the player
		var direction_to_target = (_target_node.global_position - global_position).normalized()
		
		# When very close, start attack sequence
		if distance <= approach_distance and can_attack and not is_telegraphing:
			start_telegraph_attack()
			return
		
		# Otherwise keep approaching at appropriate speed
		target_velocity = direction_to_target * move_speed * (1.0 if distance > cooldown_distance else approach_speed_multiplier)
		return
	
	# Use default behavior if no target
	super.process_chasing_state(delta)

# For the process_attacking_state function:
func process_attacking_state(delta):
	# If we're telegraphing, continue approaching the player
	if is_telegraphing:
		if is_instance_valid(_target_node):
			var direction_to_target = (_target_node.global_position - global_position).normalized()
			target_velocity = direction_to_target * move_speed * approach_speed_multiplier
		return
	
	# If we've just done our attack, ensure we retreat
	if is_retreating:
		return
	
	# If we're electrifying, stay in place
	if is_electrifying:
		# Hold position during electrify
		target_velocity = Vector2.ZERO
		return
	
	# Otherwise handle normal attacking state
	super.process_attacking_state(delta)

# --- Animation Handling ---

func update_animations_from_state(delta):
	if is_electrifying:
		update_animation(AnimationState.ATTACK)
		return
		
	if is_telegraphing:
		update_animation(AnimationState.TELEGRAPH)
		return
	
	if is_retreating:
		update_animation(AnimationState.MOVE)
		return
	
	match current_ai_state:
		AIState.IDLE:
			update_animation(AnimationState.IDLE)
		AIState.CHASING:
			update_animation(AnimationState.MOVE)
			if velocity.x != 0 and animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
		AIState.ATTACKING:
			if not is_telegraphing:
				update_animation(AnimationState.IDLE)
		AIState.REPOSITIONING:
			update_animation(AnimationState.MOVE)
			if velocity.x != 0 and animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
		AIState.STUNNED:
			update_animation(AnimationState.HURT)

func update_animation(new_state):
	if current_animation_state == new_state:
		return
	
	current_animation_state = new_state
	
	if animated_sprite:
		match new_state:
			AnimationState.IDLE:
				if animated_sprite.sprite_frames.has_animation("idle"):
					animated_sprite.play("idle")
			AnimationState.MOVE:
				if animated_sprite.sprite_frames.has_animation("move"):
					animated_sprite.play("move")
				elif animated_sprite.sprite_frames.has_animation("run"):
					animated_sprite.play("run")
			AnimationState.TELEGRAPH:
				if animated_sprite.sprite_frames.has_animation("telegraph"):
					animated_sprite.play("telegraph")
				elif animated_sprite.sprite_frames.has_animation("attack_windup"):
					animated_sprite.play("attack_windup")
			AnimationState.ATTACK:
				if animated_sprite.sprite_frames.has_animation("attack"):
					animated_sprite.play("attack")
			AnimationState.HURT:
				if animated_sprite.sprite_frames.has_animation("hurt"):
					animated_sprite.play("hurt")
			AnimationState.DEATH:
				if animated_sprite.sprite_frames.has_animation("death"):
					animated_sprite.play("death")

# --- Death Effects ---

func play_death_effects():
	update_animation(AnimationState.DEATH)
	
	super.play_death_effects()
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	
	await tween.finished
	if is_instance_valid(self):
		queue_free()
