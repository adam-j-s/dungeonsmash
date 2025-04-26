# state_machines/states/fodder_attack_state.gd
extends AttackState
class_name FodderAttackState

var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.2 # Default, can be overridden by config

# DEBUG flag inherited from base class AttackState

func enter():
	# Don't call super.enter() as we don't want the immediate attack
	is_telegraphing = false
	telegraph_timer = 0.0

	# Get telegraph duration from config if available
	if enemy and enemy.config and "states_config" in enemy.config \
	and enemy.config.states_config.has("AttackState") \
	and enemy.config.states_config["AttackState"].has("telegraph_time"):
		telegraph_duration = enemy.config.states_config["AttackState"]["telegraph_time"]
	elif enemy and "attack_telegraph_time" in enemy: # Fallback to base enemy property
		telegraph_duration = enemy.attack_telegraph_time
	else:
		telegraph_duration = 0.2 # Hardcoded fallback

	if DEBUG: print("FodderAttackState entered")

	# Start the telegraph IF conditions are met
	start_telegraph_attack()

func physics_process(delta):
	if is_telegraphing:
		telegraph_timer += delta

		# Show telegraph visual (assuming node exists)
		# No need for constant check, visibility set in start_telegraph_attack
		# if enemy.has_node("TelegraphEffect"): ...

		# After telegraph time expires, attempt attack using base class logic
		if telegraph_timer >= telegraph_duration:
			if DEBUG: print("Telegraph complete, attempting attack via base logic")
			is_telegraphing = false
			_hide_telegraph_effect() # Hide visual

			# Use the base class's combined check, execution, and transition logic
			_try_attack_and_transition()
			return # Stop processing this frame

	# If not telegraphing, allow base class movement logic to run
	# (e.g., movement during the actual attack swing/hitbox lifetime)
	# This assumes the base class physics_process handles movement appropriately
	super.physics_process(delta)


# Overrides the base function which isn't used directly now,
# but keeps the logic for starting the specific telegraph process.
func start_telegraph_attack():
	# --- Check conditions BEFORE starting telegraph ---
	# Use the base class condition check, but don't transition yet if it fails here.
	if not _check_attack_conditions():
		if DEBUG: print("FodderAttackState: Conditions not met, cannot start telegraph.")
		# If conditions fail here (e.g., target lost), transition immediately.
		# The base _check_attack_conditions already calls _transition_after_attack if needed.
		# We might need a specific transition if telegraph fails *before* starting.
		if not is_instance_valid(enemy._target_node):
			change_state("IdleState")
		else: # Likely failed due to cooldown
			change_state("ChaseState")
		return
	# --- Conditions met, proceed ---

	if DEBUG: print("Starting telegraph attack")
	is_telegraphing = true
	telegraph_timer = 0.0
	_show_telegraph_effect()


# --- Helper functions for telegraph visuals ---
func _show_telegraph_effect():
	if enemy.has_node("TelegraphEffect"):
		var telegraph = enemy.get_node("TelegraphEffect")
		if telegraph:
			telegraph.visible = true
			# Optional: Configure size/color here if needed dynamically
			if DEBUG: print("Telegraph effect shown")

func _hide_telegraph_effect():
	if enemy.has_node("TelegraphEffect"):
		var telegraph = enemy.get_node("TelegraphEffect")
		if telegraph:
			telegraph.visible = false

# Note: perform_attack_and_transition() as it's now handled by calling
# the base class's _try_attack_and_transition() method.
