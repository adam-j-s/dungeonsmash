# surface_animation_component.gd
class_name SurfaceAnimationComponent
extends EnemyComponent

# Animation states tied to BaseEnemy's AI states
enum AnimationState { IDLE, MOVE, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# Animation mapping - customize based on available animations
@export_group("Animation Mapping")
@export var idle_animation: String = "idle"
@export var move_animation: String = "move" 
@export var attack_animation: String = "attack"
@export var hurt_animation: String = "hurt"
@export var death_animation: String = "death"

# References
var animated_sprite: AnimatedSprite2D
var surface_movement: SurfaceMovementComponent

func setup():
	# Get the animated sprite
	animated_sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if !animated_sprite:
		push_error("Animation component requires AnimatedSprite2D")
	
	# Find the surface movement component
	for child in enemy.get_children():
		if child is SurfaceMovementComponent:
			surface_movement = child
			break

func process(delta: float):
	# Update animation based on enemy state
	update_animations_from_state(delta)

func update_animations_from_state(delta: float):
	var new_state = AnimationState.MOVE  # Default to move
	
	# Map enemy AI state to animation state
	match enemy.current_ai_state:
		enemy.AIState.IDLE, enemy.AIState.CHASING:
			new_state = AnimationState.MOVE
		enemy.AIState.ATTACKING:
			new_state = AnimationState.ATTACK
		enemy.AIState.STUNNED:
			new_state = AnimationState.HURT
	
	# Update the animation if it changed
	update_animation(new_state)
	
	## Update sprite orientation based on surface type
	#if animated_sprite and surface_movement:
		#var surface_info = surface_movement.get_current_surface_state()
		#
		## Get direction from modified component (either move_direction or movement_direction)
		#var direction = Vector2.RIGHT
		#if "move_direction" in surface_movement:
			#direction = surface_movement.move_direction
		#elif "movement_direction" in surface_movement:
			#direction = surface_movement.movement_direction
		#
		#match surface_info.type:
			#"ground":
				#animated_sprite.rotation = 0
				#animated_sprite.flip_h = (direction.x < 0)
			#"wall_left":
				#animated_sprite.rotation = PI/2  # 90 degrees
				#animated_sprite.flip_h = (direction.y > 0)
			#"wall_right":
				#animated_sprite.rotation = -PI/2  # -90 degrees
				#animated_sprite.flip_h = (direction.y < 0)
			#"ceiling":
				#animated_sprite.rotation = PI  # 180 degrees
				#animated_sprite.flip_h = (direction.x > 0)

func update_animation(new_state: int):
	if !animated_sprite or current_animation_state == new_state:
		return
	
	current_animation_state = new_state
	
	match new_state:
		AnimationState.IDLE:
			if animated_sprite.sprite_frames.has_animation(idle_animation):
				animated_sprite.play(idle_animation)
		AnimationState.MOVE:
			if animated_sprite.sprite_frames.has_animation(move_animation):
				animated_sprite.play(move_animation)
		AnimationState.ATTACK:
			if animated_sprite.sprite_frames.has_animation(attack_animation):
				animated_sprite.play(attack_animation)
		AnimationState.HURT:
			if animated_sprite.sprite_frames.has_animation(hurt_animation):
				animated_sprite.play(hurt_animation)
		AnimationState.DEATH:
			if animated_sprite.sprite_frames.has_animation(death_animation):
				animated_sprite.play(death_animation)
