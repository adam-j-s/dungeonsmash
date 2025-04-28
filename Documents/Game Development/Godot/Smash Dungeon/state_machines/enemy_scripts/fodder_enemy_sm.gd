# res://state_machines/fodder_enemy_sm.gd (MODIFIED)
extends BaseEnemySM # Keep extending BaseEnemySM
class_name FodderEnemySM

# --- Node References (Keep from existing script) ---
@onready var animated_sprite = $AnimatedSprite2D # Adjust path if necessary
# @onready var telegraph_effect = $TelegraphEffect # COMMENT OUT or REMOVE - TelegraphState should handle visuals if needed

# --- REMOVE OLD @export variables ---
# @export var retreat_chance: float = 0.4  <-- REMOVE/COMMENT OUT
# @export var jump_chance: float = 0.2 <-- REMOVE/COMMENT OUT
# @export var detection_range: float = 500.0 <-- REMOVE/COMMENT OUT

# --- Animation State Enum (Keep from existing script) ---
enum AnimationState { IDLE, RUN, TELEGRAPH, ATTACK, HURT, DEATH }
var current_animation_state = AnimationState.IDLE

# --- REMOVE DEBUG CONSTANT unless specifically needed for animations ---
# const DEBUG = true

func _ready():
	super() # Call BaseEnemySM's ready FIRST

	# --- REMOVE Hardcoded behavior settings from _ready ---
	# aggression_level = 0.9 <-- REMOVE
	# direct_chase = true <-- REMOVE
	# chase_speed_multiplier = 1.8 <-- REMOVE
	# Ensure telegraph effect is properly set up <-- REMOVE (TelegraphState handles this)
	# Debug weapon system state <-- REMOVE (Base system handles this)
	# Force weapon initialization <-- REMOVE (Base system handles this)

	# Keep necessary node setup if not handled by BaseEnemySM/States
	if animated_sprite and animated_sprite.sprite_frames:
		# Start in idle animation if available, else default
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		elif animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

	# Add to groups (BaseEnemySM usually handles this in its _ready, but safe to keep if needed)
	if not is_in_group("enemies"):
		add_to_group("enemies")

	# Collision layers/masks (Better set in the Scene Inspector if possible)
	# collision_layer = 8
	# collision_mask = 1 | 2


# --- REMOVE initialize() function entirely ---
# func initialize(): ...

# --- REMOVE reinitialize_weapon() function entirely ---
# func reinitialize_weapon(): ...

# --- REMOVE _on_weapon_cooldown_complete() - BaseEnemySM already has this ---
# func _on_weapon_cooldown_complete(): ...

# --- REMOVE reset_weapon_cooldown() function entirely ---
# func reset_weapon_cooldown(): ...

# --- Animation handling (Keep logic from existing script, ensure state names match standard states) ---
func update_animations_from_state(delta):
	if state_machine and is_instance_valid(state_machine.current_state): # Check current_state validity
		var current_state_name = state_machine.current_state_name
		match current_state_name:
			"IdleState":
				update_animation(AnimationState.IDLE)
			"ChaseState":
				update_animation(AnimationState.RUN)
				# Flip sprite based on velocity (BaseEnemySM physics applies velocity)
				if velocity.x != 0 and animated_sprite:
					animated_sprite.flip_h = velocity.x < 0
			"TelegraphState": # Use standard TelegraphState name
				update_animation(AnimationState.TELEGRAPH)
			"AttackState": # Use standard AttackState name
				update_animation(AnimationState.ATTACK)
			"StunnedState": # Use standard StunnedState name
				update_animation(AnimationState.HURT)
			"DeathState": # Use standard DeathState name
				update_animation(AnimationState.DEATH)
			# Add cases for RepositioningState if fodder uses it and has animation
			"RepositioningState":
				update_animation(AnimationState.RUN) # Or IDLE? Or a specific anim?
			_: # Default case if state name doesn't match
				update_animation(AnimationState.IDLE)


func update_animation(new_state):
	# Small improvement: check if sprite exists first
	if not is_instance_valid(animated_sprite):
		return
	# Only change if state changes OR if animation finished/stopped (important for looping vs non-looping)
	if current_animation_state == new_state and animated_sprite.is_playing():
		# Exception: Allow restarting loop animations like IDLE or RUN if needed
		if new_state != AnimationState.IDLE and new_state != AnimationState.RUN:
			return

	current_animation_state = new_state

	var anim_name = ""
	match new_state:
		AnimationState.IDLE: anim_name = "idle"
		AnimationState.RUN: anim_name = "run"
		AnimationState.TELEGRAPH: anim_name = "telegraph"
		AnimationState.ATTACK: anim_name = "attack"
		AnimationState.HURT: anim_name = "hurt"
		AnimationState.DEATH: anim_name = "death"

	# Play the animation if it exists, otherwise default
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")

func _physics_process(delta):
	# Call parent FIRST to let state machine update velocity etc.
	super._physics_process(delta)

	# Then update animations based on the state set by the parent/state machine
	update_animations_from_state(delta)

	# --- REMOVE Debug weapon cooldown reset logic ---
	# if DEBUG: ... reset_weapon_cooldown() ...

# --- Override for death effects (Keep logic from existing script, ensure super() called correctly) ---
func play_death_effects():
	# BaseEnemySM.die() changes state to DeathState.
	# DeathState.enter() calls this function (play_death_effects).
	# So, animation should be triggered by update_animations_from_state when DeathState becomes active.
	# We might not need to explicitly call update_animation here if physics_process runs once more.
	# update_animation(AnimationState.DEATH) # Maybe redundant, test this

	# Call BaseEnemy's effects (signals, etc.) FIRST
	super.play_death_effects() # This is BaseEnemy.play_death_effects

	# Use a helper function to handle async animation wait + cleanup
	# Needs to be called deferred if play_death_effects is called within physics processing sometimes
	call_deferred("_handle_death_animation_and_cleanup")


# Changed to async function for cleaner await syntax if preferred, or keep as is
func _handle_death_animation_and_cleanup():
	# Wait for death animation if available
	if is_instance_valid(animated_sprite) and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		# Ensure the death animation is playing (might have been set by update_animations_from_state)
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		# Now wait for it to finish
		await animated_sprite.animation_finished
	else:
		# Fallback delay if no death animation
		await get_tree().create_timer(0.5).timeout # Use await with timer

	# Actual removal from scene - BaseEnemy.play_death_effects already queues free by default.
	# Check BaseEnemy script. If it calls queue_free(), remove the line below.
	# If BaseEnemy.play_death_effects ONLY sets flags/signals, keep queue_free() here.
	# Assuming BaseEnemy handles queue_free():
	pass # print("Death animation finished, BaseEnemy handles queue_free.")
	# If BaseEnemy does NOT handle queue_free():
	# queue_free()
