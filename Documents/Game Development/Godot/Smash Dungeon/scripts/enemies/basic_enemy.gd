## basic_enemy.gd - Updated to use enhanced BaseEnemy system
#extends BaseEnemy
#class_name BasicEnemy
#
## Node references
##@onready var animated_sprite = $AnimatedSprite2D
#
## Animation states
#enum AnimationState { IDLE, RUN, ATTACK, HURT, DEATH }
#var current_animation_state = AnimationState.IDLE
#
#func _ready():
	## Set weapon ID
	#weapon_id = "sword"
#
	## Call parent _ready
	#super._ready()
	#
	## Start with idle animation
	#update_animation(AnimationState.IDLE)
#
#func initialize():
	## Call parent initialization
##	super.initialize()
	#
	## Additional initialization specific to this enemy type
	#add_to_group("enemies")
	#collision_layer = 4  # Enemy layer
	#collision_mask = 1 | 2  # World and player layers
#
## Override physics process to handle animations
#func _physics_process(delta):
	## Call the parent physics process first
	#super._physics_process(delta)
	#
	## Update animations based on state and movement
	#update_animations_from_state(delta)
#
## Handle specific animation updates based on AI state and movement
#func update_animations_from_state(_delta):
	#match current_ai_state:
		#AIState.IDLE:
			#update_animation(AnimationState.IDLE)
		#AIState.CHASING:
			#update_animation(AnimationState.RUN)
			## Update sprite direction based on horizontal movement
			#if velocity.x != 0:
				#animated_sprite.flip_h = velocity.x < 0
		#AIState.ATTACKING:
			#update_animation(AnimationState.ATTACK)
		#AIState.REPOSITIONING:
			#update_animation(AnimationState.RUN)
			## Update sprite direction based on movement
			#if velocity.x != 0:
				#animated_sprite.flip_h = velocity.x < 0
		#AIState.FLEEING:
			#update_animation(AnimationState.RUN)
			#if velocity.x != 0:
				#animated_sprite.flip_h = velocity.x < 0
		#AIState.STUNNED:
			#update_animation(AnimationState.HURT)
#
## Update the animation if needed
#func update_animation(new_state):
	#if current_animation_state == new_state:
		#return
		#
	#current_animation_state = new_state
	#
	#match new_state:
		#AnimationState.IDLE:
			#animated_sprite.play("idle")
		#AnimationState.RUN:
			#animated_sprite.play("run")
		#AnimationState.ATTACK:
			#animated_sprite.play("attack")
		#AnimationState.HURT:
			#animated_sprite.play("hurt")
		#AnimationState.DEATH:
			#animated_sprite.play("death")
#
## Override process_attacking_state to handle melee attacks
#func process_attacking_state(delta):
	## First call the parent method to handle basic attack state logic
	#super.process_attacking_state(delta)
	#
	## Basic enemies prefer to stop when attacking
	#if is_instance_valid(_target_node):
		#var distance = global_position.distance_to(_target_node.global_position)
		#
		#if distance <= preferred_attack_distance + preferred_distance_tolerance:
			## If close enough, stop moving while attacking
			#target_velocity = Vector2.ZERO
#
## Override the death handler to play death animation
#func play_death_effects():
	## Update animation
	#update_animation(AnimationState.DEATH)
	#
	## Call parent method to handle signals and cleanup
	#super.play_death_effects()
	#
	## Wait for death animation to finish
	#await animated_sprite.animation_finished
	#
	## Disable collision
	#disable_collision()
	#
	## Fade out
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	#
	## Queue free after fade out
	#await tween.finished
	#queue_free()
#
## Overriding the attack execution for melee attacks
#func execute_melee_attack(attack_data: Dictionary):
	## Only proceed if we have a valid target
	#if not is_instance_valid(_target_node):
		#return
		#
	## Get attack attributes
	#var damage = attack_data.get("damage", 10)
	#var knockback = attack_data.get("knockback", 100.0)
	#
	## Calculate direction to target
	#var direction = (_target_node.global_position - global_position).normalized()
	#
	## Apply damage if target has take_damage method
	#if _target_node.has_method("take_damage"):
		#_target_node.take_damage(damage, direction, knockback)
	#
	## Play attack animation
	#update_animation(AnimationState.ATTACK)
