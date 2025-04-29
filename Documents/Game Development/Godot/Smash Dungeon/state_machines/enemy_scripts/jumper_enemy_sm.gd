# res://state_machines/jumper_sm.gd
extends BaseEnemySM
class_name JumperEnemySM

# --- Node References ---
@onready var animated_sprite = $AnimatedSprite2D # Adjust path if necessary
@onready var jump_sound = $JumpSound # Adjust path if necessary
@onready var land_sound = $LandSound # Adjust path if necessary

# --- Animation State Enum ---
enum AnimationState { IDLE, RUN, JUMP, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# --- State Tracking for Sounds/Animation ---
var was_on_floor: bool = true # Track previous floor state for jump/land detection

func _ready():
	super() # Call BaseEnemySM ready first

	# Start with idle animation
	# Note: BaseEnemySM might already call _physics_process once in ready,
	# so animation might get set there too. Setting default here is safe.
	update_animation(AnimationState.IDLE)

	# Initial floor state
	was_on_floor = is_on_floor()

# --- Animation Handling ---
func update_animations_from_state(current_state_name: String):
	# Determine the target animation state based on the FSM state and physics
	var target_anim_state = AnimationState.IDLE # Default

	match current_state_name:
		"IdleState":
			target_anim_state = AnimationState.IDLE
		"ChaseState":
			if not is_on_floor(): # If chasing and not on floor, must be jumping/falling
				target_anim_state = AnimationState.JUMP
			else: # If chasing and on floor, running
				target_anim_state = AnimationState.RUN
				# Flip sprite based on velocity (BaseEnemySM physics applies velocity)
				if velocity.x != 0 and is_instance_valid(animated_sprite):
					animated_sprite.flip_h = velocity.x < 0
		"TelegraphState":
			 # Assuming no specific telegraph anim, reuse IDLE or ATTACK? Or add one?
			target_anim_state = AnimationState.ATTACK # Placeholder - use ATTACK anim for telegraph?
			# Keep facing target during telegraph/attack
			if is_instance_valid(_target_node) and is_instance_valid(animated_sprite):
				animated_sprite.flip_h = global_position.x > _target_node.global_position.x
		"AttackState":
			target_anim_state = AnimationState.ATTACK
			# Keep facing target during telegraph/attack
			if is_instance_valid(_target_node) and is_instance_valid(animated_sprite):
				animated_sprite.flip_h = global_position.x > _target_node.global_position.x
		"StunnedState":
			target_anim_state = AnimationState.HURT
		"DeathState":
			target_anim_state = AnimationState.DEATH
		"RepositioningState": # If used
			target_anim_state = AnimationState.RUN
			if velocity.x != 0 and is_instance_valid(animated_sprite):
				animated_sprite.flip_h = velocity.x < 0
		_:
			target_anim_state = AnimationState.IDLE

	# Update the actual animation player
	update_animation(target_anim_state)


func update_animation(new_state):
	if not is_instance_valid(animated_sprite): return
	# Prevent redundant plays, especially for non-looping animations
	if current_animation_state == new_state and animated_sprite.is_playing():
		# Allow looping animations (like Run, Idle) to restart if needed,
		# but prevent non-looping (Attack, Hurt, Death, Jump?) from restarting mid-play.
		var is_looping = ["idle", "run"] # Add animation names that should loop
		if not animated_sprite.animation in is_looping:
			return

	current_animation_state = new_state
	var anim_name = ""
	match new_state:
		AnimationState.IDLE: anim_name = "idle"
		AnimationState.RUN: anim_name = "run"
		AnimationState.JUMP: anim_name = "jump" # Assumes "jump" animation exists
		AnimationState.ATTACK: anim_name = "attack"
		AnimationState.HURT: anim_name = "hurt"
		AnimationState.DEATH: anim_name = "death"

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")


func _physics_process(delta):
	super._physics_process(delta) # IMPORTANT: Call parent first!

	var current_state_name = ""
	if state_machine and is_instance_valid(state_machine.current_state):
		current_state_name = state_machine.current_state_name

	# --- Jump/Land Sound Logic ---
	var currently_on_floor = is_on_floor()
	# Only trigger jump/land sounds logic if relevant state (avoids sounds in Idle/Death etc.)
	if current_state_name == "ChaseState" or current_state_name == "AttackState" or current_state_name == "RepositioningState":
		# Check for liftoff (was on floor, now is not)
		if was_on_floor and not currently_on_floor:
			if is_instance_valid(jump_sound) and not jump_sound.is_playing():
				jump_sound.play()
				# print("JUMP SOUND") # Debug

		# Check for landing (was not on floor, now is)
		if not was_on_floor and currently_on_floor:
			if is_instance_valid(land_sound) and not land_sound.is_playing():
				land_sound.play()
				# print("LAND SOUND") # Debug

	# Update floor state tracker for next frame
	was_on_floor = currently_on_floor

	# Update animations based on the current state
	update_animations_from_state(current_state_name)


# --- Override Death Effects (Similar to Fodder, adapt animation name) ---
func play_death_effects():
	# Animation should be triggered by update_animations_from_state when DeathState is active.
	super.play_death_effects() # BaseEnemy handles signals/flags
	# Call cleanup helper deferred
	call_deferred("_handle_death_animation_and_cleanup")

func _handle_death_animation_and_cleanup():
	if is_instance_valid(animated_sprite) and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		if animated_sprite.animation != "death": animated_sprite.play("death")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	# Assuming BaseEnemy.play_death_effects handles queue_free()
	pass
